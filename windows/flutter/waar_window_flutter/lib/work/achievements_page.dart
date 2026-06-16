import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'store.dart';

class AchievementsPage extends StatelessWidget {
  final WorkStore store;

  const AchievementsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('成就 🏆'),
            backgroundColor: cs.inversePrimary,
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: '分享',
                onPressed: () => _shareSystem(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      Text(
                        '已坚持 ${store.daysUsingApp} 天',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '继续赚奶粉钱，娃儿会骄傲的！',
                        style: TextStyle(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _StatGrid(store: store),
              const SizedBox(height: 24),
              Text('分享到', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ShareButtons(
                onShare: (target) => _shareToTarget(context, target),
              ),
              const SizedBox(height: 8),
              Text(
                'macOS 暂不支持直接分享到社交平台，内容会复制到剪贴板并尝试打开对应 App',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareSystem(BuildContext context) async {
    await Share.share(store.buildAchievementShareText(),
        subject: '娃儿视窗 · 我的成就');
  }

  Future<void> _shareToTarget(BuildContext context, _ShareTarget target) async {
    final text = store.buildAchievementShareText();
    await Clipboard.setData(ClipboardData(text: text));

    if (Platform.isMacOS) {
      await _tryOpenMacApp(target);
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('成就内容已复制，${target.hint}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _tryOpenMacApp(_ShareTarget target) async {
    for (final id in target.macBundleIds) {
      final r = await Process.run('open', ['-b', id]);
      if (r.exitCode == 0) return;
    }
    for (final name in target.macAppNames) {
      final r = await Process.run('open', ['-a', name]);
      if (r.exitCode == 0) return;
    }
  }
}

// ── Stat grid ─────────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  final WorkStore store;
  const _StatGrid({required this.store});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(icon: '📅', label: '使用天数', value: '${store.daysUsingApp} 天'),
      _StatItem(
          icon: '⏱',
          label: '工作总时长',
          value: WorkStore.formatDuration(store.totalWorkSeconds)),
      _StatItem(
          icon: '⭐', label: '赚取积分', value: '${store.totalEarned}'),
      _StatItem(
          icon: '🎁',
          label: '兑换奖励',
          value: '${store.totalRewardsRedeemed} 次'),
      _StatItem(
          icon: '🎲', label: '抽奖次数', value: '${store.totalDrawCount} 次'),
      _StatItem(
          icon: '📦',
          label: '抽中宝箱',
          value: '${store.totalChestCount} 次'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) => stats[i],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ── Share buttons ─────────────────────────────────────────────────────────

enum _ShareTarget {
  wechat('微信', '请在微信中粘贴分享',
      ['com.tencent.xinWeChat'], ['WeChat', '微信']),
  moments('朋友圈', '请在微信朋友圈发布页粘贴分享',
      ['com.tencent.xinWeChat'], ['WeChat', '微信']),
  xiaohongshu('小红书', '请在小红书中粘贴分享',
      ['com.xingin.discover', 'com.xingin.xhs'], ['小红书', 'RED']);

  final String label;
  final String hint;
  final List<String> macBundleIds;
  final List<String> macAppNames;
  const _ShareTarget(this.label, this.hint, this.macBundleIds, this.macAppNames);
}

class _ShareButtons extends StatelessWidget {
  final void Function(_ShareTarget) onShare;
  const _ShareButtons({required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _ShareTarget.values.map((t) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: () => onShare(t),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(t.label, style: const TextStyle(fontSize: 13)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
