#!/usr/bin/env python3
"""ClipShield Build Station.

A desktop front end for the release pipeline. It reads the current app version,
asks the live panel who the resellers are and what they are already on, and then
does the whole run behind one button:

    compile house -> compile reseller base -> stamp each reseller
    -> commit and push to GitHub -> publish every link back to the panel

Publishing is what closes the loop. Once a build is recorded in the panel, the
reseller sees the download on their portal and their customers' apps offer the
update on their next sync -- no links copied by hand.

Runs from the project folder. Packaged with tools/builder_app/build_exe.ps1.
"""

import hashlib
import hmac
import json
import os
import queue
import re
import subprocess
import sys
import threading
import time
import tkinter as tk
import urllib.error
import urllib.request
from tkinter import messagebox, scrolledtext, ttk

APP_TITLE = "ClipShield Build Station"
PANEL_URL = "https://clipshieldpro.toolsfinity.io"
GITHUB_REPO = "badarbukharidev-alt/ClipShieldPro"
RESELLER_DIR = "resellers"
RELEASE_DIR = "release"

# GitHub serves LFS files from this host; a raw.githubusercontent link returns
# the pointer text rather than the APK.
LFS_BASE = "https://media.githubusercontent.com/media/%s/main" % GITHUB_REPO

BG = "#F5F2EC"
CARD = "#FFFFFF"
INK = "#191722"
MUT = "#726E7C"
ACCENT = "#FF6A3D"
LIME = "#12B56A"
ERROR = "#E53935"


def project_root():
    """The ClipShield App folder, whether running as a script or a frozen exe."""
    if getattr(sys, "frozen", False):
        # Packaged: the exe is expected to sit in the project folder, or in
        # tools/builder_app/dist inside it.
        here = os.path.dirname(sys.executable)
        for candidate in (here, os.path.abspath(os.path.join(here, "..", "..", ".."))):
            if os.path.isfile(os.path.join(candidate, "pubspec.yaml")):
                return candidate
        return here

    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


ROOT = project_root()


# ---------------------------------------------------------------------------
# Panel API
# ---------------------------------------------------------------------------

def read_secret():
    path = os.path.join(ROOT, "android", "api_secret.txt")
    if not os.path.isfile(path):
        return None
    with open(path, "r", encoding="utf-8") as handle:
        return re.sub(r"\s", "", handle.read())


def sign(secret, action, ts, nonce, extra=""):
    """Canonical form must match api_canonical(): action|device|ts|nonce|extra."""
    canonical = "|".join([action, "", str(ts), nonce, extra])

    return hmac.new(
        secret.encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256
    ).hexdigest()


# A raw error code from the panel says nothing about what to do. These are the
# ones with an obvious fix.
API_HINTS = {
    "bad_signature":
        "The panel rejected the signature.\n\n"
        "API_SECRET in the panel's inc/config.php does not match "
        "android/api_secret.txt on this machine. Open that file, copy its "
        "contents, and paste them as API_SECRET on the server.\n\n"
        "(The same mismatch also keeps the task reward system switched off.)",
    "stale_request":
        "The panel rejected the request as stale. This machine's clock is more "
        "than a few minutes away from the server's.",
    "bad_nonce":
        "The panel rejected the request. Re-run it; if it keeps happening, the "
        "panel files may be out of date.",
}


def explain(error):
    return API_HINTS.get(str(error), str(error))


def fetch_resellers(secret, timeout=30):
    ts = int(time.time())
    nonce = os.urandom(8).hex()
    sig = sign(secret, "build.resellers", ts, nonce)

    url = "%s/api/resellers.php?ts=%d&nonce=%s&sig=%s" % (PANEL_URL, ts, nonce, sig)

    with urllib.request.urlopen(url, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))

    if not payload.get("ok"):
        raise RuntimeError(payload.get("error", "unknown error"))

    return payload.get("resellers", [])


def publish_build(secret, target, code, version_name, version_code, apk_url, notes, timeout=30):
    ts = int(time.time())
    nonce = os.urandom(8).hex()
    sig = sign(secret, "build.publish", ts, nonce, "%s:%s" % (target, code))

    body = json.dumps({
        "target": target,
        "code": code,
        "version_name": version_name,
        "version_code": version_code,
        "apk_url": apk_url,
        "notes": notes,
        "ts": ts,
        "nonce": nonce,
        "sig": sig,
    }).encode("utf-8")

    request = urllib.request.Request(
        "%s/api/publish_build.php" % PANEL_URL,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))

    if not payload.get("ok"):
        raise RuntimeError(payload.get("error", "unknown error"))

    return payload


# ---------------------------------------------------------------------------
# Local project state
# ---------------------------------------------------------------------------

def app_version():
    """Returns (name, code) from pubspec.yaml, e.g. ("1.2.16", 19)."""
    path = os.path.join(ROOT, "pubspec.yaml")
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"^version:\s*([0-9.]+)\+(\d+)\s*$", line.strip())
            if match:
                return match.group(1), int(match.group(2))

    raise RuntimeError("Could not read version from pubspec.yaml")


def apk_url_for(filename):
    return "%s/%s/%s" % (LFS_BASE, RESELLER_DIR, filename)


def house_apk_url(filename):
    return "%s/%s/%s" % (LFS_BASE, RELEASE_DIR, filename)


# ---------------------------------------------------------------------------
# The run
# ---------------------------------------------------------------------------

class BuildRun:
    """Executes the pipeline, reporting progress through a queue.

    Kept free of any Tk reference so it can run on a worker thread: touching
    widgets from off the main thread is how a GUI starts crashing in ways that
    look random.
    """

    def __init__(self, secret, resellers, notes, do_push, do_publish, log, progress):
        self.secret = secret
        self.resellers = resellers
        self.notes = notes
        self.do_push = do_push
        self.do_publish = do_publish
        self.log = log
        self.progress = progress
        self.cancelled = False

    def run_command(self, args, cwd=None, label=None):
        if label:
            self.log(label)

        process = subprocess.Popen(
            args,
            cwd=cwd or ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )

        for line in process.stdout:
            line = line.rstrip()
            if line:
                self.log("   " + line)
            if self.cancelled:
                process.terminate()
                return 1

        return process.wait()

    def clear_intermediates(self):
        """Gradle's daemon holds handles on these; deleting while it is alive
        fails with "Access is denied", and so does Flutter's own cleanup a moment
        later -- which crashes the tool rather than failing cleanly."""
        target = os.path.join(ROOT, "build", "app", "intermediates", "flutter")
        if not os.path.isdir(target):
            return

        gradlew = os.path.join(ROOT, "android", "gradlew.bat")
        if os.path.isfile(gradlew):
            self.run_command([gradlew, "--stop"], cwd=os.path.join(ROOT, "android"))

        import shutil
        shutil.rmtree(target, ignore_errors=True)

        if os.path.isdir(target):
            self.log("   intermediates still locked; running flutter clean")
            self.run_command(["flutter", "clean"])

    def execute(self):
        name, code = app_version()
        built = []

        steps = 2 + len(self.resellers) + (1 if self.do_push else 0)
        step = [0]

        def advance():
            step[0] += 1
            self.progress(step[0], steps)

        # ------------------------------------------------------- house build
        self.log("Building the house app (v%s)..." % name)
        self.clear_intermediates()

        status = self.run_command([
            "flutter", "build", "apk", "--release",
            "--dart-define=CLIPSHIELD_API_SECRET=%s" % self.secret,
        ])
        if status != 0:
            raise RuntimeError("The house build failed.")

        os.makedirs(os.path.join(ROOT, RELEASE_DIR), exist_ok=True)
        house_name = "ClipShieldPro-v%s.apk" % name
        house_path = os.path.join(ROOT, RELEASE_DIR, house_name)

        import shutil
        shutil.copy2(
            os.path.join(ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk"),
            house_path,
        )
        self.log("   %s" % house_name)
        built.append(house_path)
        advance()

        # ---------------------------------------------------- reseller base
        base_path = None
        if self.resellers:
            self.log("Building the reseller base (admin tools compiled out)...")
            self.clear_intermediates()

            status = self.run_command([
                "flutter", "build", "apk", "--release",
                "--dart-define=CLIPSHIELD_API_SECRET=%s" % self.secret,
                "--dart-define=CLIPSHIELD_RESELLER_BASE=true",
            ])
            if status != 0:
                raise RuntimeError("The reseller base build failed.")

            base_path = os.path.join(ROOT, "build", "reseller-base.apk")
            shutil.copy2(
                os.path.join(ROOT, "build", "app", "outputs", "flutter-apk", "app-release.apk"),
                base_path,
            )
            self.log("   base ready")
        advance()

        # ------------------------------------------------------- stamp each
        stamped = []
        if base_path:
            os.makedirs(os.path.join(ROOT, RESELLER_DIR), exist_ok=True)
            stamper = os.path.join(ROOT, "tools", "stamp_reseller.py")

            for reseller in self.resellers:
                if self.cancelled:
                    raise RuntimeError("Cancelled.")

                rcode = reseller["code"]
                filename = "ClipShieldPro-%s.apk" % rcode
                out = os.path.join(ROOT, RESELLER_DIR, filename)

                self.log("Stamping %s..." % rcode)
                status = self.run_command([sys.executable, stamper, base_path, rcode, out])

                if status == 0:
                    stamped.append((rcode, filename))
                    built.append(out)
                else:
                    self.log("   FAILED: %s was not built" % rcode)

                advance()

            try:
                os.remove(base_path)
            except OSError:
                pass

        # -------------------------------------------------------------- push
        if self.do_push and built:
            self.log("Pushing to GitHub...")
            self.run_command(["git", "add", RELEASE_DIR, RESELLER_DIR])

            changed = subprocess.run(
                ["git", "status", "--porcelain", "--", RELEASE_DIR, RESELLER_DIR],
                cwd=ROOT, capture_output=True, text=True,
            ).stdout.strip()

            if changed:
                message = "Build v%s+%d" % (name, code)
                if stamped:
                    message += " with %d reseller APK(s)" % len(stamped)
                self.run_command(["git", "commit", "-q", "-m", message])

                status = self.run_command(["git", "push", "origin", "main"])
                if status != 0:
                    # The APKs exist and are committed; only the upload failed.
                    # Publishing links now would point the panel at files nobody
                    # can download yet, so it is stopped here.
                    raise RuntimeError(
                        "The push failed. The APKs are committed locally.\n"
                        "Nothing was published, because the links would 404."
                    )
                self.log("   pushed")
            else:
                self.log("   nothing changed")
            advance()

        # ----------------------------------------------------------- publish
        if self.do_publish:
            if not self.do_push:
                self.log("Skipping publish: nothing was pushed, so the links "
                         "would not resolve yet.")
            else:
                self.log("Publishing links to the panel...")

                try:
                    publish_build(
                        self.secret, "house", "", name, code,
                        house_apk_url(house_name), self.notes,
                    )
                    self.log("   house -> v%s" % name)
                except Exception as error:
                    self.log("   house publish failed: %s" % error)

                for rcode, filename in stamped:
                    try:
                        publish_build(
                            self.secret, "reseller", rcode, name, code,
                            apk_url_for(filename), self.notes,
                        )
                        self.log("   %s -> v%s" % (rcode, name))
                    except Exception as error:
                        self.log("   %s publish failed: %s" % (rcode, error))

        return name, code, stamped


# ---------------------------------------------------------------------------
# GUI
# ---------------------------------------------------------------------------

class BuilderApp:

    def __init__(self, root):
        self.root = root
        self.secret = read_secret()
        self.resellers = []
        self.messages = queue.Queue()
        self.running = False
        self.run_object = None

        root.title(APP_TITLE)
        root.geometry("820x620")
        root.configure(bg=BG)
        root.minsize(700, 520)

        self._build_ui()
        self._poll_messages()

        if self.secret is None:
            self.log("android/api_secret.txt is missing. Builds and the panel "
                     "connection both need it.")
            self.build_button.config(state="disabled")
        else:
            self.refresh()

    # ------------------------------------------------------------------ ui
    def _build_ui(self):
        header = tk.Frame(self.root, bg=CARD, padx=18, pady=14)
        header.pack(fill="x")

        tk.Label(header, text="ClipShield Build Station", bg=CARD, fg=INK,
                 font=("Segoe UI", 15, "bold")).pack(side="left")

        self.version_label = tk.Label(header, text="", bg=CARD, fg=MUT,
                                      font=("Segoe UI", 10))
        self.version_label.pack(side="right")

        body = tk.Frame(self.root, bg=BG, padx=18, pady=14)
        body.pack(fill="both", expand=True)

        # Reseller table
        table_frame = tk.Frame(body, bg=BG)
        table_frame.pack(fill="x")

        tk.Label(table_frame, text="Resellers", bg=BG, fg=INK,
                 font=("Segoe UI", 11, "bold")).pack(anchor="w")

        self.tree = ttk.Treeview(
            table_frame,
            columns=("code", "name", "published", "status"),
            show="headings",
            height=6,
        )
        for column, heading, width in (
            ("code", "Code", 130),
            ("name", "Name", 200),
            ("published", "Panel has", 110),
            ("status", "After this build", 170),
        ):
            self.tree.heading(column, text=heading)
            self.tree.column(column, width=width, anchor="w")
        self.tree.pack(fill="x", pady=(6, 0))

        # Controls
        controls = tk.Frame(body, bg=BG, pady=12)
        controls.pack(fill="x")

        self.push_var = tk.BooleanVar(value=True)
        self.publish_var = tk.BooleanVar(value=True)

        tk.Checkbutton(controls, text="Push APKs to GitHub", variable=self.push_var,
                       bg=BG, fg=INK, activebackground=BG, selectcolor=CARD,
                       font=("Segoe UI", 9)).pack(side="left")
        tk.Checkbutton(controls, text="Publish links to the panel",
                       variable=self.publish_var, bg=BG, fg=INK,
                       activebackground=BG, selectcolor=CARD,
                       font=("Segoe UI", 9)).pack(side="left", padx=(12, 0))

        tk.Button(controls, text="Refresh", command=self.refresh,
                  bg=CARD, fg=INK, relief="flat", padx=14, pady=5,
                  font=("Segoe UI", 9, "bold"),
                  cursor="hand2").pack(side="right")

        notes_frame = tk.Frame(body, bg=BG)
        notes_frame.pack(fill="x", pady=(0, 10))
        tk.Label(notes_frame, text="What's new (shown in the update popup)",
                 bg=BG, fg=MUT, font=("Segoe UI", 9)).pack(anchor="w")
        self.notes_entry = tk.Entry(notes_frame, font=("Segoe UI", 10),
                                    relief="flat", bg=CARD, fg=INK)
        self.notes_entry.pack(fill="x", ipady=6, pady=(4, 0))

        self.build_button = tk.Button(
            body, text="Build new version for resellers",
            command=self.start_build,
            bg=ACCENT, fg="white", relief="flat",
            font=("Segoe UI", 12, "bold"), pady=12, cursor="hand2",
            activebackground=ACCENT, activeforeground="white",
        )
        self.build_button.pack(fill="x")

        self.progress = ttk.Progressbar(body, mode="determinate")
        self.progress.pack(fill="x", pady=(10, 0))

        self.status_label = tk.Label(body, text="Ready", bg=BG, fg=MUT,
                                     font=("Segoe UI", 9), anchor="w")
        self.status_label.pack(fill="x", pady=(6, 0))

        self.output = scrolledtext.ScrolledText(
            body, height=12, bg="#14121E", fg="#E8E6F0",
            font=("Consolas", 9), relief="flat", wrap="word",
        )
        self.output.pack(fill="both", expand=True, pady=(10, 0))
        self.output.configure(state="disabled")

    # ------------------------------------------------------------- helpers
    def log(self, message):
        self.messages.put(("log", message))

    def _poll_messages(self):
        """Drains the worker's queue on the main thread.

        Every widget update goes through here, because Tk is not thread-safe and
        touching it from the worker produces failures that look random.
        """
        try:
            while True:
                kind, payload = self.messages.get_nowait()

                if kind == "log":
                    self.output.configure(state="normal")
                    self.output.insert("end", payload + "\n")
                    self.output.see("end")
                    self.output.configure(state="disabled")
                elif kind == "progress":
                    done, total = payload
                    self.progress["maximum"] = total
                    self.progress["value"] = done
                    self.status_label.config(text="Step %d of %d" % (done, total))
                elif kind == "status":
                    self.status_label.config(text=payload)
                elif kind == "done":
                    self._on_finished(payload)
                elif kind == "resellers":
                    self._render_resellers(payload)
        except queue.Empty:
            pass

        self.root.after(80, self._poll_messages)

    def _render_resellers(self, resellers):
        self.resellers = resellers
        for row in self.tree.get_children():
            self.tree.delete(row)

        try:
            name, _ = app_version()
        except Exception:
            name = "?"

        for reseller in resellers:
            current = reseller.get("current_build") or {}
            published = current.get("version_name") or "none"
            status = "unchanged" if published == name else "will become v%s" % name

            self.tree.insert("", "end", values=(
                reseller["code"],
                reseller.get("display_name") or reseller["code"],
                published,
                status,
            ))

        if not resellers:
            self.tree.insert("", "end", values=("", "No active resellers", "", ""))

    # ------------------------------------------------------------- actions
    def refresh(self):
        try:
            name, code = app_version()
            self.version_label.config(text="App version %s+%d" % (name, code))
        except Exception as error:
            self.version_label.config(text="version unreadable")
            self.log("Could not read pubspec.yaml: %s" % error)
            return

        self.log("Asking the panel who the resellers are...")

        def work():
            try:
                resellers = fetch_resellers(self.secret)
                self.messages.put(("resellers", resellers))
                self.log("   %d active reseller(s)" % len(resellers))
            except urllib.error.HTTPError as error:
                detail = ""
                try:
                    detail = json.loads(error.read().decode("utf-8")).get("error", "")
                except Exception:
                    pass
                self.log("   panel returned HTTP %d" % error.code)
                if detail:
                    for line in explain(detail).splitlines():
                        self.log("   " + line if line else "")
            except Exception as error:
                self.log("   could not reach the panel: %s" % explain(error))

        threading.Thread(target=work, daemon=True).start()

    def start_build(self):
        if self.running:
            return

        count = len(self.resellers)
        confirm = messagebox.askyesno(
            APP_TITLE,
            "Build the house app and %d reseller APK%s?\n\n"
            "This takes several minutes and will %s."
            % (
                count,
                "" if count == 1 else "s",
                "push and publish" if (self.push_var.get() and self.publish_var.get())
                else "build locally only",
            ),
        )
        if not confirm:
            return

        self.running = True
        self.build_button.config(state="disabled", text="Building...")
        self.progress["value"] = 0

        self.run_object = BuildRun(
            secret=self.secret,
            resellers=self.resellers,
            notes=self.notes_entry.get().strip(),
            do_push=self.push_var.get(),
            do_publish=self.publish_var.get(),
            log=self.log,
            progress=lambda done, total: self.messages.put(("progress", (done, total))),
        )

        def work():
            started = time.time()
            try:
                name, code, stamped = self.run_object.execute()
                elapsed = int(time.time() - started)
                self.messages.put(("done", {
                    "ok": True,
                    "name": name,
                    "code": code,
                    "stamped": len(stamped),
                    "elapsed": elapsed,
                }))
            except Exception as error:
                self.messages.put(("done", {"ok": False, "error": str(error)}))

        threading.Thread(target=work, daemon=True).start()

    def _on_finished(self, result):
        self.running = False
        self.build_button.config(state="normal", text="Build new version for resellers")

        if result.get("ok"):
            minutes, seconds = divmod(result["elapsed"], 60)
            summary = "Done in %dm %ds - v%s, %d reseller APK(s)" % (
                minutes, seconds, result["name"], result["stamped"],
            )
            self.status_label.config(text=summary, fg=LIME)
            self.log("")
            self.log(summary)

            if self.publish_var.get() and self.push_var.get():
                self.log("Resellers can download from their portal now. Their "
                         "customers get the update prompt on the next sync.")
            self.refresh()
        else:
            self.status_label.config(text="Failed", fg=ERROR)
            self.log("")
            self.log("FAILED: %s" % result.get("error"))
            messagebox.showerror(APP_TITLE, result.get("error", "Unknown failure"))


def main():
    if not os.path.isfile(os.path.join(ROOT, "pubspec.yaml")):
        # Said plainly rather than failing later with a confusing build error.
        root = tk.Tk()
        root.withdraw()
        messagebox.showerror(
            APP_TITLE,
            "This does not look like the ClipShield project folder:\n\n%s\n\n"
            "Put the exe in the project folder and run it again." % ROOT,
        )
        return

    root = tk.Tk()
    BuilderApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
