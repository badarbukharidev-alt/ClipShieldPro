#!/usr/bin/env python3
"""Stamps a reseller code into a finished APK and re-signs it.

This is what makes one build serve every reseller. The reseller code lives in a
bundled asset rather than a compile-time constant, so producing a reseller's APK
is: copy the base, rewrite one small file inside it, align, sign. Seconds,
instead of a full AOT compile each.

Rewriting anything inside an APK invalidates its signature, so re-signing is not
optional -- Android will refuse to install an APK whose v2 signature no longer
matches its contents. The keystore used is the same one the Gradle build uses,
read from android/key.properties, so a stamped APK installs over an existing
ClipShield exactly like an ordinary update.

Usage:
    python tools/stamp_reseller.py <base.apk> <code> <out.apk>

Exits non-zero with a plain message on any failure; the caller treats that as
"this reseller did not get a build" rather than carrying on.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

# Where the asset ends up inside a Flutter release APK.
ASSET_IN_APK = "assets/flutter_assets/assets/build/reseller.txt"

CODE_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]{1,31}$")


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(1)


def find_build_tool(name):
    """Locates a build-tools executable, newest version first."""
    sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if not sdk:
        # The Flutter default on Windows, and what this project uses.
        for guess in [r"D:\tools\android-sdk", os.path.expanduser("~/Android/Sdk")]:
            if os.path.isdir(guess):
                sdk = guess
                break

    if not sdk or not os.path.isdir(sdk):
        fail("Android SDK not found. Set ANDROID_HOME.")

    root = os.path.join(sdk, "build-tools")
    if not os.path.isdir(root):
        fail("No build-tools in " + root)

    # Newest first, so a stamped APK is signed by the same tooling the Gradle
    # build would have used.
    for version in sorted(os.listdir(root), reverse=True):
        for candidate in (name, name + ".bat", name + ".exe"):
            path = os.path.join(root, version, candidate)
            if os.path.isfile(path):
                return path

    fail("Could not find %s in any build-tools version under %s" % (name, root))


def read_key_properties(project_root):
    """Signing config, from the same file Gradle reads."""
    path = os.path.join(project_root, "android", "key.properties")
    if not os.path.isfile(path):
        fail(
            "android/key.properties is missing, so the stamped APK could not be "
            "signed. An unsigned or debug-signed APK will not install over an "
            "existing ClipShield."
        )

    props = {}
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            props[key.strip()] = value.strip()

    for required in ("storePassword", "keyPassword", "keyAlias", "storeFile"):
        if required not in props:
            fail("android/key.properties is missing " + required)

    store = props["storeFile"]
    if not os.path.isabs(store):
        # Gradle resolves storeFile relative to the android/ directory.
        store = os.path.normpath(os.path.join(project_root, "android", store))
    if not os.path.isfile(store):
        fail("Keystore not found at " + store)
    props["storeFile"] = store

    return props


def rewrite_asset(base_apk, code, staged_apk):
    """Copies the APK, replacing the reseller asset.

    The whole archive is rewritten rather than patched in place. A zip entry
    cannot simply grow or shrink where it sits, and a half-patched APK that
    still looks valid is far worse than one that plainly failed.
    """
    with zipfile.ZipFile(base_apk, "r") as source:
        if ASSET_IN_APK not in source.namelist():
            fail(
                "%s is not in the APK. The base build must include "
                "assets/build/ -- check pubspec.yaml." % ASSET_IN_APK
            )

        with zipfile.ZipFile(staged_apk, "w", zipfile.ZIP_DEFLATED) as target:
            for item in source.infolist():
                if item.filename == ASSET_IN_APK:
                    # Written with the same compression as the rest, so nothing
                    # downstream has to special-case it.
                    target.writestr(item.filename, code.encode("utf-8"))
                    continue

                data = source.read(item.filename)
                # Preserve STORED entries as STORED: resources.arsc and some
                # native libraries must stay uncompressed on modern Android.
                if item.compress_type == zipfile.ZIP_STORED:
                    info = zipfile.ZipInfo(item.filename, date_time=item.date_time)
                    info.compress_type = zipfile.ZIP_STORED
                    info.external_attr = item.external_attr
                    target.writestr(info, data)
                else:
                    target.writestr(item, data)


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)

    base_apk, code, out_apk = sys.argv[1], sys.argv[2].strip().lower(), sys.argv[3]

    if not os.path.isfile(base_apk):
        fail("Base APK not found: " + base_apk)

    # The same rule the panel and the app apply. A code that fails here would
    # produce an APK the app reads as a house build.
    if not CODE_PATTERN.match(code):
        fail('"%s" is not a valid reseller code.' % code)

    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    props = read_key_properties(project_root)

    zipalign = find_build_tool("zipalign")
    apksigner = find_build_tool("apksigner")

    workdir = tempfile.mkdtemp(prefix="cs_stamp_")
    staged = os.path.join(workdir, "staged.apk")
    aligned = os.path.join(workdir, "aligned.apk")

    try:
        rewrite_asset(base_apk, code, staged)

        # Alignment has to happen before signing: zipalign rewrites offsets, and
        # doing it afterwards would break the signature it just verified.
        subprocess.run(
            [zipalign, "-p", "-f", "4", staged, aligned],
            check=True,
            capture_output=True,
        )

        os.makedirs(os.path.dirname(os.path.abspath(out_apk)) or ".", exist_ok=True)

        subprocess.run(
            [
                apksigner,
                "sign",
                # v4 writes a separate .idsig alongside the APK, which is only
                # used by incremental ADB installs and is pure noise in a
                # distribution folder.
                "--v4-signing-enabled", "false",
                "--ks", props["storeFile"],
                "--ks-key-alias", props["keyAlias"],
                "--ks-pass", "pass:" + props["storePassword"],
                "--key-pass", "pass:" + props["keyPassword"],
                "--out", out_apk,
                aligned,
            ],
            check=True,
            capture_output=True,
        )

        # Verified rather than assumed. A signature that does not check out here
        # becomes "App not installed" on a customer's phone with no explanation.
        subprocess.run(
            [apksigner, "verify", out_apk],
            check=True,
            capture_output=True,
        )

    except subprocess.CalledProcessError as error:
        detail = (error.stderr or b"").decode("utf-8", "replace").strip()
        fail("%s failed:\n%s" % (os.path.basename(error.cmd[0]), detail))
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    size_mb = os.path.getsize(out_apk) / (1024 * 1024)
    print("  stamped %-20s -> %s (%.1f MB)" % (code, out_apk, size_mb))


if __name__ == "__main__":
    main()
