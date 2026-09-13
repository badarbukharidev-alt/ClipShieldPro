import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/license_service.dart';
import '../services/project_storage_service.dart';
import '../theme/app_theme.dart';
import 'activation_dialog.dart';
import 'admin_license_screen.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _openRouterController = TextEditingController();
  final TextEditingController _groqController = TextEditingController();
  final TextEditingController _cerebrasController = TextEditingController();

  String _exportQuality = "1080p";
  String _selectedAiProvider = "gemini";
  String _licenseStatus = "Trial";
  String _deviceId = "CS-DEV-SCANNING";
  bool _obscureKeys = true;

  int _adminTapCount = 0;
  DateTime? _lastAdminTapTime;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _handleAdminSecretTap() {
    final now = DateTime.now();
    if (_lastAdminTapTime == null || now.difference(_lastAdminTapTime!).inSeconds > 2) {
      _adminTapCount = 1;
    } else {
      _adminTapCount++;
    }
    _lastAdminTapTime = now;

    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _promptAdminPasscode();
    } else if (_adminTapCount >= 2) {
      final remaining = 5 - _adminTapCount;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text("Developer mode: tap $remaining more times"),
          backgroundColor: AppColors.darkCard,
        ),
      );
    }
  }

  Future<void> _promptAdminPasscode() async {
    final pinController = TextEditingController();
    final bool? isAuthed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: AppColors.accentTangerine, size: 24),
            SizedBox(width: 10),
            Text("Admin Authentication", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter master admin passcode to access license key generator:",
              style: TextStyle(color: AppColors.mut, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 3, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Admin Passcode",
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.line)),
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.mut),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: AppColors.mut)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTangerine,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin == "7860" || pin == "9922" || pin == "admin2026") {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Access Denied: Incorrect Admin Passcode"),
                    backgroundColor: AppColors.error,
                  ),
                );
                Navigator.pop(ctx, false);
              }
            },
            child: const Text("Unlock"),
          ),
        ],
      ),
    );

    if (isAuthed == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminLicenseScreen(isAuthenticated: true)),
      );
    }
  }

  Future<void> _loadSettings() async {
    final gemini = await ProjectStorageService.getGeminiApiKey();
    final openRouter = await ProjectStorageService.getOpenRouterApiKey();
    final groq = await ProjectStorageService.getGroqApiKey();
    final cerebras = await ProjectStorageService.getCerebrasApiKey();
    final quality = await ProjectStorageService.getExportQuality();
    final provider = await ProjectStorageService.getSelectedAiProvider();
    final license = await ProjectStorageService.getLicenseStatus();
    final deviceId = await ProjectStorageService.getDeviceId();

    if (!mounted) return;
    setState(() {
      _geminiController.text = gemini ?? "";
      _openRouterController.text = openRouter ?? "";
      _groqController.text = groq ?? "";
      _cerebrasController.text = cerebras ?? "";
      _exportQuality = quality;
      _selectedAiProvider = provider;
      _licenseStatus = license;
      _deviceId = deviceId;
    });
  }

  Future<void> _saveSettings() async {
    await ProjectStorageService.setGeminiApiKey(_geminiController.text.trim());
    await ProjectStorageService.setOpenRouterApiKey(_openRouterController.text.trim());
    await ProjectStorageService.setGroqApiKey(_groqController.text.trim());
    await ProjectStorageService.setCerebrasApiKey(_cerebrasController.text.trim());
    await ProjectStorageService.setSelectedAiProvider(_selectedAiProvider);
    await ProjectStorageService.setExportQuality(_exportQuality);
    await ProjectStorageService.setLicenseStatus(_licenseStatus);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Settings and AI configuration saved successfully!"),
        backgroundColor: AppColors.accentLime,
      ),
    );
  }

  Future<void> _launchWhatsAppSupport() async {
    final url = Uri.parse(LicenseService.instance.getWhatsAppUrl(_deviceId));

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open WhatsApp: $e")),
      );
    }
  }

  Future<void> _showActivationDialog() async {
    final activated = await ActivationDialog.show(context);
    if (activated) {
      await _loadSettings();
    }
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openRouterController.dispose();
    _groqController.dispose();
    _cerebrasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActivated = _licenseStatus.toLowerCase() == "activated";

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Admin Access",
            icon: const Icon(Icons.shield_outlined, color: AppColors.mut, size: 20),
            onPressed: _promptAdminPasscode,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card with Developer Secret Tap
            GestureDetector(
              onTap: _handleAdminSecretTap,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkCard,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ClipShield Studio", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        SizedBox(height: 2),
                        Text("On-device engine · Standalone", style: TextStyle(color: AppColors.mut, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActivated ? AppColors.softLime : AppColors.softTangerine,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isActivated ? "ACTIVATED" : "TRIAL",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isActivated ? AppColors.accentLime : AppColors.accentTangerine,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

            // License & Activation Group
            const Text(
              "LICENSE & DEVICE IDENTIFICATION",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("License Status", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          SizedBox(height: 2),
                          Text("ClipShield Pro Commercial License", style: TextStyle(color: AppColors.mut, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActivated ? AppColors.softLime : AppColors.softTangerine,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActivated ? Icons.check_circle : Icons.hourglass_top_rounded,
                              size: 14,
                              color: isActivated ? AppColors.accentLime : AppColors.accentTangerine,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isActivated ? "Activated (Pro)" : "Trial (Evaluation)",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isActivated ? AppColors.accentLime : AppColors.accentTangerine,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.line),

                  // Device ID row
                  const Text("Device ID", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  const Text(
                    "Your unique on-device machine fingerprint for license generation.",
                    style: TextStyle(color: AppColors.mut, fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fingerprint_rounded, size: 20, color: AppColors.mut),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SelectableText(
                            _deviceId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _deviceId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Device ID copied to clipboard")),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action buttons: WhatsApp link & License Code dialog
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchWhatsAppSupport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text("WhatsApp Activation", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _showActivationDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          isActivated ? "License Details" : "Enter Key",
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI API Configuration Group
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "ARTIFICIAL INTELLIGENCE",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
                ),
                InkWell(
                  onTap: () => setState(() => _obscureKeys = !_obscureKeys),
                  child: Row(
                    children: [
                      Icon(_obscureKeys ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 14, color: AppColors.mut),
                      const SizedBox(width: 4),
                      Text(_obscureKeys ? "Show Keys" : "Hide Keys", style: const TextStyle(fontSize: 11.5, color: AppColors.mut)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Provider Picker
                  const Text("Active AI Provider", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAiProvider,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink),
                        items: const [
                          DropdownMenuItem(
                            value: "gemini",
                            child: Text("Google Gemini 1.5 Flash (Recommended)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: "openrouter",
                            child: Text("OpenRouter (Gemini 2.0 / LLaMA 3.3)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: "groq",
                            child: Text("Groq (LLaMA-3.3-70B-Versatile)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: "cerebras",
                            child: Text("Cerebras (LLaMA-3.1-70B Ultra-Fast)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                          DropdownMenuItem(
                            value: "heuristic",
                            child: Text("Uniform Segment (Offline Heuristic)", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAiProvider = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Google Gemini Key
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.accentTangerine),
                      SizedBox(width: 6),
                      Text("Google Gemini API Key (1.5 Flash)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _geminiController,
                    obscureText: _obscureKeys,
                    decoration: InputDecoration(
                      hintText: "AIzaSy...",
                      hintStyle: const TextStyle(color: AppColors.mut, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. OpenRouter Key
                  const Row(
                    children: [
                      Icon(Icons.hub_outlined, size: 16, color: AppColors.accentGrape),
                      SizedBox(width: 6),
                      Text("OpenRouter API Key (Gemini 2.0 / LLaMA 3.3)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _openRouterController,
                    obscureText: _obscureKeys,
                    decoration: InputDecoration(
                      hintText: "sk-or-v1-...",
                      hintStyle: const TextStyle(color: AppColors.mut, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Groq Key
                  const Row(
                    children: [
                      Icon(Icons.speed_rounded, size: 16, color: AppColors.accentOcean),
                      SizedBox(width: 6),
                      Text("Groq API Key (LLaMA-3.3-70B)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _groqController,
                    obscureText: _obscureKeys,
                    decoration: InputDecoration(
                      hintText: "gsk_...",
                      hintStyle: const TextStyle(color: AppColors.mut, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Cerebras Key
                  const Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 16, color: AppColors.accentLime),
                      SizedBox(width: 6),
                      Text("Cerebras API Key (LLaMA-3.1-70B)", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cerebrasController,
                    obscureText: _obscureKeys,
                    decoration: InputDecoration(
                      hintText: "csk-...",
                      hintStyle: const TextStyle(color: AppColors.mut, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Optional: If keys are omitted or network is unavailable, ClipShield falls back to its built-in offline mathematical heuristic.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.mut, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Output Group
            const Text(
              "OUTPUT SETTINGS",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.2),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Export Resolution", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      DropdownButton<String>(
                        value: _exportQuality,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: "1080p", child: Text("1080p (FHD)")),
                          DropdownMenuItem(value: "720p", child: Text("720p (HD)")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _exportQuality = val);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppColors.line),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Target Social Canvas", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      Text("9:16 Vertical", style: TextStyle(color: AppColors.mut, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Diagnostics Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
              },
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text("Run Engine Diagnostics"),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),

            // Save Settings
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text("Save Configuration"),
            ),
            const SizedBox(height: 28),

            // Legal & Safe Positioning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "LEGAL & SAFETY POSITIONING",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1.0),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "ClipShield Pro is an authorized content editing, dynamic reframing, and transformation suite. Users are solely responsible for ensuring they possess the necessary rights, licenses, or permissions for all media imported or processed. ClipShield Pro does not defeat Content ID, DRM, copyright enforcement, or authentication systems, and technical modifications do not constitute automatic copyright clearance.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.mut, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
