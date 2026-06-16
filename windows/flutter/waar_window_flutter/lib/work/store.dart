import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// Central store for the work module. Persisted to {workDir}/ as JSON files.
class WorkStore extends ChangeNotifier {
  final String workDir;

  // ── State ──────────────────────────────────────────────────────────────
  int lotteryTickets = 0;
  int currentPoints = 0;
  int totalEarned = 0;
  int totalSpent = 0;

  int boardPosition = 0;
  List<int> chestCells = [];

  WorkSession? activeSession;

  List<WorkSession> sessions = [];
  List<Motivation> motivations = [];
  List<Reward> rewards = [];
  List<PointEvent> pointEvents = [];

  // ── Settings (persisted) ───────────────────────────────────────────────

  /// How many seconds of work to earn 1 lottery ticket
  int secondsPerTicket = 1800; // default: 30 min

  /// Enable notification when lottery tickets are earned
  bool notifyOnTickets = false;

  /// Notify every N tickets earned (1 = every ticket)
  int notifyEveryNTickets = 1;

  /// false = bell sound, true = macOS system notification
  bool notifyFullscreen = false;

  // ── Achievement stats (persisted) ──────────────────────────────────────

  /// Unix seconds — first time the work module was used
  int? firstUseTs;

  /// Total lottery dice rolls
  int totalDrawCount = 0;

  /// Total chest events triggered
  int totalChestCount = 0;

  // ── Runtime (not persisted) ────────────────────────────────────────────

  /// Tickets already accounted for in current work session
  int _ticketsNotifiedCount = 0;

  /// Tickets accumulated since last notification (for every-N logic)
  int _ticketsAccumSinceNotify = 0;

  /// Called when a ticket notification should be shown (set by WorkPage)
  VoidCallback? onTicketNotification;

  bool _loaded = false;
  bool get loaded => _loaded;

  WorkStore(this.workDir);

  // ── Achievement computed stats ───────────────────────────────────────

  int get daysUsingApp {
    if (firstUseTs == null) return 0;
    final first =
        DateTime.fromMillisecondsSinceEpoch(firstUseTs! * 1000);
    final now = DateTime.now();
    final firstDay = DateTime(first.year, first.month, first.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(firstDay).inDays + 1;
  }

  int get totalWorkSeconds {
    var total = 0;
    for (final s in sessions) {
      total += s.duration.inSeconds;
    }
    if (activeSession != null) {
      total += activeSession!.duration.inSeconds;
    }
    return total;
  }

  int get totalRewardsRedeemed =>
      rewards.fold(0, (sum, r) => sum + r.redeemedCount);

  static String formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '$h 小时 $m 分钟';
    if (m > 0) return '$m 分钟';
    return '$totalSeconds 秒';
  }

  String buildAchievementShareText() {
    return '''【娃儿视窗 · 我的成就】

📅 使用天数：$daysUsingApp 天
⏱ 工作总时长：${formatDuration(totalWorkSeconds)}
⭐ 赚取积分：$totalEarned
🎁 兑换奖励：$totalRewardsRedeemed 次
🎲 抽奖次数：$totalDrawCount 次
📦 抽中宝箱：$totalChestCount 次

#娃儿视窗 #赚奶粉钱''';
  }

  // ── Persistence ────────────────────────────────────────────────────────

  File _f(String name) => File('$workDir/$name');

  Future<void> load() async {
    final dir = Directory(workDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    sessions = await _readList('sessions.json',
        (j) => WorkSession.fromJson(j as Map<String, dynamic>));
    motivations = await _readList('motivations.json',
        (j) => Motivation.fromJson(j as Map<String, dynamic>));
    rewards = await _readList('rewards.json',
        (j) => Reward.fromJson(j as Map<String, dynamic>));
    pointEvents = await _readList('point_events.json',
        (j) => PointEvent.fromJson(j as Map<String, dynamic>));

    final state = await _readMap('state.json');
    lotteryTickets = state['lotteryTickets'] as int? ?? 0;
    currentPoints = state['currentPoints'] as int? ?? 0;
    totalEarned = state['totalEarned'] as int? ?? 0;
    totalSpent = state['totalSpent'] as int? ?? 0;
    boardPosition = state['boardPosition'] as int? ?? 0;
    chestCells = (state['chestCells'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    final activeStart = state['activeSessionStart'] as int?;
    if (activeStart != null) {
      activeSession = WorkSession(startTs: activeStart);
    }

    // Settings
    secondsPerTicket = state['secondsPerTicket'] as int? ?? 1800;
    notifyOnTickets = state['notifyOnTickets'] as bool? ??
        state['notifyOnPoints'] as bool? ??
        false;
    notifyEveryNTickets = state['notifyEveryNTickets'] as int? ??
        state['notifyEveryNPoints'] as int? ??
        1;
    notifyFullscreen = state['notifyFullscreen'] as bool? ?? false;

    firstUseTs = state['firstUseTs'] as int?;
    if (firstUseTs == null) {
      firstUseTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    }
    totalDrawCount = state['totalDrawCount'] as int? ?? 0;
    totalChestCount = state['totalChestCount'] as int? ?? 0;

    _ensureChestsAhead();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await _writeList('sessions.json', sessions.map((s) => s.toJson()).toList());
    await _writeList(
        'motivations.json', motivations.map((m) => m.toJson()).toList());
    await _writeList('rewards.json', rewards.map((r) => r.toJson()).toList());
    await _writeList(
        'point_events.json', pointEvents.map((e) => e.toJson()).toList());
    await _writeMap('state.json', {
      'lotteryTickets': lotteryTickets,
      'currentPoints': currentPoints,
      'totalEarned': totalEarned,
      'totalSpent': totalSpent,
      'boardPosition': boardPosition,
      'chestCells': chestCells,
      'activeSessionStart': activeSession?.startTs,
      'secondsPerTicket': secondsPerTicket,
      'notifyOnTickets': notifyOnTickets,
      'notifyEveryNTickets': notifyEveryNTickets,
      'notifyFullscreen': notifyFullscreen,
      'firstUseTs': firstUseTs,
      'totalDrawCount': totalDrawCount,
      'totalChestCount': totalChestCount,
    });
  }

  Future<List<T>> _readList<T>(
      String name, T Function(dynamic) fromJson) async {
    final f = _f(name);
    if (!await f.exists()) return [];
    try {
      final data = jsonDecode(await f.readAsString()) as List<dynamic>;
      return data.map(fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _readMap(String name) async {
    final f = _f(name);
    if (!await f.exists()) return {};
    try {
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeList(String name, List<dynamic> data) async {
    await _f(name).writeAsString(jsonEncode(data));
  }

  Future<void> _writeMap(String name, Map<String, dynamic> data) async {
    await _f(name).writeAsString(jsonEncode(data));
  }

  // ── Settings ───────────────────────────────────────────────────────────

  Future<void> saveSettings({
    int? secondsPerTicket,
    bool? notifyOnTickets,
    int? notifyEveryNTickets,
    bool? notifyFullscreen,
  }) async {
    if (secondsPerTicket != null) this.secondsPerTicket = secondsPerTicket;
    if (notifyOnTickets != null) this.notifyOnTickets = notifyOnTickets;
    if (notifyEveryNTickets != null) {
      this.notifyEveryNTickets = notifyEveryNTickets;
    }
    if (notifyFullscreen != null) this.notifyFullscreen = notifyFullscreen;
    await _save();
    notifyListeners();
  }

  // ── Work Session ───────────────────────────────────────────────────────

  Future<void> startWork() async {
    if (activeSession != null) return;
    _ticketsNotifiedCount = 0;
    _ticketsAccumSinceNotify = 0;
    activeSession =
        WorkSession(startTs: DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await _save();
    notifyListeners();
  }

  Future<void> endWork() async {
    final session = activeSession;
    if (session == null) return;
    session.endTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tickets = session.earnedTickets(secondsPerTicket: secondsPerTicket);
    sessions.add(session);
    activeSession = null;
    lotteryTickets += tickets;
    await _save();
    notifyListeners();
  }

  /// Check if new lottery tickets were earned during active work and notify.
  void checkWorkTicketNotification() {
    if (!notifyOnTickets || activeSession == null) return;

    final earned = activeSession!
        .earnedTickets(secondsPerTicket: secondsPerTicket);
    if (earned <= _ticketsNotifiedCount) return;

    final delta = earned - _ticketsNotifiedCount;
    _ticketsNotifiedCount = earned;

    _ticketsAccumSinceNotify += delta;
    final threshold = notifyEveryNTickets.clamp(1, 999999);
    while (_ticketsAccumSinceNotify >= threshold) {
      _ticketsAccumSinceNotify -= threshold;
      onTicketNotification?.call();
    }
  }

  // ── Motivations ────────────────────────────────────────────────────────

  Future<void> addMotivation(String text, MotivationType type) async {
    motivations.add(Motivation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        type: type));
    await _save();
    notifyListeners();
  }

  Future<void> removeMotivation(String id) async {
    motivations.removeWhere((m) => m.id == id);
    await _save();
    notifyListeners();
  }

  // ── Board / Lottery ────────────────────────────────────────────────────

  static final _rng = Random();

  void _ensureChestsAhead() {
    int ahead = boardPosition + 80;
    int farthest = chestCells.isEmpty ? -1 : chestCells.reduce(max);
    if (farthest >= ahead) return;

    int start = ((farthest + 1) ~/ 6) * 6;
    while (start <= ahead) {
      final count = 1 + _rng.nextInt(2);
      final positions = <int>{};
      while (positions.length < count) {
        positions.add(start + _rng.nextInt(6));
      }
      chestCells.addAll(positions);
      start += 6;
    }
  }

  Future<int> rollDice() async {
    if (lotteryTickets <= 0) return 0;
    lotteryTickets--;
    totalDrawCount++;
    final dice = 1 + _rng.nextInt(6);
    _addPoints(dice, '骰子 $dice 点');
    await _save();
    notifyListeners();
    return dice;
  }

  Future<void> moveOneStep() async {
    boardPosition++;
    _ensureChestsAhead();
    await _save();
    notifyListeners();
  }

  Future<void> moveForwardSteps(int steps) async {
    boardPosition += steps;
    _ensureChestsAhead();
    await _save();
    notifyListeners();
  }

  Future<void> moveBackSteps(int steps) async {
    boardPosition = max(0, boardPosition - steps);
    _ensureChestsAhead();
    await _save();
    notifyListeners();
  }

  ChestEvent? checkChestAtCurrentPosition() {
    if (chestCells.contains(boardPosition)) {
      return ChestEvent.generate(rewards: rewards);
    }
    return null;
  }

  Future<void> applyChestEvent(ChestEvent event) async {
    totalChestCount++;
    final delta = event.pointsDelta;
    if (delta > 0) {
      _addPoints(delta, '宝箱：${event.title}');
    } else if (delta < 0) {
      _spendPoints(-delta, '宝箱：${event.title}');
    }
    if (event.type == ChestEventType.reward && event.extraText != null) {
      final idx = rewards.indexWhere(
          (r) => r.name == event.extraText && r.canWinFromLottery);
      if (idx != -1) {
        rewards[idx].obtainedCount++;
        rewards[idx].firstObtainedTs ??=
            DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
    }
    await _save();
    notifyListeners();
  }

  void _addPoints(int amount, String note) {
    currentPoints += amount;
    totalEarned += amount;
    pointEvents.add(PointEvent(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: PointEventType.earned,
      amount: amount,
      note: note,
    ));
  }

  void _spendPoints(int amount, String note) {
    currentPoints -= amount;
    if (currentPoints < 0) currentPoints = 0;
    totalSpent += amount;
    pointEvents.add(PointEvent(
      ts: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: PointEventType.spent,
      amount: amount,
      note: note,
    ));
  }

  // ── Rewards ────────────────────────────────────────────────────────────

  Future<void> addReward(String name, int price,
      {bool canWinFromLottery = false, int? quantity}) async {
    rewards.add(Reward(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      price: price,
      canWinFromLottery: canWinFromLottery,
      quantity: quantity,
    ));
    await _save();
    notifyListeners();
  }

  Future<bool> buyReward(String id) async {
    final r = rewards.firstWhere((r) => r.id == id,
        orElse: () => Reward(id: '', name: '', price: 0));
    if (r.id.isEmpty || !r.isAvailableToBuy || currentPoints < r.price) {
      return false;
    }
    r.obtainedCount++;
    r.firstObtainedTs ??= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _spendPoints(r.price, '购买奖励：${r.name}');
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> useReward(String id) async {
    final r = rewards.firstWhere((r) => r.id == id,
        orElse: () => Reward(id: '', name: '', price: 0));
    if (r.id.isEmpty || r.availableToUse <= 0) return;
    r.redeemedCount++;
    await _save();
    notifyListeners();
  }

  Future<void> removeReward(String id) async {
    rewards.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }
}
