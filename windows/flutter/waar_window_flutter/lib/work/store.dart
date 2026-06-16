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

  /// Position on the board (cell index, 0-based)
  int boardPosition = 0;

  /// Global list of chest cell indices that are visible ahead (absolute positions)
  List<int> chestCells = [];

  WorkSession? activeSession;

  List<WorkSession> sessions = [];
  List<Motivation> motivations = [];
  List<Reward> rewards = [];
  List<PointEvent> pointEvents = [];

  bool _loaded = false;
  bool get loaded => _loaded;

  WorkStore(this.workDir);

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

  // ── Work Session ───────────────────────────────────────────────────────

  Future<void> startWork() async {
    if (activeSession != null) return;
    activeSession =
        WorkSession(startTs: DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await _save();
    notifyListeners();
  }

  Future<void> endWork() async {
    final session = activeSession;
    if (session == null) return;
    session.endTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tickets = session.earnedTickets;
    sessions.add(session);
    activeSession = null;
    lotteryTickets += tickets;
    await _save();
    notifyListeners();
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

  /// Ensure there are enough chest cells pre-generated ahead
  void _ensureChestsAhead() {
    int ahead = boardPosition + 80;
    // Find the farthest generated cell
    int farthest = chestCells.isEmpty ? -1 : chestCells.reduce(max);
    if (farthest >= ahead) return;

    // Generate chests for each block of 6 from farthest+1 onward
    int start = ((farthest + 1) ~/ 6) * 6;
    while (start <= ahead) {
      final count = 1 + _rng.nextInt(2); // 1 or 2
      final positions = <int>{};
      while (positions.length < count) {
        positions.add(start + _rng.nextInt(6));
      }
      chestCells.addAll(positions);
      start += 6;
    }
  }

  /// Roll dice (1-6), move character, return (diceValue, chestEvent or null)
  Future<(int dice, ChestEvent? chest)> rollDice() async {
    if (lotteryTickets <= 0) return (0, null);

    final dice = 1 + _rng.nextInt(6);
    lotteryTickets--;

    final newPos = boardPosition + dice;
    boardPosition = newPos;

    _ensureChestsAhead();

    ChestEvent? chestEvent;
    if (chestCells.contains(newPos)) {
      chestEvent = ChestEvent.generate(rewards: rewards);
      final delta = chestEvent.pointsDelta;
      if (delta > 0) {
        _addPoints(delta, '宝箱：${chestEvent.title}');
      } else if (delta < 0) {
        _spendPoints(-delta, '宝箱：${chestEvent.title}');
      }
      // If advance/retreat, apply additional movement
      if (chestEvent.type == ChestEventType.advance) {
        boardPosition += chestEvent.steps ?? 0;
      } else if (chestEvent.type == ChestEventType.retreat) {
        boardPosition = max(0, boardPosition - (chestEvent.steps ?? 0));
      }
    }

    // Base points = dice value
    _addPoints(dice, '骰子 $dice 点');

    _ensureChestsAhead();
    await _save();
    notifyListeners();
    return (dice, chestEvent);
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

  Future<void> addReward(String name, int price) async {
    rewards.add(Reward(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        price: price));
    await _save();
    notifyListeners();
  }

  Future<bool> buyReward(String id) async {
    final r = rewards.firstWhere((r) => r.id == id, orElse: () => Reward(id: '', name: '', price: 0));
    if (r.id.isEmpty || r.purchased || currentPoints < r.price) return false;
    r.purchased = true;
    r.purchasedTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _spendPoints(r.price, '购买奖励：${r.name}');
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> removeReward(String id) async {
    rewards.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }
}
