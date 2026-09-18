import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tasks_screen.dart';
import '../services/build_identity.dart';
import '../services/license_service.dart';
import '../theme/app_theme.dart';

/// Sleek modal dialog for ClipShield Pro licensing, Device ID extraction,
/// WhatsApp key acquisition, and instant cryptographic key activation.
class ActivationDialog extends StatefulWidget {
  const ActivationDialog({super.key});

  /// Convenience method to display the ActivationDialog modal.
  /// Returns `true` if the device was successfully activated.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ActivationDialog(),
    );
    return result ?? false;
  }

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final LicenseService _licenseService = LicenseService.instance;
  final TextEditingController _keyController = TextEditingController();

  String _deviceId = "Loading...";
  bool _isLoading = true;
  bool _isActivating = false;
  bool _copied = false;
  String? _statusMessage;
  bool? _isKeyValid;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _keyController.addListener(_onKeyInputChanged);
  }

  @override
  void dispose() {
    _keyController.removeListener(_onKeyInputChanged);
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    await _licenseService.init();
    final id = await _licenseService.getDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = id;
        _isLoading = false;
      });
    }
  }

  void _onKeyInputChanged() {
    final text = _keyController.text.trim();
    final clean = text.replaceAll('-', '').replaceAll(' ', '');

    if (clean.length == 16) {
      final isValid = LicenseService.verifyKey(clean, _deviceId);
      setState(() {
        _isKeyValid = isValid;
        _statusMessage = isValid
            ? "Valid cryptographic key detected!"
            : "Key does not match this Device ID.";
      });
    } else if (clean.isEmpty) {
      setState(() {
        _isKeyValid = null;
        _statusMessage = null;
      });
    } else {
      setState(() {
        _isKeyValid = null;
        _statusMessage = "${clean.length}/16 characters entered";
      });
    }
  }

  Future<void> _copyDeviceId() async {
    if (_deviceId.isEmpty || _isLoading) return;
    await Clipboard.setData(ClipboardData(text: _deviceId));
    setState(() => _copied = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Device ID copied: $_deviceId"),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _pasteKey() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      _keyController.text = LicenseService.formatKey(data.text!.trim());
      _keyController.selection = TextSelection.fromPosition(
        TextPosition(offset: _keyController.text.length),
      );
    }
  }

  Future<void> _orderViaWhatsApp() async {
    final url = _licenseService.getWhatsAppUrl(_deviceId);
    final uri = Uri.parse(url);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _fallbackWhatsAppNotification();
      }
    } catch (_) {
      if (mounted) _fallbackWhatsAppNotification();
    }
  }

  void _fallbackWhatsAppNotification() {
    Clipboard.setData(ClipboardData(text: _licenseService.getWhatsAppUrl(_deviceId)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "WhatsApp link copied to clipboard (${LicenseService.supportPhone})"),
        backgroundColor: AppColors.ink,
      ),
    );
  }

  Future<void> _submitActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _isActivating = true);

    final success = await _licenseService.activate(key);

    if (!mounted) return;
    setState(() => _isActivating = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.card,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.softLime,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.accentLime, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                "ClipShield Pro Activated!",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _licenseService.statusDescription,
                style: const TextStyle(color: AppColors.mut, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentLime,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text("Start Creating", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text("Invalid activation key. Please double-check or contact support."),
        ),
      );
    }
  }

  /// Takes the user to the tasks screen, where trial renders are earned.
  void _openFreeVideos() {
    // The dialog closes first so tapping back from Tasks returns to the app
    // rather than to a dialog asking for a licence key again.
    Navigator.pop(context, false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TasksScreen()),
    );
  }

  Widget _buildEarnFreeCta() {
    final int available = _licenseService.bonusAvailable;

    return GestureDetector(
      onTap: _openFreeVideos,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.softLime,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentLime),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accentLime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard_rounded,
                  color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    available > 0
                        ? "You have $available free ${available == 1 ? 'video' : 'videos'}"
                        : "Get free videos",
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    available > 0
                        ? "Tap to use them, or earn more"
                        : "Complete quick tasks to unlock more renders",
                    style: const TextStyle(fontSize: 11.5, color: AppColors.mut),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.accentLime),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = _licenseService.isActivated();

    return Dialog(
      backgroundColor: AppColors.card,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPro ? AppColors.softLime : AppColors.softTangerine,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPro ? Icons.verified : Icons.lock_outline_rounded,
                          size: 14,
                          color: isPro ? AppColors.accentLime : AppColors.accentTangerine,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isPro ? "LIFETIME PRO ACTIVE" : "PRO ACTIVATION",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isPro ? AppColors.accentLime : AppColors.accentTangerine,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.mut),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context, isPro),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title & Description
              const Text(
                "Unlock ClipShield Pro",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPro
                    ? "Your installation is verified and active with unrestricted on-device exports."
                    : "You have used your free trial export. Earn more free videos by completing quick tasks, or activate lifetime access for unlimited exports.",
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mut,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // The free route, offered before the paid one.
              //
              // This dialog appears exactly when someone has run out of trial
              // renders, which is the moment they most need to know that free
              // ones are earnable -- and until now the only options on screen
              // were "buy a key" or "close".
              if (!isPro && !BuildIdentity.isResellerBuild) _buildEarnFreeCta(),

              const SizedBox(height: 20),

              // Hardware Device ID Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "YOUR UNIQUE DEVICE ID",
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mut,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _deviceId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.ink,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _copyDeviceId,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _copied ? AppColors.softLime : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _copied ? AppColors.accentLime : AppColors.line,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.copy_rounded,
                                  size: 14,
                                  color: _copied ? AppColors.accentLime : AppColors.ink,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _copied ? "Copied" : "Copy",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _copied ? AppColors.accentLime : AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // WhatsApp Order Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _orderViaWhatsApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: Text(
                    "Order Key via WhatsApp (${LicenseService.supportPhone})",
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              const Divider(color: AppColors.line, height: 1),
              const SizedBox(height: 18),

              // Key Input Section
              const Text(
                "ENTER ACTIVATION KEY",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mut,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _keyController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 1.5,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: "XXXX-XXXX-XXXX-XXXX",
                  hintStyle: const TextStyle(
                    fontFamily: 'monospace',
                    color: AppColors.mut,
                    letterSpacing: 1.2,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isKeyValid != null)
                        Icon(
                          _isKeyValid! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _isKeyValid! ? AppColors.accentLime : AppColors.error,
                        ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18, color: AppColors.mut),
                        tooltip: "Paste from Clipboard",
                        onPressed: _pasteKey,
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _isKeyValid == true
                          ? AppColors.accentLime
                          : (_isKeyValid == false ? AppColors.error : AppColors.line),
                      width: _isKeyValid != null ? 1.5 : 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _isKeyValid == true ? AppColors.accentLime : AppColors.accentTangerine,
                      width: 1.8,
                    ),
                  ),
                ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isKeyValid == true
                          ? AppColors.accentLime
                          : (_isKeyValid == false ? AppColors.error : AppColors.mut),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // Submit Activation Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isActivating || _isKeyValid == false) ? null : _submitActivation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTangerine,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isActivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Activate ClipShield Pro",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
