import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/license_service.dart';
import '../theme/app_theme.dart';

class AdminLicenseScreen extends StatefulWidget {
  const AdminLicenseScreen({super.key});

  @override
  State<AdminLicenseScreen> createState() => _AdminLicenseScreenState();
}

class _AdminLicenseScreenState extends State<AdminLicenseScreen> {
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  LicenseTier _selectedTier = LicenseTier.monthly;
  int _monthlyDays = 30;
  int _videoPackCount = 5;

  String? _generatedKey;
  String? _generatedDetails;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _generateKey() {
    final devId = _deviceIdController.text.trim();
    if (devId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter or paste the customer Device ID (CS-XXXX-XXXX-XXXX)"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String key;
    String details;

    if (_selectedTier == LicenseTier.lifetime) {
      key = LicenseService.generateLifetimeKey(devId);
      details = "Lifetime License · Unlimited On-Device Renders";
    } else if (_selectedTier == LicenseTier.monthly) {
      key = LicenseService.generateMonthlyKey(devId, days: _monthlyDays);
      details = "Monthly License · Valid for $_monthlyDays Days";
    } else {
      key = LicenseService.generateVideoPackKey(devId, videoCount: _videoPackCount);
      details = "Video Pack · $_videoPackCount Renders Valid";
    }

    setState(() {
      _generatedKey = key;
      _generatedDetails = details;
    });
  }

  void _copyKey() {
    if (_generatedKey == null) return;
    Clipboard.setData(ClipboardData(text: _generatedKey!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Activation Key copied to clipboard!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _shareToWhatsApp() async {
    if (_generatedKey == null) return;
    final devId = _deviceIdController.text.trim();
    final message = "Hello! Here is your ClipShield Pro Activation Key:\n\n"
        "Key: $_generatedKey\n"
        "Plan: $_generatedDetails\n"
        "Device ID: $devId\n\n"
        "To activate: Open ClipShield Pro -> Tap 'Activate Pro' -> Paste Key -> Enjoy!";

    final phone = _phoneController.text.replaceAll('+', '').replaceAll(' ', '').trim();
    final uri = phone.isNotEmpty
        ? Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}")
        : Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Admin Key Generator",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softTangerine,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentTangerine.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppColors.accentTangerine, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Owner License Console: Generate cryptographically signed keys for Monthly, Lifetime, or Video Packs.",
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Customer Device ID Input
              const Text(
                "Customer Device ID",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: AppColors.mut, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _deviceIdController,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: "CS-XXXX-XXXX-XXXX",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: AppColors.mut),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_paste, color: AppColors.accentTangerine, size: 20),
                      tooltip: "Paste Device ID",
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          setState(() => _deviceIdController.text = data!.text!.trim());
                        }
                      },
                    ),
                    TextButton(
                      child: const Text("My Device", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final myId = await LicenseService.instance.getDeviceId();
                        setState(() => _deviceIdController.text = myId);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Select License Tier
              const Text(
                "Select License Plan",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTierCard(
                      tier: LicenseTier.monthly,
                      title: "1 Month",
                      subtitle: "30 Days Access",
                      icon: Icons.calendar_month,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTierCard(
                      tier: LicenseTier.lifetime,
                      title: "Lifetime",
                      subtitle: "Permanent Pro",
                      icon: Icons.all_inclusive,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTierCard(
                      tier: LicenseTier.videoPack,
                      title: "Video Pack",
                      subtitle: "Pay Per Render",
                      icon: Icons.video_library,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom configuration for Video Pack or Month duration
              if (_selectedTier == LicenseTier.videoPack) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Allowed Video Count:", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          Text("$_videoPackCount Videos", style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.accentTangerine)),
                        ],
                      ),
                      Slider(
                        value: _videoPackCount.toDouble(),
                        min: 1,
                        max: 50,
                        divisions: 49,
                        activeColor: AppColors.accentTangerine,
                        onChanged: (v) => setState(() => _videoPackCount = v.round()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [3, 5, 10, 20, 30].map((count) {
                          return GestureDetector(
                            onTap: () => setState(() => _videoPackCount = count),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _videoPackCount == count ? AppColors.accentTangerine : AppColors.softTangerine,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "$count",
                                style: TextStyle(
                                  color: _videoPackCount == count ? Colors.white : AppColors.ink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_selectedTier == LicenseTier.monthly) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Validity Period:", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      DropdownButton<int>(
                        value: _monthlyDays,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 7, child: Text("7 Days")),
                          DropdownMenuItem(value: 15, child: Text("15 Days")),
                          DropdownMenuItem(value: 30, child: Text("30 Days (1 Month)")),
                          DropdownMenuItem(value: 60, child: Text("60 Days (2 Months)")),
                          DropdownMenuItem(value: 90, child: Text("90 Days (3 Months)")),
                        ],
                        onChanged: (v) => setState(() => _monthlyDays = v ?? 30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Customer WhatsApp Phone (Optional)
              const Text(
                "Customer WhatsApp Number (Optional)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: "923001234567",
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: AppColors.mut),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Generate Button
              ElevatedButton.icon(
                icon: const Icon(Icons.vpn_key_rounded, color: Colors.white),
                label: const Text(
                  "GENERATE ACTIVATION KEY",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentTangerine,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: _generateKey,
              ),
              const SizedBox(height: 24),

              // Generated Key Output Box
              if (_generatedKey != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accentTangerine, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentTangerine.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentTangerine,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedTier.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ),
                          Text(
                            _generatedDetails ?? "",
                            style: const TextStyle(color: AppColors.mut, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SelectableText(
                        _generatedKey!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppColors.ink,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.copy, size: 18, color: AppColors.ink),
                              label: const Text("Copy Key", style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                              onPressed: _copyKey,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send, size: 18, color: Colors.white),
                              label: const Text("WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                              onPressed: _shareToWhatsApp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard({
    required LicenseTier tier,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedTier == tier;
    return GestureDetector(
      onTap: () => setState(() => _selectedTier = tier),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.softTangerine : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accentTangerine : AppColors.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.accentTangerine : AppColors.mut, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: isSelected ? AppColors.accentTangerine : AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: AppColors.mut),
            ),
          ],
        ),
      ),
    );
  }
}
