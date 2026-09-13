/// A reward task defined in the admin panel and shown in the app.
class RewardTask {
  final int id;
  final String title;
  final String subtitle;

  /// Logical icon name from the panel: instagram | whatsapp | youtube |
  /// facebook | tiktok | telegram | web | star
  final String icon;

  final String actionUrl;
  final int rewardCredits;

  /// Seconds the user must be away before a claim is accepted. The server
  /// enforces this too; the app only uses it to keep the button honest.
  final int minDwellSeconds;

  final bool claimed;

  const RewardTask({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.icon = 'web',
    required this.actionUrl,
    this.rewardCredits = 1,
    this.minDwellSeconds = 5,
    this.claimed = false,
  });

  factory RewardTask.fromMap(Map<String, dynamic> map) {
    return RewardTask(
      id: (map['id'] as num).toInt(),
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      icon: map['icon'] as String? ?? 'web',
      actionUrl: map['action_url'] as String? ?? '',
      rewardCredits: (map['reward_credits'] as num?)?.toInt() ?? 1,
      minDwellSeconds: (map['min_dwell_secs'] as num?)?.toInt() ?? 5,
      claimed: map['claimed'] == true,
    );
  }

  RewardTask copyWith({bool? claimed}) => RewardTask(
        id: id,
        title: title,
        subtitle: subtitle,
        icon: icon,
        actionUrl: actionUrl,
        rewardCredits: rewardCredits,
        minDwellSeconds: minDwellSeconds,
        claimed: claimed ?? this.claimed,
      );
}

/// Credit balance as reported by the server, which is the authority.
class CreditBalance {
  final int earned;
  final int used;
  final int maxCredits;
  final bool tasksEnabled;

  const CreditBalance({
    this.earned = 0,
    this.used = 0,
    this.maxCredits = 5,
    this.tasksEnabled = true,
  });

  int get available => (earned - used).clamp(0, 1 << 30);

  factory CreditBalance.fromMap(Map<String, dynamic> map) {
    return CreditBalance(
      earned: (map['credits_earned'] as num?)?.toInt() ?? 0,
      used: (map['credits_used'] as num?)?.toInt() ?? 0,
      maxCredits: (map['max_credits'] as num?)?.toInt() ?? 5,
      tasksEnabled: map['tasks_enabled'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'credits_earned': earned,
        'credits_used': used,
        'max_credits': maxCredits,
        'tasks_enabled': tasksEnabled,
      };
}

/// Outcome of a claim attempt, so the UI can explain a refusal precisely.
class ClaimResult {
  final bool ok;
  final int awarded;
  final String error;
  final CreditBalance? balance;

  const ClaimResult({
    required this.ok,
    this.awarded = 0,
    this.error = '',
    this.balance,
  });

  /// Maps the server's error codes to something worth showing a user.
  String get message {
    switch (error) {
      case '':
        return 'Credit added';
      case 'already_claimed':
        return 'You have already completed this task';
      case 'too_fast':
        return 'Spend a few seconds on the page before claiming';
      case 'credit_cap_reached':
        return 'You have earned all available task credits';
      case 'ip_rate_limited':
        return 'Too many claims from this network today';
      case 'device_banned':
        return 'This device is not eligible for rewards';
      case 'tasks_disabled':
        return 'Rewards are temporarily unavailable';
      case 'network':
        return 'No connection. Try again when you are online';
      default:
        return 'Could not complete the task right now';
    }
  }
}
