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
  // 0=可购买, 1=可使用, 2=已使用

  WorkStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
    final quantityCtrl = TextEditingController();
    bool canWin = false;
    bool unlimited = true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: const Text('添加奖励'),
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
                  const SizedBox(height: 12),
                  // ── Quantity ──────────────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('数量：'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('不限量'),
                            selected: unlimited,
                            onSelected: (_) => setSt(() => unlimited = true),
                          ),
                          ChoiceChip(
                            label: const Text('指定数量'),
                            selected: !unlimited,
                            onSelected: (_) => setSt(() => unlimited = false),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!unlimited) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: quantityCtrl,
                      decoration: const InputDecoration(
                          labelText: '数量', hintText: '例如：3'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (unlimited) return null;
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return '请输入正整数';
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  // ── canWinFromLottery ─────────────────────────────────
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('可以抽奖获得'),
                    subtitle: const Text('宝箱事件可能直接给出此奖励',
                        style: TextStyle(fontSize: 12)),
                    value: canWin,
                    onChanged: (v) => setSt(() => canWin = v),
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
                  final qty = unlimited
                      ? null
                      : int.tryParse(quantityCtrl.text.trim());
                  await store.addReward(
                    nameCtrl.text.trim(),
                    int.parse(priceCtrl.text.trim()),
                    canWinFromLottery: canWin,
                    quantity: qty,
                  );
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
    final canBuy = store.rewards.where((r) => r.isAvailableToBuy).toList();
    final canUse = store.rewards.where((r) => r.availableToUse > 0).toList();
    final used = store.rewards.where((r) => r.redeemedCount > 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('奖励列表 🎁'),
        backgroundColor: colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '可购买（${canBuy.length}）'),
            Tab(text: '可使用（${canUse.length}）'),
            Tab(text: '已使用（${used.length}）'),
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
          // ── Tab 0: 可购买 ─────────────────────────────────────────────
          canBuy.isEmpty
              ? const Center(child: Text('还没有可购买的奖励，快来添加吧！'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: canBuy.length,
                  itemBuilder: (ctx, i) {
                    final r = canBuy[i];
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
                                      : colorScheme.onSurface)),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(r.name)),
                            const SizedBox(width: 6),
                            if (r.canWinFromLottery)
                              _Badge(label: '可抽奖', color: Colors.orange),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Text('${r.price} 积分',
                                style: TextStyle(
                                    color: canAfford ? Colors.green : Colors.grey,
                                    fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(r.quantityLabel,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
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

          // ── Tab 1: 可使用 ─────────────────────────────────────────────
          canUse.isEmpty
              ? const Center(child: Text('还没有可使用的奖励'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: canUse.length,
                  itemBuilder: (ctx, i) {
                    final r = canUse[i];
                    final dt = r.firstObtainedTs != null
                        ? DateTime.fromMillisecondsSinceEpoch(
                            r.firstObtainedTs! * 1000)
                        : null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.redeem,
                              color: Colors.blue, size: 20),
                        ),
                        title: Row(children: [
                          Flexible(child: Text(r.name)),
                          const SizedBox(width: 6),
                          _Badge(
                              label: '×${r.availableToUse}',
                              color: Colors.blue),
                          if (r.canWinFromLottery) ...[
                            const SizedBox(width: 4),
                            _Badge(label: '可抽奖', color: Colors.orange),
                          ],
                        ]),
                        subtitle: dt != null
                            ? Text(
                                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 首次获得',
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline,
                              size: 16),
                          label: const Text('使用一张'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('确认使用'),
                                content:
                                    Text('确认使用「${r.name}」？使用后将移入已使用列表。'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('确认')),
                                ],
                              ),
                            );
                            if (ok == true) await store.useReward(r.id);
                          },
                        ),
                      ),
                    );
                  },
                ),

          // ── Tab 2: 已使用 ─────────────────────────────────────────────
          used.isEmpty
              ? const Center(child: Text('还没有使用任何奖励'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: used.length,
                  itemBuilder: (ctx, i) {
                    final r = used[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(Icons.done_all,
                              color: Colors.grey.shade600, size: 20),
                        ),
                        title: Text(r.name,
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                        subtitle: Text(
                          '已使用 ${r.redeemedCount} 张  ·  共获得 ${r.obtainedCount} 张',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text('${r.price} 积分/张',
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12)),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
}
