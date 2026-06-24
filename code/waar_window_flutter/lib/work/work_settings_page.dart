import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../about_page.dart';
import '../app_theme.dart';
import '../data_storage.dart';
import '../project_root.dart';
import 'store.dart';

/// Show notification based on store settings.
/// notifyFullscreen=false → system alert sound
/// notifyFullscreen=true  → macOS system notification via osascript
void showWorkTicketNotification(BuildContext context, WorkStore store) {
  if (store.notifyFullscreen) {
    _sendSystemNotification(
        title: '获得抽奖券啦！🎟️', body: '可以抽奖了，继续加油 💪');
  } else {
    SystemSound.play(SystemSoundType.alert);
  }
}

Future<void> _sendSystemNotification({
  required String title,
  required String body,
  String soundName = 'Glass',
}) async {
  // Escape for AppleScript string literals
  final t = title.replaceAll('"', '\\"');
  final b = body.replaceAll('"', '\\"');
  await Process.run('osascript', [
    '-e',
    'display notification "$b" with title "$t" sound name "$soundName"',
  ]);
}

class WorkSettingsPage extends StatefulWidget {
  final WorkStore store;
  final String projectRoot;
  final ValueChanged<String>? onProjectRootChanged;
  final String dataStorageBasePath;
  final DataStorageEnv dataStorageEnv;
  final void Function(String basePath, DataStorageEnv env)? onDataStorageChanged;
  final AppThemeTone themeTone;
  final ValueChanged<AppThemeTone>? onThemeChanged;

  const WorkSettingsPage({
    super.key,
    required this.store,
    required this.projectRoot,
    this.onProjectRootChanged,
    required this.dataStorageBasePath,
    required this.dataStorageEnv,
    this.onDataStorageChanged,
    required this.themeTone,
    this.onThemeChanged,
  });

  @override
  State<WorkSettingsPage> createState() => _WorkSettingsPageState();
}

class _WorkSettingsPageState extends State<WorkSettingsPage> {
  late int _secondsPerTicket;
  late bool _notifyOnTickets;
  late int _notifyEveryNTickets;
  late bool _notifyFullscreen;
  late final TextEditingController _rootCtrl;
  late final TextEditingController _dataPathCtrl;
  late AppThemeTone _themeTone;

  WorkStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _secondsPerTicket = store.secondsPerTicket;
    _notifyOnTickets = store.notifyOnTickets;
    _notifyEveryNTickets = store.notifyEveryNTickets;
    _notifyFullscreen = store.notifyFullscreen;
    _rootCtrl = TextEditingController(text: widget.projectRoot);
    _dataPathCtrl = TextEditingController(text: widget.dataStorageBasePath);
    _themeTone = widget.themeTone;
  }

  @override
  void dispose() {
    _rootCtrl.dispose();
    _dataPathCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await store.saveSettings(
        secondsPerTicket: _secondsPerTicket,
        notifyOnTickets: _notifyOnTickets,
        notifyEveryNTickets: _notifyEveryNTickets,
        notifyFullscreen: _notifyFullscreen,
      );
      await saveProjectRoot(_rootCtrl.text.trim());
      widget.onProjectRootChanged?.call(_rootCtrl.text.trim());

      if (!isMobileDataStorage) {
        final basePath = _dataPathCtrl.text.trim();
        await saveDataStorageBasePath(basePath);
        final env = buildDataStorageEnv;
        await saveDataStorageEnv(env);
        widget.onDataStorageChanged?.call(basePath, env);
      }

      if (_themeTone != widget.themeTone) {
        widget.onThemeChanged?.call(_themeTone);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _pickDataStorageDir() async {
    final dir = await pickDataStorageDirectory();
    if (dir == null) return;
    _dataPathCtrl.text = dir;
    setState(() {});
  }

  Future<void> _pickProjectRoot() async {
    final root = await pickProjectRootViaFile();
    if (root == null) return;
    _rootCtrl.text = root;
    setState(() {});
  }

  String _dataDirHint() {
    if (isMobileDataStorage) {
      return '{应用私有目录}/waar_hook_data/${buildDataStorageEnv.dirName}/work/';
    }
    final base = _dataPathCtrl.text.trim();
    final root = base.isEmpty ? '{未设置，使用应用目录}/waar_hook_data' : base;
    return '$root/${buildDataStorageEnv.dirName}/work/';
  }

  String _fmtSeconds(int s) {
    if (s < 60) return '$s 秒';
    if (s < 3600) return '${s ~/ 60} 分钟';
    return '${s ~/ 3600} 小时 ${(s % 3600) ~/ 60} 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: cs.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme ─────────────────────────────────────────────────────
          _SectionHeader(title: '主题色调', icon: Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppThemeTone.values.map((tone) {
                  final selected = _themeTone == tone;
                  return InkWell(
                    onTap: () {
                      setState(() => _themeTone = tone);
                      widget.onThemeChanged?.call(tone);
                      saveThemeTone(tone);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? tone.seedColor
                              : Colors.grey.shade300,
                          width: selected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: tone.seedColor.withValues(alpha: 0.12),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: tone.seedColor,
                          ),
                          const SizedBox(height: 6),
                          Text(tone.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Data storage ────────────────────────────────────────────
          _SectionHeader(title: '数据存储', icon: Icons.storage_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobileDataStorage) ...[
                    const Text('Android / iOS 使用应用私有目录存储数据'),
                    const SizedBox(height: 8),
                    Text(
                      '实际路径：${_dataDirHint()}',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '移动端无法写入通过文件选择器挑选的外部目录，请勿在桌面端配置的路径同步到手机。',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  ] else ...[
                    const Text('数据根目录（不放在项目仓库内）'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dataPathCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: '例如 /Users/你/data/waar_hook',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '实际路径：${_dataDirHint()}',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: const Text('选择数据目录…'),
                      onPressed: _pickDataStorageDir,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('运行环境'),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Text(buildDataStorageEnv.label),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kReleaseMode
                        ? 'Release 包固定使用正式环境数据。'
                        : 'Debug 包固定使用测试环境数据。',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Waar path ───────────────────────────────────────────────
          _SectionHeader(title: 'Waar路径', icon: Icons.folder_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('项目根目录（到 waar/ 层级）'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rootCtrl,
                    decoration: const InputDecoration(
                      hintText: '留空则不启用娃儿视窗',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '固定拼接：{root}/.core/waar.life',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('选择 waar.life 文件来定位根目录…'),
                    onPressed: _pickProjectRoot,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Work duration section ─────────────────────────────────────
          _SectionHeader(title: '工作计时', icon: Icons.timer_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('每张抽奖券所需工作时长',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    '当前：${_fmtSeconds(_secondsPerTicket)}',
                    style:
                        TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!kReleaseMode)
                        _PresetChip(
                            label: '10秒（测试）',
                            value: 10,
                            current: _secondsPerTicket,
                            onTap: (v) =>
                                setState(() => _secondsPerTicket = v)),
                      _PresetChip(
                          label: '15分钟',
                          value: 900,
                          current: _secondsPerTicket,
                          onTap: (v) => setState(() => _secondsPerTicket = v)),
                      _PresetChip(
                          label: '30分钟',
                          value: 1800,
                          current: _secondsPerTicket,
                          onTap: (v) => setState(() => _secondsPerTicket = v)),
                      _PresetChip(
                          label: '45分钟',
                          value: 2700,
                          current: _secondsPerTicket,
                          onTap: (v) => setState(() => _secondsPerTicket = v)),
                      _PresetChip(
                          label: '60分钟',
                          value: 3600,
                          current: _secondsPerTicket,
                          onTap: (v) => setState(() => _secondsPerTicket = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _CustomSecondsInput(
                    initialValue: _secondsPerTicket,
                    onChanged: (v) => setState(() => _secondsPerTicket = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Notification section ──────────────────────────────────────
          _SectionHeader(title: '抽奖券提醒', icon: Icons.notifications_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开启抽奖券提醒'),
                    subtitle: const Text('工作时获得抽奖券时发出提醒，避免频繁看计时器',
                        style: TextStyle(fontSize: 12)),
                    value: _notifyOnTickets,
                    onChanged: (v) => setState(() => _notifyOnTickets = v),
                  ),
                  if (_notifyOnTickets) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('提醒时机', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetChip(
                            label: '每张券',
                            value: 1,
                            current: _notifyEveryNTickets,
                            onTap: (v) =>
                                setState(() => _notifyEveryNTickets = v)),
                        _PresetChip(
                            label: '每 2 张',
                            value: 2,
                            current: _notifyEveryNTickets,
                            onTap: (v) =>
                                setState(() => _notifyEveryNTickets = v)),
                        _PresetChip(
                            label: '每 5 张',
                            value: 5,
                            current: _notifyEveryNTickets,
                            onTap: (v) =>
                                setState(() => _notifyEveryNTickets = v)),
                        _PresetChip(
                            label: '每 10 张',
                            value: 10,
                            current: _notifyEveryNTickets,
                            onTap: (v) =>
                                setState(() => _notifyEveryNTickets = v)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('自定义每 '),
                        SizedBox(
                          width: 64,
                          child: TextFormField(
                            initialValue: '$_notifyEveryNTickets',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder()),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n > 0) {
                                setState(() => _notifyEveryNTickets = n);
                              }
                            },
                          ),
                        ),
                        const Text(' 张抽奖券提醒一次'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('提醒方式', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('🔔 响铃'),
                          icon: Icon(Icons.volume_up_outlined),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('🖥 系统通知'),
                          icon: Icon(Icons.notifications_active_outlined),
                        ),
                      ],
                      selected: {_notifyFullscreen},
                      onSelectionChanged: (s) =>
                          setState(() => _notifyFullscreen = s.first),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow_outlined, size: 18),
                      label: const Text('测试提醒效果'),
                      onPressed: () => _testNotify(context),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── About ───────────────────────────────────────────────────
          _SectionHeader(title: '关于', icon: Icons.info_outline),
          Card(
            child: ListTile(
              leading: Icon(Icons.article_outlined, color: cs.primary),
              title: const Text('关于我们'),
              subtitle: Text('版本 v$kAppVersion'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                );
              },
            ),
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _save,
              child: const Text('保存设置'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _testNotify(BuildContext context) {
    if (_notifyFullscreen) {
      _sendSystemNotification(
          title: '测试通知 🎟️', body: '获得抽奖券时会这样提醒你');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('已发送系统通知，请查看屏幕右上角'),
            duration: Duration(seconds: 2)),
      );
    } else {
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 响铃提醒！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary)),
        ]),
      );
}

class _PresetChip extends StatelessWidget {
  final String label;
  final int value;
  final int current;
  final void Function(int) onTap;

  const _PresetChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
    );
  }
}

class _CustomSecondsInput extends StatefulWidget {
  final int initialValue;
  final void Function(int) onChanged;
  const _CustomSecondsInput(
      {required this.initialValue, required this.onChanged});

  @override
  State<_CustomSecondsInput> createState() => _CustomSecondsInputState();
}

class _CustomSecondsInputState extends State<_CustomSecondsInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.initialValue}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('自定义秒数：'),
        SizedBox(
          width: 100,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
                suffixText: '秒'),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) widget.onChanged(n);
            },
          ),
        ),
      ],
    );
  }
}
