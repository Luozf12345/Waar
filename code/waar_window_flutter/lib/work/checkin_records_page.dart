import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'store.dart';
import 'models.dart';

class CheckInRecordsPage extends StatelessWidget {
  final WorkStore store;

  const CheckInRecordsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final groups = _groupByDate(store);
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('打卡记录 📋'),
            backgroundColor: cs.inversePrimary,
          ),
          body: groups.isEmpty
              ? const Center(
                  child: Text('暂无打卡记录',
                      style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: groups.length,
                  itemBuilder: (context, i) {
                    final group = groups[i];
                    return _DaySection(
                      date: group.date,
                      records: group.records,
                    );
                  },
                ),
        );
      },
    );
  }

  List<_DayGroup> _groupByDate(WorkStore store) {
    final taskMap = {for (final t in store.checkInTasks) t.id: t.name};
    final byDay = <DateTime, List<_RecordItem>>{};

    for (final r in store.checkInRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.ts * 1000);
      final day = DateTime(dt.year, dt.month, dt.day);
      byDay.putIfAbsent(day, () => []);
      byDay[day]!.add(_RecordItem(
        record: r,
        taskName: taskMap[r.taskId] ?? '未知任务',
        time: dt,
      ));
    }

    for (final list in byDay.values) {
      list.sort((a, b) => b.time.compareTo(a.time));
    }

    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return days
        .map((d) => _DayGroup(date: d, records: byDay[d]!))
        .toList();
  }
}

class _DayGroup {
  final DateTime date;
  final List<_RecordItem> records;
  const _DayGroup({required this.date, required this.records});
}

class _RecordItem {
  final CheckInRecord record;
  final String taskName;
  final DateTime time;
  const _RecordItem(
      {required this.record, required this.taskName, required this.time});
}

class _DaySection extends StatelessWidget {
  final DateTime date;
  final List<_RecordItem> records;

  const _DaySection({
    required this.date,
    required this.records,
  });

  static final _timeFmt = DateFormat('HH:mm');

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return '今天';
    if (d == yesterday) return '昨天';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final w = weekdays[d.weekday - 1];
    return '${d.year}年${d.month}月${d.day}日 $w';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalTickets =
        records.fold(0, (sum, r) => sum + r.record.ticketsEarned);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _dateLabel(date),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '${records.length} 次 · +$totalTickets 券',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < records.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(Icons.check,
                          size: 18, color: cs.onPrimaryContainer),
                    ),
                    title: Text(records[i].taskName),
                    subtitle: Text(_timeFmt.format(records[i].time)),
                    trailing: Text(
                      '+${records[i].record.ticketsEarned} 券',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
