import 'dart:async';
import 'package:flutter/material.dart';
import 'store.dart';
import 'models.dart';
import 'board_game.dart';
import 'rewards_page.dart';
import 'work_settings_page.dart';
import 'achievements_page.dart';

class WorkPage extends StatefulWidget {
  final String projectRoot;

  const WorkPage({super.key, required this.projectRoot});

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  late final WorkStore _store;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _store = WorkStore('${widget.projectRoot}/work');
    _store.addListener(_onStoreChange);
    _store.load().then((_) => _registerNotification());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_store.activeSession != null) {
        _store.checkWorkTicketNotification();
        setState(() {});
      }
    });
  }

  void _registerNotification() {
    _store.onTicketNotification = () {
      if (!mounted) return;
      showWorkTicketNotification(context, _store);
    };
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _store.removeListener(_onStoreChange);
    _store.dispose();
    super.dispose();
  }

  void _onStoreChange() => setState(() {});

  String _fmtThreshold(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    return '${seconds ~/ 3600}小时';
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '$h时$m分$s秒';
    if (m > 0) return '$m分$s秒';
    return '$s秒';
  }

  Future<void> _toggleWork() async {
    if (_store.activeSession != null) {
      final session = _store.activeSession!;
      final tickets = session.earnedTickets(
          secondsPerTicket: _store.secondsPerTicket);
      await _store.endWork();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tickets > 0
                ? '工作结束！获得 $tickets 张抽奖券 🎟️'
                : '工作结束！（不足30分钟，暂未获得抽奖券）'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      await _store.startWork();
    }
  }

  void _showAddMotivation() {
    final ctrl = TextEditingController();
    MotivationType type = MotivationType.dream;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('添加动机'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: '写下你的梦想或现实压力…'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<MotivationType>(
                segments: const [
                  ButtonSegment(
                      value: MotivationType.dream,
                      label: Text('🌟 梦想'),
                      icon: Icon(Icons.star_outline)),
                  ButtonSegment(
                      value: MotivationType.pressure,
                      label: Text('⚡ 压力'),
                      icon: Icon(Icons.bolt_outlined)),
                ],
                selected: {type},
                onSelectionChanged: (s) => setSt(() => type = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  await _store.addMotivation(text, type);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('添加'),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    final active = _store.activeSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('赚奶粉钱 💰'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: '成就',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AchievementsPage(store: _store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: '奖励列表',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RewardsPage(store: _store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '积分记录',
            onPressed: _showPointHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WorkSettingsPage(store: _store)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MotivationsCard(
            motivations: _store.motivations,
            onAdd: _showAddMotivation,
            onDelete: (id) async => await _store.removeMotivation(id),
          ),
          const SizedBox(height: 16),
          _WorkTimerCard(
            active: active,
            onToggle: _toggleWork,
            fmtDuration: _fmtDuration,
            sessions: _store.sessions,
            secondsPerTicket: _store.secondsPerTicket,
          ),
          const SizedBox(height: 16),
          _StatsCard(
            tickets: _store.lotteryTickets,
            currentPoints: _store.currentPoints,
            totalEarned: _store.totalEarned,
            totalSpent: _store.totalSpent,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(Icons.casino_outlined),
              label: Text(_store.lotteryTickets > 0
                  ? '开始抽奖（${_store.lotteryTickets}张券）'
                  : '暂无抽奖券（工作满${_fmtThreshold(_store.secondsPerTicket)}获得）'),
              style: FilledButton.styleFrom(
                backgroundColor: _store.lotteryTickets > 0
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: _store.lotteryTickets > 0
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              onPressed: _store.lotteryTickets > 0
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BoardGamePage(store: _store)),
                      )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showPointHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scroll) {
          final events = _store.pointEvents.reversed.toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('积分记录',
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              Expanded(
                child: events.isEmpty
                    ? const Center(child: Text('暂无记录'))
                    : ListView.builder(
                        controller: scroll,
                        itemCount: events.length,
                        itemBuilder: (ctx, i) {
                          final e = events[i];
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                              e.ts * 1000);
                          final sign =
                              e.type == PointEventType.earned ? '+' : '-';
                          final color = e.type == PointEventType.earned
                              ? Colors.green
                              : Colors.red;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              e.type == PointEventType.earned
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: color,
                            ),
                            title: Text(e.note),
                            subtitle: Text(
                                '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'),
                            trailing: Text('$sign${e.amount}',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Motivations Card ──────────────────────────────────────────────────────

class _MotivationsCard extends StatelessWidget {
  final List<Motivation> motivations;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;

  const _MotivationsCard(
      {required this.motivations,
      required this.onAdd,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_outlined),
                const SizedBox(width: 8),
                Text('工作动机',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (motivations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('还没有动机，加一个吧 ✨',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...motivations.map((m) => Dismissible(
                    key: Key(m.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: Colors.red,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => onDelete(m.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            m.type == MotivationType.dream ? '🌟' : '⚡',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m.text)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ── Work Timer Card ───────────────────────────────────────────────────────

class _WorkTimerCard extends StatelessWidget {
  final WorkSession? active;
  final VoidCallback onToggle;
  final String Function(Duration) fmtDuration;
  final List<WorkSession> sessions;
  final int secondsPerTicket;

  const _WorkTimerCard({
    required this.active,
    required this.onToggle,
    required this.fmtDuration,
    required this.sessions,
    required this.secondsPerTicket,
  });

  @override
  Widget build(BuildContext context) {
    final isWorking = active != null;
    final elapsed = isWorking ? active!.duration : Duration.zero;
    final ticketsPreview = isWorking
        ? active!.earnedTickets(secondsPerTicket: secondsPerTicket)
        : 0;

    // Stats from completed sessions
    final todaySessions = sessions.where((s) {
      if (s.endTs == null) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(s.startTs * 1000);
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    final todayMinutes = todaySessions.fold(0,
        (sum, s) => sum + (s.endTs! - s.startTs) ~/ 60);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text('工作记录',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('今日已工作 $todayMinutes 分钟',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Text(
                    isWorking ? fmtDuration(elapsed) : '00:00',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isWorking ? Colors.green : Colors.grey,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                  if (isWorking)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          ticketsPreview > 0
                              ? '已可获得 $ticketsPreview 张抽奖券'
                              : '再坚持 ${secondsPerTicket - elapsed.inSeconds % secondsPerTicket} 秒获得抽奖券',
                          style: const TextStyle(color: Colors.orange)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: isWorking
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('下班了'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      onPressed: onToggle,
                    )
                  : FilledButton.icon(
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('开始工作'),
                      onPressed: onToggle,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Card ────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final int tickets;
  final int currentPoints;
  final int totalEarned;
  final int totalSpent;

  const _StatsCard({
    required this.tickets,
    required this.currentPoints,
    required this.totalEarned,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars_outlined),
                const SizedBox(width: 8),
                Text('积分 & 抽奖券',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatItem(label: '抽奖券', value: '$tickets 张', icon: '🎟️'),
                const SizedBox(width: 16),
                _StatItem(
                    label: '当前积分',
                    value: '$currentPoints',
                    icon: '⭐',
                    highlight: true),
                const SizedBox(width: 16),
                _StatItem(
                    label: '累计获得', value: '$totalEarned', icon: '📈'),
                const SizedBox(width: 16),
                _StatItem(
                    label: '已花费', value: '$totalSpent', icon: '💸'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final bool highlight;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : null)),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
