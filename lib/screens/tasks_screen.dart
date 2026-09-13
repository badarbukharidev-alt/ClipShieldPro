import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reward_task.dart';
import '../services/license_service.dart';
import '../services/task_api_service.dart';
import '../theme/app_theme.dart';

/// Earn free render credits by completing tasks.
///
/// Completion is on the honour system: no public API can tell us whether the
/// user actually followed an account, so the task is credited when they return
/// from the link. Abuse is bounded server-side by a one-claim-per-task rule, a
/// minimum dwell time, a lifetime cap, and per-IP limits.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<RewardTask> _tasks = [];
  CreditBalance _balance = const CreditBalance();
  bool _isLoading = true;
  bool _failed = false;
  int? _claimingId;

  /// When the user left for a task's link, so dwell time can be measured.
  final Map<int, DateTime> _openedAt = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failed = false;
    });

    final result = await TaskApiService.instance.fetchTasks();
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _failed = true;
      });
      return;
    }

    await LicenseService.instance
        .applyBonusBalance(result.balance.earned, result.balance.used);

    if (!mounted) return;
    setState(() {
      _tasks = result.tasks;
      _balance = result.balance;
      _isLoading = false;
    });
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.darkCard,
      ));
  }

  Future<void> _openTask(RewardTask task) async {
    final uri = Uri.tryParse(task.actionUrl);
    if (uri == null) {
      _notify('This task has an invalid link', isError: true);
      return;
    }

    _openedAt[task.id] = DateTime.now();
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _notify('Could not open the link', isError: true);
      }
    } catch (_) {
      _notify('Could not open the link', isError: true);
    }
  }

  Future<void> _claim(RewardTask task) async {
    final opened = _openedAt[task.id];
    if (opened == null) {
      _notify('Open the link first, then come back to claim');
      return;
    }

    final dwell = DateTime.now().difference(opened).inSeconds;
    if (dwell < task.minDwellSeconds) {
      final wait = task.minDwellSeconds - dwell;
      _notify('Give it $wait more second${wait == 1 ? '' : 's'}');
      return;
    }

    setState(() => _claimingId = task.id);
    final result = await TaskApiService.instance.claimTask(task.id, dwellSeconds: dwell);
    if (!mounted) return;
    setState(() => _claimingId = null);

    if (!result.ok) {
      _notify(result.message, isError: true);
      // The server may know it was already claimed; refresh to match.
      if (result.error == 'already_claimed') _load();
      return;
    }

    final balance = result.balance;
    if (balance != null) {
      await LicenseService.instance.applyBonusBalance(balance.earned, balance.used);
    }
    if (!mounted) return;

    setState(() {
      _tasks = _tasks
          .map((t) => t.id == task.id ? t.copyWith(claimed: true) : t)
          .toList();
      if (balance != null) _balance = balance;
    });

    _notify('+${result.awarded} free video unlocked');
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'whatsapp':
        return Icons.chat_bubble_outline;
      case 'youtube':
        return Icons.smart_display_outlined;
      case 'facebook':
        return Icons.facebook_outlined;
      case 'tiktok':
        return Icons.music_note_outlined;
      case 'telegram':
        return Icons.send_outlined;
      case 'star':
        return Icons.star_outline;
      default:
        return Icons.public;
    }
  }

  Color _colorFor(String name) {
    switch (name) {
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'whatsapp':
        return const Color(0xFF25D366);
      case 'youtube':
        return const Color(0xFFFF0033);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'telegram':
        return const Color(0xFF229ED9);
      case 'tiktok':
        return AppColors.ink;
      default:
        return AppColors.accentGrape;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Free Videos',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.accentTangerine,
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentTangerine))
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 18),
                  if (_failed)
                    _buildUnavailable()
                  else if (!_balance.tasksEnabled)
                    _buildMessage(
                      icon: Icons.pause_circle_outline,
                      title: 'Rewards paused',
                      body: 'Free video tasks are temporarily unavailable. Check back soon.',
                    )
                  else if (_tasks.isEmpty)
                    _buildMessage(
                      icon: Icons.inbox_outlined,
                      title: 'No tasks right now',
                      body: 'New ways to earn free videos will appear here.',
                    )
                  else ...[
                    const Text(
                      'COMPLETE A TASK, EARN A VIDEO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mut,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._tasks.map(_buildTaskCard),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final available = _balance.available;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E28), Color(0xFF14141E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FREE VIDEOS AVAILABLE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.accentTangerine,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$available',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                available == 1 ? 'video' : 'videos',
                style: const TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Earned ${_balance.earned} of ${_balance.maxCredits} · used ${_balance.used}',
            style: const TextStyle(fontSize: 12, color: AppColors.mut),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _balance.maxCredits == 0
                  ? 0
                  : (_balance.earned / _balance.maxCredits).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentTangerine),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(RewardTask task) {
    final accent = _colorFor(task.icon);
    final isClaiming = _claimingId == task.id;
    final opened = _openedAt.containsKey(task.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.claimed ? AppColors.line : accent.withOpacity(0.35),
          width: task.claimed ? 1 : 1.4,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(task.claimed ? 0.08 : 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  task.claimed ? Icons.check_rounded : _iconFor(task.icon),
                  color: task.claimed ? AppColors.accentLime : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: task.claimed ? AppColors.mut : AppColors.ink,
                        decoration: task.claimed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.mut),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: task.claimed ? AppColors.softLime : AppColors.softTangerine,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  task.claimed ? 'DONE' : '+${task.rewardCredits}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: task.claimed ? AppColors.accentLime : AppColors.accentTangerine,
                  ),
                ),
              ),
            ],
          ),
          if (!task.claimed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isClaiming ? null : () => _openTask(task),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(opened ? 'Open again' : 'Open'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withOpacity(0.5)),
                      minimumSize: const Size.fromHeight(42),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: (!opened || isClaiming) ? null : () => _claim(task),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: isClaiming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('I did it'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnavailable() {
    return _buildMessage(
      icon: Icons.wifi_off_rounded,
      title: TaskApiService.isConfigured ? 'Cannot reach rewards' : 'Rewards not set up',
      body: TaskApiService.isConfigured
          ? 'Check your connection and pull down to retry. Credits you already earned still work offline.'
          : 'This build has no rewards server configured.',
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AppColors.mut),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.mut, height: 1.45),
          ),
        ],
      ),
    );
  }
}
