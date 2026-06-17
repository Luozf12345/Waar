import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'project_root.dart';
import 'app_theme.dart';
import 'data_storage.dart';
import 'work/work_page.dart';

void main() {
  runApp(const WaarApp());
}

class WaarApp extends StatefulWidget {
  const WaarApp({super.key});

  @override
  State<WaarApp> createState() => _WaarAppState();
}

class _WaarAppState extends State<WaarApp> {
  AppThemeTone _themeTone = AppThemeTone.blue;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final tone = await loadThemeTone();
    if (mounted) {
      setState(() {
        _themeTone = tone;
        _themeLoaded = true;
      });
    }
  }

  void _onThemeChanged(AppThemeTone tone) {
    setState(() => _themeTone = tone);
    saveThemeTone(tone);
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeLoaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: '梦想Hook',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(_themeTone),
      home: AppRoot(
        themeTone: _themeTone,
        onThemeChanged: _onThemeChanged,
      ),
    );
  }
}

// ─────────────────────────── App root ─────────────────────────────────────

class AppRoot extends StatefulWidget {
  final AppThemeTone themeTone;
  final ValueChanged<AppThemeTone> onThemeChanged;

  const AppRoot({
    super.key,
    required this.themeTone,
    required this.onThemeChanged,
  });

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String _projectRoot = '';
  String _dataStorageBasePath = '';
  DataStorageEnv _dataStorageEnv = DataStorageEnv.debug;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final root = await loadProjectRoot();
    final basePath = await loadDataStorageBasePath();
    final env = await loadDataStorageEnv();
    setState(() {
      _projectRoot = root;
      _dataStorageBasePath = basePath;
      _dataStorageEnv = env;
      _loading = false;
    });
  }

  void _onProjectRootChanged(String root) {
    setState(() => _projectRoot = root);
  }

  void _onDataStorageChanged(String basePath, DataStorageEnv env) {
    setState(() {
      _dataStorageBasePath = basePath;
      _dataStorageEnv = env;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WorkPage(
      key: ValueKey('$_projectRoot|$_dataStorageBasePath|${_dataStorageEnv.name}'),
      projectRoot: _projectRoot,
      onProjectRootChanged: _onProjectRootChanged,
      dataStorageBasePath: _dataStorageBasePath,
      dataStorageEnv: _dataStorageEnv,
      onDataStorageChanged: _onDataStorageChanged,
      themeTone: widget.themeTone,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}

// ─────────────────────────── Home page (娃儿视窗) ─────────────────────────

class HomePage extends StatefulWidget {
  final String projectRoot;
  final ValueChanged<String>? onProjectRootChanged;

  const HomePage({
    super.key,
    required this.projectRoot,
    this.onProjectRootChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _birthDisplay;
  String? _lastFeedDisplay;
  String? _elapsedDisplay;
  String? _errorMessage;
  bool _isPermissionError = false;
  late String _projectRoot;
  bool _loading = true;

  static final DateFormat _fmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  String get _waarLifePath => '$_projectRoot/.core/waar.life';
  String get _foodsPath => '$_projectRoot/foods';

  @override
  void initState() {
    super.initState();
    _projectRoot = widget.projectRoot;
    _refresh();
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectRoot != widget.projectRoot) {
      _projectRoot = widget.projectRoot;
      _refresh();
    }
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

  Future<void> _pickFile() async {
    final root = await pickProjectRootViaFile();
    if (root == null) return;
    await saveProjectRoot(root);
    _projectRoot = root;
    widget.onProjectRootChanged?.call(root);
    await _refresh();
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
