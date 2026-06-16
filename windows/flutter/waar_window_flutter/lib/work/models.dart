import 'dart:math';

// ── Work session ──────────────────────────────────────────────────────────

class WorkSession {
  final int startTs; // Unix seconds
  int? endTs;

  WorkSession({required this.startTs, this.endTs});

  Duration get duration {
    final end = endTs ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    return Duration(seconds: end - startTs);
  }

  /// 1 ticket per completed 30 minutes
  int get earnedTickets => duration.inMinutes ~/ 30;

  Map<String, dynamic> toJson() => {'startTs': startTs, 'endTs': endTs};
  factory WorkSession.fromJson(Map<String, dynamic> j) =>
      WorkSession(startTs: j['startTs'] as int, endTs: j['endTs'] as int?);
}

// ── Motivation ────────────────────────────────────────────────────────────

enum MotivationType { dream, pressure }

class Motivation {
  final String id;
  String text;
  MotivationType type;

  Motivation({required this.id, required this.text, required this.type});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'type': type.name};
  factory Motivation.fromJson(Map<String, dynamic> j) => Motivation(
        id: j['id'] as String,
        text: j['text'] as String,
        type: MotivationType.values.byName(j['type'] as String),
      );
}

// ── Points ────────────────────────────────────────────────────────────────

enum PointEventType { earned, spent }

class PointEvent {
  final int ts;
  final PointEventType type;
  final int amount;
  final String note;

  PointEvent(
      {required this.ts,
      required this.type,
      required this.amount,
      required this.note});

  Map<String, dynamic> toJson() =>
      {'ts': ts, 'type': type.name, 'amount': amount, 'note': note};
  factory PointEvent.fromJson(Map<String, dynamic> j) => PointEvent(
        ts: j['ts'] as int,
        type: PointEventType.values.byName(j['type'] as String),
        amount: j['amount'] as int,
        note: j['note'] as String,
      );
}

// ── Reward ────────────────────────────────────────────────────────────────

class Reward {
  final String id;
  String name;
  int price; // multiple of 5
  bool purchased;
  int? purchasedTs;

  Reward(
      {required this.id,
      required this.name,
      required this.price,
      this.purchased = false,
      this.purchasedTs});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'purchased': purchased,
        'purchasedTs': purchasedTs,
      };
  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'] as String,
        name: j['name'] as String,
        price: j['price'] as int,
        purchased: j['purchased'] as bool? ?? false,
        purchasedTs: j['purchasedTs'] as int?,
      );
}

// ── Board / Chest ─────────────────────────────────────────────────────────

enum ChestEventType { advance, retreat, reward, exercise, wishBonus, wishPenalty }

class ChestEvent {
  final ChestEventType type;
  final int? steps;
  final String? exerciseName;
  final int? exerciseCount;
  final String? extraText;

  ChestEvent({
    required this.type,
    this.steps,
    this.exerciseName,
    this.exerciseCount,
    this.extraText,
  });

  static final _rng = Random();

  static ChestEvent generate({List<Reward> rewards = const []}) {
    final types = ChestEventType.values;
    final t = types[_rng.nextInt(types.length)];
    switch (t) {
      case ChestEventType.advance:
        return ChestEvent(type: t, steps: 1 + _rng.nextInt(10));
      case ChestEventType.retreat:
        return ChestEvent(type: t, steps: 1 + _rng.nextInt(5));
      case ChestEventType.reward:
        final available = rewards.where((r) => !r.purchased).toList();
        if (available.isEmpty) {
          return ChestEvent(type: ChestEventType.wishBonus,
              extraText: '没有可用奖励，随心所欲！');
        }
        final r = available[_rng.nextInt(available.length)];
        return ChestEvent(type: t, extraText: r.name);
      case ChestEventType.exercise:
        final exercises = ['俯卧撑', '深蹲', '开合跳'];
        final counts = [10, 15, 20];
        final i = _rng.nextInt(exercises.length);
        return ChestEvent(
            type: t,
            exerciseName: exercises[i],
            exerciseCount: counts[_rng.nextInt(counts.length)]);
      case ChestEventType.wishBonus:
        return ChestEvent(type: t, extraText: '奖励：随心所欲！');
      case ChestEventType.wishPenalty:
        return ChestEvent(type: t, extraText: '惩罚：随心所欲！');
    }
  }

  String get title {
    switch (type) {
      case ChestEventType.advance: return '🚀 前进 $steps 格！';
      case ChestEventType.retreat: return '⬇️ 后退 $steps 格';
      case ChestEventType.reward: return '🎁 获得奖励：$extraText';
      case ChestEventType.exercise: return '💪 运动挑战';
      case ChestEventType.wishBonus: return '⭐ 随心所欲（奖励）';
      case ChestEventType.wishPenalty: return '💀 随心所欲（惩罚）';
    }
  }

  String get detail {
    switch (type) {
      case ChestEventType.advance: return '前进 $steps 格，获得 $steps 积分！';
      case ChestEventType.retreat: return '后退 $steps 格，减少 $steps 积分。';
      case ChestEventType.reward: return '直接获得「$extraText」！';
      case ChestEventType.exercise:
        return '完成 $exerciseCount 个$exerciseName！';
      case ChestEventType.wishBonus: return extraText ?? '奖励由你决定！';
      case ChestEventType.wishPenalty: return extraText ?? '惩罚由你决定！';
    }
  }

  /// Points delta from this event
  int get pointsDelta {
    switch (type) {
      case ChestEventType.advance: return steps ?? 0;
      case ChestEventType.retreat: return -(steps ?? 0);
      default: return 0;
    }
  }
}
