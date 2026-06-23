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

  /// Tickets earned based on configurable seconds-per-ticket threshold
  int earnedTickets({int secondsPerTicket = 1800}) =>
      duration.inSeconds ~/ secondsPerTicket;

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
  int price;
  bool canWinFromLottery;

  /// Max total obtainable (null = unlimited)
  int? quantity;

  /// Times obtained (bought + won via lottery)
  int obtainedCount;

  /// Times redeemed/used
  int redeemedCount;

  /// Timestamp when first obtained
  int? firstObtainedTs;

  Reward({
    required this.id,
    required this.name,
    required this.price,
    this.canWinFromLottery = false,
    this.quantity,
    this.obtainedCount = 0,
    this.redeemedCount = 0,
    this.firstObtainedTs,
  });

  /// Units ready to use
  int get availableToUse => obtainedCount - redeemedCount;

  /// Whether more can still be obtained
  bool get isAvailableToBuy => quantity == null || obtainedCount < quantity!;

  String get quantityLabel =>
      quantity == null ? '不限量' : '已获得 $obtainedCount/$quantity';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'canWinFromLottery': canWinFromLottery,
        'quantity': quantity,
        'obtainedCount': obtainedCount,
        'redeemedCount': redeemedCount,
        'firstObtainedTs': firstObtainedTs,
      };

  factory Reward.fromJson(Map<String, dynamic> j) {
    // Migrate legacy fields
    int obtained = j['obtainedCount'] as int? ?? 0;
    int redeemed = j['redeemedCount'] as int? ?? 0;
    if (obtained == 0 && (j['purchased'] as bool? ?? false)) {
      obtained = j['usedCount'] as int? ?? 1;
    }
    if (redeemed == 0 && j['usedAt'] != null) redeemed = 1;
    return Reward(
      id: j['id'] as String,
      name: j['name'] as String,
      price: j['price'] as int,
      canWinFromLottery: j['canWinFromLottery'] as bool? ?? false,
      quantity: j['quantity'] as int?,
      obtainedCount: obtained,
      redeemedCount: redeemed,
      firstObtainedTs: j['firstObtainedTs'] as int? ?? j['purchasedTs'] as int?,
    );
  }
}

// ── Check-in ──────────────────────────────────────────────────────────────

enum CheckInPeriodType { days, weeks }

class CheckInTask {
  final String id;
  String name;
  CheckInPeriodType periodType;
  int periodN;
  int ticketsPerCheckIn;
  bool active;
  bool starred;
  final int createdTs;

  CheckInTask({
    required this.id,
    required this.name,
    required this.periodType,
    required this.periodN,
    required this.ticketsPerCheckIn,
    this.active = true,
    this.starred = false,
    required this.createdTs,
  });

  String get periodLabel {
    if (periodType == CheckInPeriodType.days) {
      return periodN == 1 ? '每日' : '每 $periodN 日';
    }
    return periodN == 1 ? '每周' : '每 $periodN 周';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'periodType': periodType.name,
        'periodN': periodN,
        'ticketsPerCheckIn': ticketsPerCheckIn,
        'active': active,
        'starred': starred,
        'createdTs': createdTs,
      };

  factory CheckInTask.fromJson(Map<String, dynamic> j) => CheckInTask(
        id: j['id'] as String,
        name: j['name'] as String,
        periodType:
            CheckInPeriodType.values.byName(j['periodType'] as String),
        periodN: j['periodN'] as int,
        ticketsPerCheckIn: j['ticketsPerCheckIn'] as int,
        active: j['active'] as bool? ?? true,
        starred: j['starred'] as bool? ?? false,
        createdTs: j['createdTs'] as int,
      );
}

class CheckInRecord {
  final String taskId;
  final String periodKey;
  final int ts;
  final int ticketsEarned;

  CheckInRecord({
    required this.taskId,
    required this.periodKey,
    required this.ts,
    required this.ticketsEarned,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'periodKey': periodKey,
        'ts': ts,
        'ticketsEarned': ticketsEarned,
      };

  factory CheckInRecord.fromJson(Map<String, dynamic> j) => CheckInRecord(
        taskId: j['taskId'] as String,
        periodKey: j['periodKey'] as String,
        ts: j['ts'] as int,
        ticketsEarned: j['ticketsEarned'] as int,
      );
}

/// Period boundaries: daily refresh at 00:00, weekly at Monday 00:00.
class CheckInPeriod {
  static DateTime _midnight(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  static final _epoch = DateTime(1970, 1, 1);
  static final _epochMonday = DateTime(1970, 1, 5);

  static int _daysSinceEpoch(DateTime midnight) =>
      midnight.difference(_epoch).inDays;

  static DateTime _mondayOfWeek(DateTime dt) {
    final local = _midnight(dt);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  static int _weeksSinceEpochMonday(DateTime monday) =>
      monday.difference(_epochMonday).inDays ~/ 7;

  static String periodKey(CheckInPeriodType type, int n, [DateTime? now]) {
    now ??= DateTime.now();
    if (type == CheckInPeriodType.days) {
      final idx = _daysSinceEpoch(_midnight(now)) ~/ n;
      return 'd_${n}_$idx';
    }
    final idx = _weeksSinceEpochMonday(_mondayOfWeek(now)) ~/ n;
    return 'w_${n}_$idx';
  }

  static DateTime nextRefreshAt(CheckInPeriodType type, int n,
      [DateTime? now]) {
    now ??= DateTime.now();
    if (type == CheckInPeriodType.days) {
      final days = _daysSinceEpoch(_midnight(now));
      final nextDay = ((days ~/ n) + 1) * n;
      return _epoch.add(Duration(days: nextDay));
    }
    final weeks = _weeksSinceEpochMonday(_mondayOfWeek(now));
    final nextWeek = ((weeks ~/ n) + 1) * n;
    return _epochMonday.add(Duration(days: nextWeek * 7));
  }

  static String nextRefreshLabel(CheckInPeriodType type, int n,
      [DateTime? now]) {
    final next = nextRefreshAt(type, n, now);
    if (type == CheckInPeriodType.days) {
      return '${next.month}月${next.day}日 0:00 刷新';
    }
    return '${next.month}月${next.day}日（周一）0:00 刷新';
  }
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
        final available = rewards
            .where((r) => r.canWinFromLottery && r.isAvailableToBuy)
            .toList();
        if (available.isEmpty) {
          return ChestEvent(type: ChestEventType.wishBonus,
              extraText: '没有可抽奖的奖励，随心所欲！');
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
