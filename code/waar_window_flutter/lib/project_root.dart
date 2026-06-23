import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kProjectRootPrefKey = 'waar_project_root';

Future<String> detectProjectRoot() async {
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
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
  }
  return (await getApplicationDocumentsDirectory()).path;
}

Future<String> loadProjectRoot() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kProjectRootPrefKey) ?? '';
}

Future<void> saveProjectRoot(String root) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kProjectRootPrefKey, root);
}

Future<bool> isWaarLifeAvailable(String projectRoot) async {
  if (projectRoot.isEmpty) return false;
  return File('$projectRoot/.core/waar.life').exists();
}

Future<String?> pickProjectRootViaFile() async {
  const typeGroup = XTypeGroup(label: 'waar.life', extensions: ['life']);
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return null;
  return File(file.path).parent.parent.path;
}

Future<void> showProjectRootSettings(
  BuildContext context, {
  required String currentRoot,
  required ValueChanged<String> onSaved,
}) async {
  final ctrl = TextEditingController(text: currentRoot);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Waar 路径'),
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
                final root = await pickProjectRootViaFile();
                if (root != null) {
                  await saveProjectRoot(root);
                  onSaved(root);
                }
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
            await saveProjectRoot(root);
            onSaved(root);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}
