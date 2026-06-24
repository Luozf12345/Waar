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

  void _showAddDialog() => _showRewardFormDialog();

  void _showEditDialog(Reward reward) => _showRewardFormDialog(reward: reward);

  void _showRewardFormDialog({Reward? reward}) {
    final editing = reward != null;
    final nameCtrl = TextEditingController(text: reward?.name ?? '');
    final priceCtrl = TextEditingController(text: '${reward?.price ?? 5}');
    final quantityCtrl = TextEditingController(
      text: reward?.quantity?.toString() ?? '',
    );
    bool canWin = reward?.canWinFromLottery ?? false;
    bool unlimited = reward?.quantity == null;
    final minQuantity = reward?.obtainedCount ?? 0;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: Text(editing ? '编辑奖励' : '添加奖励'),
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
                      decoration: InputDecoration(
                        labelText: '数量',
                        hintText: minQuantity > 0 ? '至少 $minQuantity' : '例如：3',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (unlimited) return null;
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return '请输入正整数';
                        if (n < minQuantity) {
                          return '不能少于已获得数量（$minQuantity）';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
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
                if (!formKey.currentState!.validate()) return;
                final qty = unlimited
                    ? null
                    : int.tryParse(quantityCtrl.text.trim());
                final name = nameCtrl.text.trim();
                final price = int.parse(priceCtrl.text.trim());
                if (editing) {
                  final existing = reward;
                  if (existing == null) return;
                  final ok = await store.updateReward(
                    id: existing.id,
                    name: name,
                    price: price,
                    canWinFromLottery: canWin,
                    quantity: qty,
                  );
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('保存失败，请检查输入')),
                    );
                    return;
                  }
                } else {
                  await store.addReward(
                    name,
                    price,
                    canWinFromLottery: canWin,
                    quantity: qty,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(editing ? '保存' : '添加'),
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

  Future<void> _confirmDelete(Reward r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除奖励'),
        content: Text('确认删除「${r.name}」？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await store.removeReward(r.id);
  }

  Widget _buildMoreMenu(Reward r) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'edit') _showEditDialog(r);
        if (value == 'delete') _confirmDelete(r);
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined, size: 20),
            title: Text('编辑'),
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, size: 20, color: Colors.grey),
            title: const Text('删除'),
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildRewardHeader({
    required String title,
    List<Widget> tags = const [],
    Widget? subtitle,
    TextStyle? titleStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle ?? Theme.of(context).textTheme.titleMedium),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: tags),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          subtitle,
        ],
      ],
    );
  }

  Widget _buildCard({
    required Widget content,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 8, 12),
        child: trailing == null
            ? content
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
      ),
    );
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
                    return _buildCard(
                      content: _buildRewardHeader(
                        title: r.name,
                        tags: [
                          if (r.canWinFromLottery)
                            _Badge(label: '可抽奖', color: Colors.orange),
                        ],
                        subtitle: Text(
                          '${r.price} 积分 · ${r.quantityLabel}',
                          style: TextStyle(
                            fontSize: 12,
                            color: canAfford ? Colors.green : Colors.grey,
                          ),
                        ),
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
                          _buildMoreMenu(r),
                        ],
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
                    return _buildCard(
                      content: _buildRewardHeader(
                        title: r.name,
                        tags: [
                          _Badge(
                              label: '×${r.availableToUse}',
                              color: Colors.blue),
                          if (r.canWinFromLottery)
                            _Badge(label: '可抽奖', color: Colors.orange),
                        ],
                        subtitle: dt != null
                            ? Text(
                                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} 首次获得',
                                style: const TextStyle(fontSize: 12))
                            : null,
                      ),
                      trailing: FilledButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
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
                              content: Text(
                                  '确认使用「${r.name}」？使用后将移入已使用列表。'),
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
                    return _buildCard(
                      content: _buildRewardHeader(
                        title: r.name,
                        titleStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        subtitle: Text(
                          '已使用 ${r.redeemedCount} 张  ·  共获得 ${r.obtainedCount} 张',
                          style: const TextStyle(fontSize: 12),
                        ),
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
