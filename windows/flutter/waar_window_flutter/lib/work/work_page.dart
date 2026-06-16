import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../app_theme.dart';
import '../main.dart' show HomePage;
import 'store.dart';
import 'models.dart';
import 'board_game.dart';
import 'rewards_page.dart';
import 'work_settings_page.dart';
import 'achievements_page.dart';
import 'checkin_page.dart';
import 'point_history_page.dart';

class WorkPage extends StatefulWidget {
  final String projectRoot;
  final ValueChanged<String>? onProjectRootChanged;
  final AppThemeTone themeTone;
  final ValueChanged<AppThemeTone>? onThemeChanged;

  const WorkPage({
    super.key,
    required this.projectRoot,
    this.onProjectRootChanged,
    required this.themeTone,
    this.onThemeChanged,
  });

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  WorkStore? _store;
  Timer? _ticker;
  bool _storeLoading = true;

  @override
  void initState() {
    super.initState();
    _initStore();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_store?.activeSession != null) {
        _store!.checkWorkTicketNotification();
        setState(() {});
      }
    });
  }

  Future<void> _initStore() async {
    String workDir;
    if (widget.projectRoot.isNotEmpty) {
      workDir = '${widget.projectRoot}/work';
    } else {
      final docs = await getApplicationDocumentsDirectory();
      workDir = '${docs.path}/waar_hook_work';
    }
    final store = WorkStore(workDir);
    store.addListener(_onStoreChange);
    await store.load();
    store.onTicketNotification = () {
      if (!mounted) return;
      showWorkTicketNotification(context, store);
    };
    if (mounted) {
      setState(() {
        _store = store;
        _storeLoading = false;
      });
    }
  }

  @override
  void didUpdateWidget(WorkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectRoot != widget.projectRoot) {
      _store?.removeListener(_onStoreChange);
      _store?.dispose();
      _store = null;
      _storeLoading = true;
      _initStore();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _store?.removeListener(_onStoreChange);
    _store?.dispose();
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
    final store = _store;
    if (store == null) return;
    if (store.activeSession != null) {
      final session = store.activeSession!;
      final tickets = session.earnedTickets(
          secondsPerTicket: store.secondsPerTicket);
      await store.endWork();
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
      await store.startWork();
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
                  await _store!.addMotivation(text, type);
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

  Future<void> _checkInStarred(CheckInTask task) async {
    final store = _store;
    if (store == null) return;
    final result = await store.checkIn(task.id);
    if (!mounted) return;
    if (result > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${task.name}」打卡成功！获得 $result 张抽奖券 🎟️'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else if (result == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本周期已打卡')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = this._store;
    if (_storeLoading || store == null || !store.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    final active = store.activeSession;
    final hasWaar = widget.projectRoot.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('梦想Hook'),
        backgroundColor: colorScheme.inversePrimary,
        automaticallyImplyLeading: hasWaar,
        leading: hasWaar
            ? IconButton(
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.transparent,
                  child: Text('👶', style: TextStyle(fontSize: 22)),
                ),
                tooltip: '娃儿视窗',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(
                      projectRoot: widget.projectRoot,
                      onProjectRootChanged: widget.onProjectRootChanged,
                    ),
                  ),
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.task_alt_outlined),
            tooltip: '打卡系统',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CheckInPage(store: store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: '成就',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AchievementsPage(store: store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: '奖励列表',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RewardsPage(store: store)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '积分记录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PointHistoryPage(store: store),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkSettingsPage(
                  store: store,
                  projectRoot: widget.projectRoot,
                  onProjectRootChanged: widget.onProjectRootChanged,
                  themeTone: widget.themeTone,
                  onThemeChanged: widget.onThemeChanged,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (store.starredCheckInTasks.isNotEmpty) ...[
            _StarredCheckInCard(
              tasks: store.starredCheckInTasks,
              store: store,
              onCheckIn: _checkInStarred,
            ),
            const SizedBox(height: 16),
          ],
          _WorkTimerCard(
            active: active,
            onToggle: _toggleWork,
            fmtDuration: _fmtDuration,
            sessions: store.sessions,
            secondsPerTicket: store.secondsPerTicket,
          ),
          const SizedBox(height: 16),
          _StatsCard(
            tickets: store.lotteryTickets,
            currentPoints: store.currentPoints,
            totalEarned: store.totalEarned,
            totalSpent: store.totalSpent,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              icon: const Icon(Icons.casino_outlined),
              label: Text(store.lotteryTickets > 0
                  ? '开始抽奖（${store.lotteryTickets}张券）'
                  : '暂无抽奖券（工作满${_fmtThreshold(store.secondsPerTicket)}获得）'),
              style: FilledButton.styleFrom(
                backgroundColor: store.lotteryTickets > 0
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                foregroundColor: store.lotteryTickets > 0
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              onPressed: store.lotteryTickets > 0
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => BoardGamePage(store: store)),
                      )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          _MotivationsCard(
            motivations: store.motivations,
            onAdd: _showAddMotivation,
            onDelete: (id) async => await store.removeMotivation(id),
          ),
        ],
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

// ── Starred check-in tasks ────────────────────────────────────────────────

class _StarredCheckInCard extends StatelessWidget {
  final List<CheckInTask> tasks;
  final WorkStore store;
  final Future<void> Function(CheckInTask task) onCheckIn;

  const _StarredCheckInCard({
    required this.tasks,
    required this.store,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Text('星标打卡',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...tasks.map((task) {
              final checked = store.isCheckedInThisPeriod(task);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${task.periodLabel} · +${task.ticketsPerCheckIn} 券',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    if (checked)
                      Chip(
                        label: const Text('已打卡',
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: Colors.green.shade100,
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      FilledButton.tonal(
                        onPressed: () => onCheckIn(task),
                        child: const Text('打卡'),
                      ),
                  ],
                ),
              );
            }),
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
