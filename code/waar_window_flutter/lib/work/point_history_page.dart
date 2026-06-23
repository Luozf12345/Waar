import 'package:flutter/material.dart';
import 'models.dart';
import 'store.dart';

class PointHistoryPage extends StatelessWidget {
  final WorkStore store;

  const PointHistoryPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final events = store.pointEvents.reversed.toList();
        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('积分记录'),
            backgroundColor: cs.inversePrimary,
          ),
          body: events.isEmpty
              ? const Center(
                  child: Text('暂无记录', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final e = events[i];
                    final dt =
                        DateTime.fromMillisecondsSinceEpoch(e.ts * 1000);
                    final earned = e.type == PointEventType.earned;
                    final sign = earned ? '+' : '-';
                    final color = earned ? Colors.green : Colors.red;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        earned ? Icons.trending_up : Icons.trending_down,
                        color: color,
                      ),
                      title: Text(e.note),
                      subtitle: Text(
                        '${dt.month}月${dt.day}日 '
                        '${dt.hour.toString().padLeft(2, '0')}:'
                        '${dt.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: Text(
                        '$sign${e.amount}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
