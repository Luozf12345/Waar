import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'work/work_page.dart';

void main() {
  runApp(const WaarApp());
}

class WaarApp extends StatelessWidget {
  const WaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '娃儿视窗',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────── Home page ────────────────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _birthDisplay;
  String? _lastFeedDisplay;
  String? _elapsedDisplay;
  String? _errorMessage;
  bool _isPermissionError = false;
  String _projectRoot = '';
  bool _loading = true;

  static const String _prefKey = 'waar_project_root';
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  String get _waarLifePath => '$_projectRoot/.core/waar.life';
  String get _foodsPath => '$_projectRoot/foods';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    String? saved = prefs.getString(_prefKey);
    if (saved == null ||
        saved.isEmpty ||
        !await File('$saved/.core/waar.life').exists()) {
      saved = await _detectProjectRoot();
      await prefs.setString(_prefKey, saved);
    }
    _projectRoot = saved;
    await _refresh();
  }

  /// Walk up from cwd (and executable dir) to find the directory containing
  /// `.core/waar.life`.
  Future<String> _detectProjectRoot() async {
    final bases = <String>[
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    ];
    for (final base in bases) {
      Directory dir = Directory(base);
      for (int i = 0; i < 8; i++) {
        if (await File('${dir.path}/.core/waar.life').exists()) {
          return dir.path;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    // Fallback
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _isPermissionError = false;
    });
    try {
      final file = File(_waarLifePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = '找不到文件：$_waarLifePath';
          _birthDisplay = null;
          _lastFeedDisplay = null;
          _elapsedDisplay = null;
          _loading = false;
        });
        return;
      }

      final lines = await file.readAsLines();
      String? birthDisplay;
      String? lastFeedDisplay;
      DateTime? lastFeedTime;

      if (lines.isNotEmpty) {
        final ts = int.tryParse(lines[0].trim());
        if (ts != null) {
          birthDisplay = _fmt.format(
            DateTime.fromMillisecondsSinceEpoch(ts * 1000),
          );
        }
      }

      if (lines.length >= 2) {
        final ts = int.tryParse(lines[1].trim());
        if (ts != null) {
          lastFeedTime = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
          lastFeedDisplay = _fmt.format(lastFeedTime);
        }
      }

      setState(() {
        _birthDisplay = birthDisplay;
        _lastFeedDisplay = lastFeedDisplay;
        _elapsedDisplay = lastFeedTime != null
            ? _formatElapsed(DateTime.now().difference(lastFeedTime))
            : null;
        _errorMessage = null;
        _loading = false;
      });
    } catch (e) {
      final isPermission = e.toString().contains('Operation not permitted') ||
          e.toString().contains('Permission denied') ||
          e.toString().contains('errno = 1');
      setState(() {
        _errorMessage =
            isPermission ? '无权限读取文件，请手动授权选择项目根目录' : '读取失败：$e';
        _isPermissionError = isPermission;
        _loading = false;
      });
    }
  }

  String _formatElapsed(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days天');
    if (hours > 0) buf.write('$hours小时');
    if (minutes > 0) buf.write('$minutes分钟');
    buf.write('$seconds秒');
    return buf.toString();
  }

  /// Let the user pick waar.life directly (grants sandbox access if needed).
  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(label: 'waar.life', extensions: ['life']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    // Derive project root from selected file: .core/waar.life → parent of .core
    final root = File(file.path).parent.parent.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, root);
    _projectRoot = root;
    await _refresh();
  }

  void _openSettings() {
    final ctrl = TextEditingController(text: _projectRoot);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置项目根目录'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('项目根目录路径（到 waar/ 层级）：'),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  hintText: '/path/to/waar',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 4),
              Text(
                '固定拼接：{root}/.core/waar.life',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('选择 waar.life 文件来定位根目录…'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickFile();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final root = ctrl.text.trim();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_prefKey, root);
              _projectRoot = root;
              if (ctx.mounted) Navigator.pop(ctx);
              await _refresh();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: scheme.primaryContainer,
        title: const Text(
          '娃儿视窗',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置项目根目录',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    _ErrorCard(
                      message: _errorMessage!,
                      isPermissionError: _isPermissionError,
                      onRetry: _refresh,
                      onPickFile: _pickFile,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _InfoCard(
                    icon: Icons.cake_outlined,
                    label: '生日',
                    value: _birthDisplay ?? '—',
                    color: scheme.tertiaryContainer,
                    iconColor: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.restaurant_outlined,
                    label: '上次喂食时间',
                    value: _lastFeedDisplay ?? '—',
                    color: scheme.secondaryContainer,
                    iconColor: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(height: 12),
                  _ElapsedCard(
                    elapsed: _elapsedDisplay,
                    onRefresh: _refresh,
                    color: scheme.primaryContainer,
                    iconColor: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.ramen_dining_outlined),
                      label: const Text(
                        '喂食',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _projectRoot.isEmpty
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FeedingPage(
                                    foodsDir: _foodsPath,
                                    recordDir: '$_projectRoot/record',
                                    waarLifePath: _waarLifePath,
                                    onFed: _refresh,
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.attach_money_outlined),
                      label: const Text(
                        '赚奶粉钱',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(
                            color: scheme.primary, width: 1.5),
                      ),
                      onPressed: _projectRoot.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WorkPage(
                                    projectRoot: _projectRoot,
                                  ),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────── Feeding page ─────────────────────────────────

class FeedingPage extends StatefulWidget {
  final String foodsDir;
  final String recordDir;
  final String waarLifePath;
  final VoidCallback onFed;

  const FeedingPage({
    super.key,
    required this.foodsDir,
    required this.recordDir,
    required this.waarLifePath,
    required this.onFed,
  });

  @override
  State<FeedingPage> createState() => _FeedingPageState();
}

class _FeedingPageState extends State<FeedingPage> {
  List<File> _files = [];
  String? _selectedPath;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final dir = Directory(widget.foodsDir);
    if (!await dir.exists()) await dir.create(recursive: true);
    final list = dir
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() => _files = list);
  }

  Future<void> _selectFile(File file) async {
    final content = await file.readAsString();
    final name = file.uri.pathSegments.last;
    setState(() {
      _selectedPath = file.path;
      _titleCtrl.text = name;
      _contentCtrl.text = content;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPath = null;
      _titleCtrl.clear();
      _contentCtrl.clear();
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写标题（作为文件名）')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final nowFmt = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(nowSeconds * 1000));

      // 1. Save food file to foods/
      final foodsDir = Directory(widget.foodsDir);
      if (!await foodsDir.exists()) await foodsDir.create(recursive: true);
      final foodFile = File('${widget.foodsDir}/$title');
      await foodFile.writeAsString(_contentCtrl.text);

      // 2. Update waar.life second line with current timestamp
      final waarFile = File(widget.waarLifePath);
      if (await waarFile.exists()) {
        final lines = await waarFile.readAsLines();
        final firstLine = lines.isNotEmpty ? lines[0] : '';
        await waarFile.writeAsString('$firstLine\n$nowSeconds\n');
      }

      // 3. Write record entry to record/
      final recordDir = Directory(widget.recordDir);
      if (!await recordDir.exists()) await recordDir.create(recursive: true);
      final recordFile = File('${widget.recordDir}/$nowSeconds');
      await recordFile.writeAsString(
        'time: $nowFmt\ntimestamp: $nowSeconds\ntitle: $title\n---\n${_contentCtrl.text}',
      );

      await _loadFiles();
      setState(() {
        _selectedPath = foodFile.path;
        _saving = false;
      });

      widget.onFed(); // refresh home page elapsed time

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('喂食成功！$nowFmt'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: scheme.primaryContainer,
        title: const Text(
          '喂食',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Row(
        children: [
          // ── Left: file list ──────────────────────────────────────────
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text('食谱',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: '刷新',
                        onPressed: _loadFiles,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: '新建',
                        onPressed: _clearSelection,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _files.isEmpty
                      ? Center(
                          child: Text('暂无食谱',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13)),
                        )
                      : ListView.builder(
                          itemCount: _files.length,
                          itemBuilder: (_, i) {
                            final file = _files[i];
                            final name = file.uri.pathSegments.last;
                            final selected = _selectedPath == file.path;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor: scheme.primaryContainer,
                              leading: Icon(
                                Icons.description_outlined,
                                size: 18,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectFile(file),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────
          const VerticalDivider(width: 1),

          // ── Right: editor ────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: '标题（文件名）',
                      border: OutlineInputBorder(),
                      hintText: '输入标题…',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        border: OutlineInputBorder(),
                        hintText: '输入内容…',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('确定喂食',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Shared widgets ───────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color: iconColor.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
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

class _ElapsedCard extends StatelessWidget {
  final String? elapsed;
  final VoidCallback onRefresh;
  final Color color;
  final Color iconColor;

  const _ElapsedCard({
    required this.elapsed,
    required this.onRefresh,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom_outlined, size: 32, color: iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('距上次喂食',
                      style: TextStyle(
                          fontSize: 13,
                          color: iconColor.withValues(alpha: 0.7))),
                  const SizedBox(height: 2),
                  Text(
                    elapsed != null ? '已经 $elapsed 没有喂食了' : '—',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: iconColor),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: iconColor),
              tooltip: '刷新',
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final bool isPermissionError;
  final VoidCallback onRetry;
  final VoidCallback onPickFile;

  const _ErrorCard({
    required this.message,
    required this.isPermissionError,
    required this.onRetry,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(message,
                      style: TextStyle(color: scheme.onErrorContainer)),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: Text('重试',
                      style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ],
            ),
            if (isPermissionError) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('手动授权 — 选择 waar.life 文件'),
                onPressed: onPickFile,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
