import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'store.dart';
import 'models.dart';

class BoardGamePage extends StatefulWidget {
  final WorkStore store;

  const BoardGamePage({super.key, required this.store});

  @override
  State<BoardGamePage> createState() => _BoardGamePageState();
}

class _BoardGamePageState extends State<BoardGamePage>
    with SingleTickerProviderStateMixin {
  int _displayDice = 1;
  bool _rolling = false;
  int? _lastResult;
  Timer? _animTimer;
  final _rng = Random();

  final ScrollController _boardScroll = ScrollController();
  static const double _cellW = 64.0;

  WorkStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlayer());
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    _boardScroll.dispose();
    super.dispose();
  }

  void _scrollToPlayer() {
    final target = ((store.boardPosition - 3) * _cellW).clamp(0.0, double.infinity);
    if (_boardScroll.hasClients) {
      _boardScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Dice animation ────────────────────────────────────────────────────

  Future<void> _animateDice(int targetFace) {
    final completer = Completer<void>();
    int frame = 0;
    const totalFrames = 14;
    _animTimer?.cancel();
    _animTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      frame++;
      if (frame >= totalFrames) {
        t.cancel();
        if (mounted) setState(() => _displayDice = targetFace);
        if (!completer.isCompleted) completer.complete();
      } else {
        if (mounted) {
          // Random face, avoid showing target too early
          int face;
          do {
            face = 1 + _rng.nextInt(6);
          } while (face == targetFace && frame < totalFrames - 2);
          setState(() => _displayDice = face);
        }
      }
    });
    return completer.future;
  }

  // ── Step-by-step movement with chest detection ────────────────────────

  /// Move [steps] cells forward one-by-one with animation,
  /// then check for a chest at the landing cell.
  /// If chest is advance/retreat, chain the extra movement.
  Future<void> _moveAndCheck(int steps, {bool forward = true}) async {
    if (steps <= 0) return;

    if (forward) {
      for (int i = 0; i < steps; i++) {
        await Future.delayed(const Duration(milliseconds: 260));
        await store.moveOneStep();
        if (!mounted) return;
        _scrollToPlayer();
        setState(() {});
      }
    } else {
      // Retreat: animate backwards one step at a time
      for (int i = 0; i < steps; i++) {
        await Future.delayed(const Duration(milliseconds: 220));
        await store.moveBackSteps(1);
        if (!mounted) return;
        _scrollToPlayer();
        setState(() {});
      }
    }

    // Check for chest at the landing cell
    final chest = store.checkChestAtCurrentPosition();
    if (chest == null || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    // Show chest dialog (waits for user to tap OK)
    await _showChestDialog(chest);
    if (!mounted) return;

    // Apply points / reward effects
    await store.applyChestEvent(chest);

    // Chain movement for advance / retreat
    if (chest.type == ChestEventType.advance && (chest.steps ?? 0) > 0) {
      await _moveAndCheck(chest.steps!, forward: true);
    } else if (chest.type == ChestEventType.retreat && (chest.steps ?? 0) > 0) {
      await _moveAndCheck(chest.steps!, forward: false);
    }
  }

  // ── Roll ──────────────────────────────────────────────────────────────

  Future<void> _roll() async {
    if (_rolling || store.lotteryTickets <= 0) return;
    setState(() {
      _rolling = true;
      _lastResult = null;
    });

    // 1. Get the dice value from the store (decrements ticket + awards base points)
    final dice = await store.rollDice();

    // 2. Animate dice ending on the correct face
    await _animateDice(dice);
    if (!mounted) return;
    setState(() {
      _displayDice = dice;
      _lastResult = dice;
    });

    // 3. Walk dice steps, then handle chests
    await _moveAndCheck(dice, forward: true);

    if (mounted) setState(() => _rolling = false);
  }

  // ── Chest dialog ──────────────────────────────────────────────────────

  Future<void> _showChestDialog(ChestEvent event) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(event.title, style: const TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_chestIcon(event.type),
                style: const TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            Text(event.detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            if (event.pointsDelta != 0) ...[
              const SizedBox(height: 8),
              Text(
                event.pointsDelta > 0
                    ? '+${event.pointsDelta} 积分'
                    : '${event.pointsDelta} 积分',
                style: TextStyle(
                  color: event.pointsDelta > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的！'),
          ),
        ],
      ),
    );
  }

  String _chestIcon(ChestEventType type) {
    switch (type) {
      case ChestEventType.advance:    return '🚀';
      case ChestEventType.retreat:    return '😅';
      case ChestEventType.reward:     return '🎁';
      case ChestEventType.exercise:   return '💪';
      case ChestEventType.wishBonus:  return '⭐';
      case ChestEventType.wishPenalty: return '👿';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('大富翁抽奖 🎲'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Stats bar
          Container(
            color: colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Chip(icon: '🎟️', label: '${store.lotteryTickets}张'),
                _Chip(icon: '📍', label: '第 ${store.boardPosition} 格'),
                _Chip(icon: '⭐', label: '${store.currentPoints}分'),
              ],
            ),
          ),

          // Board
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('棋盘',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: ListenableBuilder(
              listenable: store,
              builder: (_, __) => ListView.builder(
                controller: _boardScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: store.boardPosition + 25,
                itemBuilder: (ctx, i) => _BoardCell(
                  index: i,
                  isPlayer: i == store.boardPosition,
                  isChest: store.chestCells.contains(i),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 28),

          // Dice
          _DiceWidget(face: _displayDice, rolling: _rolling),

          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _lastResult != null && !_rolling
                ? Text(
                    key: ValueKey(_lastResult),
                    '骰子点数：$_lastResult  前进 $_lastResult 格',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  )
                : const SizedBox(height: 22),
          ),

          const SizedBox(height: 24),

          // Roll button
          SizedBox(
            width: 220,
            height: 52,
            child: FilledButton.icon(
              icon: const Icon(Icons.casino_outlined),
              label: _rolling
                  ? const Text('进行中…')
                  : Text(store.lotteryTickets > 0
                      ? '掷骰子！（${store.lotteryTickets}次）'
                      : '暂无抽奖券'),
              onPressed: (!_rolling && store.lotteryTickets > 0) ? _roll : null,
            ),
          ),

          const SizedBox(height: 20),

          // Legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _Legend(
                    color: Colors.amber.shade200, label: '宝箱格'),
                _Legend(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    label: '当前位置'),
                _Legend(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    label: '普通格'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Board Cell ────────────────────────────────────────────────────────────

class _BoardCell extends StatelessWidget {
  final int index;
  final bool isPlayer;
  final bool isChest;

  static const double _cellW = 64.0;
  static const double _cellH = 64.0;

  const _BoardCell(
      {required this.index, required this.isPlayer, required this.isChest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isPlayer
        ? cs.primaryContainer
        : isChest
            ? Colors.amber.shade200
            : cs.surfaceContainerHighest;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _cellW,
      height: _cellH,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isPlayer
            ? Border.all(color: cs.primary, width: 2)
            : null,
        boxShadow: isPlayer
            ? [
                BoxShadow(
                    color: cs.primary.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1)
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isPlayer)
            const Text('👶', style: TextStyle(fontSize: 24))
          else if (isChest)
            const Text('📦', style: TextStyle(fontSize: 22))
          else
            Text('$index',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

// ── Dice Widget ───────────────────────────────────────────────────────────

class _DiceWidget extends StatelessWidget {
  final int face;
  final bool rolling;

  // (row, col) in 0-4 grid
  static const _dots = {
    1: [(2, 2)],
    2: [(0, 0), (4, 4)],
    3: [(0, 0), (2, 2), (4, 4)],
    4: [(0, 0), (0, 4), (4, 0), (4, 4)],
    5: [(0, 0), (0, 4), (2, 2), (4, 0), (4, 4)],
    6: [(0, 0), (0, 4), (2, 0), (2, 4), (4, 0), (4, 4)],
  };

  const _DiceWidget({required this.face, required this.rolling});

  @override
  Widget build(BuildContext context) {
    final positions = _dots[face.clamp(1, 6)] ?? _dots[1]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: rolling ? Colors.orange.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: rolling ? Colors.orange : Colors.grey.shade400, width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(2, 4))
        ],
      ),
      child: CustomPaint(painter: _DicePainter(positions: positions)),
    );
  }
}

class _DicePainter extends CustomPainter {
  final List<(int, int)> positions;

  _DicePainter({required this.positions});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black87;
    const grid = 5;
    final cellW = size.width / (grid + 1);
    final cellH = size.height / (grid + 1);
    const r = 7.0;
    for (final (row, col) in positions) {
      canvas.drawCircle(
          Offset((col + 1) * cellW, (row + 1) * cellH), r, paint);
    }
  }

  @override
  bool shouldRepaint(_DicePainter old) => old.positions != positions;
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}
