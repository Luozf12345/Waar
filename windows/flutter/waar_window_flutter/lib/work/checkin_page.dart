import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'store.dart';
import 'models.dart';
import 'checkin_records_page.dart';

class CheckInPage extends StatefulWidget {
  final WorkStore store;
  const CheckInPage({super.key, required this.store});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  WorkStore get store => widget.store;
  static final _fmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    store.addListener(_onChange);
  }

  @override
  void dispose() {
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final nCtrl = TextEditingController(text: '1');
    final ticketsCtrl = TextEditingController(text: '1');
    CheckInPeriodType periodType = CheckInPeriodType.days;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('创建打卡任务'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '任务名称',
                      hintText: '例如：晨跑、阅读30分钟',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '名称不能为空' : null,
                  ),
                  const SizedBox(height: 12),
                  Text('周期', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<CheckInPeriodType>(
                    segments: const [
                      ButtonSegment(
                        value: CheckInPeriodType.days,
                        label: Text('每 N 日'),
                      ),
                      ButtonSegment(
                        value: CheckInPeriodType.weeks,
                        label: Text('每 N 周'),
                      ),
                    ],
                    selected: {periodType},
                    onSelectionChanged: (s) =>
                        setSt(() => periodType = s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    periodType == CheckInPeriodType.days
                        ? '每日 0:00 刷新周期'
                        : '每周一 0:00 刷新周期',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nCtrl,
                    decoration: InputDecoration(
                      labelText: periodType == CheckInPeriodType.days
                          ? 'N（日）'
                          : 'N（周）',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return '请输入正整数';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: ticketsCtrl,
                    decoration: const InputDecoration(
                      labelText: '每次打卡获得抽奖券',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return '请输入正整数';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '任务创建后不可删除，仅可设为失效',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await store.addCheckInTask(
                    name: nameCtrl.text.trim(),
                    periodType: periodType,
                    periodN: int.parse(nCtrl.text.trim()),
                    ticketsPerCheckIn: int.parse(ticketsCtrl.text.trim()),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _doCheckIn(CheckInTask task) async {
    final result = await store.checkIn(task.id);
    if (!mounted) return;
    if (result > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('打卡成功！获得 $result 张抽奖券 🎟️'),
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
    final cs = Theme.of(context).colorScheme;
    final active = store.checkInTasks.where((t) => t.active).toList();
    final inactive = store.checkInTasks.where((t) => !t.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡系统 ✅'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '打卡记录',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CheckInRecordsPage(store: store)),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建任务'),
        onPressed: _showAddDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          if (active.isEmpty && inactive.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('还没有打卡任务\n点击右下角创建第一个吧',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          if (active.isNotEmpty) ...[
            Text('进行中', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...active.map((t) => _TaskCard(
                  task: t,
                  store: store,
                  fmt: _fmt,
                  onCheckIn: () => _doCheckIn(t),
                  onDeactivate: () => store.setCheckInTaskActive(t.id, false),
                )),
          ],
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('已失效', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...inactive.map((t) => _TaskCard(
                  task: t,
                  store: store,
                  fmt: _fmt,
                  inactive: true,
                  onActivate: () => store.setCheckInTaskActive(t.id, true),
                )),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final CheckInTask task;
  final WorkStore store;
  final DateFormat fmt;
  final bool inactive;
  final VoidCallback? onCheckIn;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;

  const _TaskCard({
    required this.task,
    required this.store,
    required this.fmt,
    this.inactive = false,
    this.onCheckIn,
    this.onDeactivate,
    this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checked = store.isCheckedInThisPeriod(task);
    final last = store.lastCheckInRecord(task.id);
    final total = store.totalCheckInsFor(task.id);
    final refreshLabel =
        CheckInPeriod.nextRefreshLabel(task.periodType, task.periodN);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: inactive ? cs.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: inactive ? Colors.grey : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    task.starred ? Icons.star : Icons.star_border,
                    color: task.starred ? Colors.amber : Colors.grey,
                  ),
                  tooltip: task.starred ? '取消星标' : '标为星标',
                  onPressed: () => store.toggleCheckInTaskStar(task.id),
                ),
                if (inactive)
                  const Chip(
                    label: Text('已失效', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  )
                else if (checked)
                  Chip(
                    label: const Text('本周期已打卡',
                        style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green.shade100,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(icon: Icons.repeat, label: task.periodLabel),
                _InfoChip(
                    icon: Icons.confirmation_number_outlined,
                    label: '+${task.ticketsPerCheckIn} 券/次'),
                _InfoChip(
                    icon: Icons.history, label: '累计 $total 次'),
              ],
            ),
            const SizedBox(height: 6),
            Text(refreshLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            if (last != null)
              Text(
                '上次打卡：${fmt.format(DateTime.fromMillisecondsSinceEpoch(last.ts * 1000))}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!inactive) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('打卡'),
                      onPressed: checked ? null : onCheckIn,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onDeactivate,
                    child: const Text('设为失效'),
                  ),
                ] else
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.replay, size: 18),
                      label: const Text('恢复激活'),
                      onPressed: onActivate,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}
