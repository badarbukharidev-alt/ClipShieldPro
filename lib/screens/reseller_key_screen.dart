import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/reseller_api_service.dart';
import '../theme/app_theme.dart';

/// The reseller's own key desk, reached from the shield icon in Settings on a
/// reseller build.
///
/// It shows a login form until the reseller signs in, then a generator that
/// spends their allocation. Everything that matters — the password check, the
/// quota, the key — is the panel's; this screen only collects input and shows
/// the result. That is deliberate: a reseller (or anyone with their APK) must
/// not be able to mint keys the server did not authorise.
class ResellerKeyScreen extends StatefulWidget {
  const ResellerKeyScreen({super.key});

  @override
  State<ResellerKeyScreen> createState() => _ResellerKeyScreenState();
}

class _ResellerKeyScreenState extends State<ResellerKeyScreen> {
  final ResellerApiService _api = ResellerApiService.instance;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceController = TextEditingController();
  final _noteController = TextEditingController();

  ResellerTier _tier = ResellerTier.lifetime;
  int _monthlyDays = 30;
  int _videoCount = 5;

  ResellerQuotas? _quotas;
  bool _busy = false;
  bool _loadingQuotas = false;
  String? _generatedKey;
  String? _generatedInfo;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    await _api.loadSession();

    // Prefill the device field with this phone's own id, so a reseller
    // activating on the customer's handset in front of them need not retype it.
    final device = await _api.currentDeviceId();
    if (!mounted) return;
    setState(() => _deviceController.text = device);

    // A stored token survives the app closing, so on reopen we are signed in
    // with no allowance loaded. Without this the screen showed every tier as
    // "0 left" and disabled Generate.
    if (_api.isLoggedIn) await _refreshQuotas();
  }

  Future<void> _refreshQuotas() async {
    setState(() => _loadingQuotas = true);
    final result = await _api.fetchQuotas();
    if (!mounted) return;

    setState(() {
      _loadingQuotas = false;
      if (result.ok) _quotas = result.quotas;
    });

    if (!result.ok) {
      if (result.error == 'reauth_required') {
        // Token expired: fall back to the login form rather than showing a
        // generator that cannot generate.
        setState(() => _quotas = null);
      }
      _toast(_explain(result.error), error: true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _deviceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.ink,
    ));
  }

  String _explain(String? code) {
    switch (code) {
      case 'bad_credentials':
        return 'Wrong username or password.';
      case 'network':
        return 'Could not reach the server. Check your connection.';
      case 'no_allowance':
        return 'You have no keys of this type left. Ask the admin to top up.';
      case 'reauth_required':
        return 'Your session expired. Please sign in again.';
      case 'invalid_device_id':
        return 'That device ID is not valid (it looks like CS-XXXX-XXXX-XXXX).';
      case 'unavailable':
        return 'Reseller sign-in is not available in this build.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> _login() async {
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    if (user.isEmpty || pass.isEmpty) {
      _toast('Enter your username and password.', error: true);
      return;
    }

    setState(() => _busy = true);
    final result = await _api.login(user, pass);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      _passwordController.clear();
      setState(() => _quotas = result.quotas);
    } else {
      _toast(_explain(result.error), error: true);
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _loadingQuotas = false;
      _quotas = null;
      _generatedKey = null;
      _generatedInfo = null;
    });
  }

  int get _param => switch (_tier) {
        ResellerTier.monthly => _monthlyDays,
        ResellerTier.videopack => _videoCount,
        ResellerTier.lifetime => 0,
      };

  Future<void> _generate() async {
    final device = _deviceController.text.trim().toUpperCase();
    if (device.isEmpty) {
      _toast('Enter the customer\'s device ID.', error: true);
      return;
    }

    setState(() => _busy = true);
    final result = await _api.generateKey(
      deviceId: device,
      tier: _tier,
      param: _param,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.quotas != null) {
      setState(() => _quotas = result.quotas);
    }

    if (result.ok) {
      setState(() {
        _generatedKey = result.key;
        _generatedInfo = _describe(result.expires);
      });
    } else {
      if (result.error == 'reauth_required') {
        setState(() => _quotas = null); // back to the login form
      }
      _toast(_explain(result.error), error: true);
    }
  }

  String _describe(String? expires) {
    switch (_tier) {
      case ResellerTier.lifetime:
        return 'Lifetime · unlimited on-device renders';
      case ResellerTier.monthly:
        return 'Monthly · $_monthlyDays days'
            '${expires != null ? ' · expires $expires' : ''}';
      case ResellerTier.videopack:
        return 'Video pack · $_videoCount renders';
    }
  }

  void _copyKey() {
    if (_generatedKey == null) return;
    Clipboard.setData(ClipboardData(text: _generatedKey!));
    _toast('Key copied to clipboard');
  }

  Future<void> _shareKey() async {
    if (_generatedKey == null) return;
    final message = 'Here is your ClipShield Pro key:\n\n'
        'Key: $_generatedKey\n'
        'Plan: $_generatedInfo\n'
        'Device ID: ${_deviceController.text.trim()}\n\n'
        'Open ClipShield Pro → Activate Pro → paste this key.';
    final uri = Uri.parse(
        'https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}');
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
        title: const Text('Reseller Keys',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          if (_api.isLoggedIn)
            TextButton(
              onPressed: _logout,
              child: const Text('Sign out', style: TextStyle(color: AppColors.mut)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: _api.isLoggedIn ? _buildGenerator() : _buildLogin(),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- login
  Widget _buildLogin() {
    if (!_api.isAvailable) {
      return _card(
        child: const Text(
          'This build is not set up for reseller sign-in.',
          style: TextStyle(color: AppColors.mut, height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.storefront_rounded, size: 44, color: AppColors.accentTangerine),
        const SizedBox(height: 12),
        const Text('Reseller sign-in',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 4),
        const Text('Use the username and password the admin gave you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.mut)),
        const SizedBox(height: 22),
        _field(_usernameController, 'Username', icon: Icons.person_outline),
        const SizedBox(height: 12),
        _field(_passwordController, 'Password',
            icon: Icons.lock_outline, obscure: true, onSubmit: (_) => _login()),
        const SizedBox(height: 18),
        _primaryButton(_busy ? 'Signing in...' : 'Sign in', _busy ? null : _login),
      ],
    );
  }

  // -------------------------------------------------------------- generator
  Widget _buildGenerator() {
    final q = _quotas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_api.displayName.isNotEmpty)
          Text('Signed in as ${_api.displayName}',
              style: const TextStyle(fontSize: 13, color: AppColors.mut)),
        const SizedBox(height: 12),

        // Allowance
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('YOUR ALLOWANCE',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1)),
                  if (_loadingQuotas)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mut),
                    )
                  else
                    GestureDetector(
                      onTap: _refreshQuotas,
                      child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.mut),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (q == null && _loadingQuotas)
                const Text('Loading your allowance...',
                    style: TextStyle(fontSize: 13, color: AppColors.mut))
              else if (q == null)
                const Text('Could not load your allowance. Tap refresh.',
                    style: TextStyle(fontSize: 13, color: AppColors.error))
              else
                for (final tier in ResellerTier.values) _quotaRow(tier, q.of(tier)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Generated key
        if (_generatedKey != null) ...[
          _card(
            highlight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KEY GENERATED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accentLime, letterSpacing: 1)),
                const SizedBox(height: 8),
                SelectableText(_generatedKey!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_generatedInfo ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.mut)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _outlineButton('Copy', Icons.copy_rounded, _copyKey)),
                  const SizedBox(width: 10),
                  Expanded(child: _outlineButton('WhatsApp', Icons.chat_rounded, _shareKey)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Generate form
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GENERATE A KEY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mut, letterSpacing: 1)),
              const SizedBox(height: 12),
              _field(_deviceController, 'Customer device ID (CS-XXXX-XXXX-XXXX)',
                  icon: Icons.smartphone_outlined),
              const SizedBox(height: 12),
              _tierSelector(),
              if (_tier == ResellerTier.monthly) _stepper('Days', _monthlyDays, 7, 365,
                  (v) => setState(() => _monthlyDays = v)),
              if (_tier == ResellerTier.videopack) _stepper('Videos', _videoCount, 1, 200,
                  (v) => setState(() => _videoCount = v)),
              const SizedBox(height: 12),
              _field(_noteController, 'Note (optional, for your records)',
                  icon: Icons.sticky_note_2_outlined),
              const SizedBox(height: 16),
              _primaryButton(
                _busy ? 'Generating...' : 'Generate key',
                // Only blocked on a *known* zero. An allowance that has not
                // loaded yet is unknown, not empty -- the server enforces the
                // real limit either way.
                (_busy || _loadingQuotas || (q != null && q.of(_tier) <= 0))
                    ? null
                    : _generate,
              ),
              if (q != null && q.of(_tier) <= 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('No keys of this type left in your allowance.',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quotaRow(ResellerTier tier, int remaining) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tier.label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: remaining > 0 ? AppColors.softLime : AppColors.line,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$remaining left',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: remaining > 0 ? AppColors.accentLime : AppColors.mut)),
          ),
        ],
      ),
    );
  }

  Widget _tierSelector() {
    return Row(
      children: [
        for (final tier in ResellerTier.values)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tier = tier),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _tier == tier ? AppColors.accentTangerine : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _tier == tier ? AppColors.accentTangerine : AppColors.line),
                ),
                child: Text(
                  tier.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _tier == tier ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppColors.mut),
              onPressed: value > min ? () => onChanged(value - (label == 'Days' ? 1 : 1)) : null,
            ),
            Text('$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.accentTangerine),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ]),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- widgets
  Widget _card({required Widget child, bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: highlight ? AppColors.accentLime : AppColors.line),
      ),
      child: child,
    );
  }

  Widget _field(TextEditingController controller, String hint,
      {IconData? icon, bool obscure = false, ValueChanged<String>? onSubmit}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20, color: AppColors.mut) : null,
        filled: true,
        fillColor: AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentTangerine,
        disabledBackgroundColor: AppColors.line,
        foregroundColor: Colors.white,
        disabledForegroundColor: AppColors.mut,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
