import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'models.dart';

class RewardsPage extends StatefulWidget {
  final WorkStore store;

  const RewardsPage({super.key, required this.store});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  WorkStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    store.addListener(_onChange);
  }

  @override
  void dispose() {
    _tabs.dispose();
    store.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '5');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加奖励'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: '奖励名称', hintText: '例如：喝一杯奶茶'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? '名称不能为空' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                    labelText: '积分价格', hintText: '5的倍数'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return '请输入正整数';
                  if (n % 5 != 0) return '必须是5的倍数';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await store.addReward(
                    nameCtrl.text.trim(), int.parse(priceCtrl.text.trim()));
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  Future<void> _buy(Reward r) async {
    if (store.currentPoints < r.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('积分不足！需要 ${r.price} 分，当前 ${store.currentPoints} 分')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('购买确认'),
        content: Text('花费 ${r.price} 积分购买「${r.name}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (ok == true) {
      final success = await store.buyReward(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success
                  ? '🎉 已购买「${r.name}」！'
                  : '购买失败，请检查积分是否足够')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final available = store.rewards.where((r) => !r.purchased).toList();
    final purchased = store.rewards.where((r) => r.purchased).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('奖励列表 🎁'),
        backgroundColor: colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '可购买（${available.length}）'),
            Tab(text: '已购买（${purchased.length}）'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.star, size: 16, color: Colors.amber),
              label: Text('${store.currentPoints} 分'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增奖励'),
        onPressed: _showAddDialog,
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Available rewards
          available.isEmpty
              ? const Center(child: Text('还没有奖励，快来添加吧！'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: available.length,
                  itemBuilder: (ctx, i) {
                    final r = available[i];
                    final canAfford = store.currentPoints >= r.price;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: canAfford
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          child: Text('${r.price}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: canAfford
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant)),
                        ),
                        title: Text(r.name),
                        subtitle: Text('${r.price} 积分',
                            style: TextStyle(
                                color: canAfford ? Colors.green : Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canAfford)
                              FilledButton(
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12)),
                                onPressed: () => _buy(r),
                                child: const Text('购买'),
                              )
                            else
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12)),
                                onPressed: null,
                                child: const Text('分不够'),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.grey),
                              onPressed: () async {
                                await store.removeReward(r.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // Purchased rewards
          purchased.isEmpty
              ? const Center(child: Text('还没有购买任何奖励'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: purchased.length,
                  itemBuilder: (ctx, i) {
                    final r = purchased[i];
                    final dt = r.purchasedTs != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            r.purchasedTs! * 1000)
                        : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.check,
                              color: Colors.green, size: 20),
                        ),
                        title: Text(r.name,
                            style: const TextStyle(
                                decoration: TextDecoration.none)),
                        subtitle: dt != null
                            ? Text(
                                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 购买',
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Text('${r.price} 积分',
                            style: const TextStyle(color: Colors.grey)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
