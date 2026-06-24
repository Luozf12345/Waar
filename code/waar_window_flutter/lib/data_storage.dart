import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mobile platforms cannot write arbitrary filesystem paths picked via SAF.
bool get isMobileDataStorage => Platform.isAndroid || Platform.isIOS;

Future<String> defaultDataStorageRoot() async =>
    '${(await getApplicationDocumentsDirectory()).path}/waar_hook_data';

/// Returns true if [path] can be created and written with dart:io.
Future<bool> isDataStoragePathWritable(String path) async {
  if (path.isEmpty) return false;
  try {
    final probeDir = Directory('$path/.waar_write_probe');
    await probeDir.create(recursive: true);
    final probeFile = File('${probeDir.path}/probe');
    await probeFile.writeAsString('ok');
    await probeFile.delete();
    await probeDir.delete(recursive: true);
    return true;
  } catch (_) {
    return false;
  }
}

const String kDataStorageBasePathKey = 'data_storage_base_path';
const String kDataStorageEnvKey = 'data_storage_env';

enum DataStorageEnv {
  debug('debug', '测试环境'),
  release('release', '正式环境');

  final String dirName;
  final String label;
  const DataStorageEnv(this.dirName, this.label);

  static DataStorageEnv fromName(String? name) {
    return DataStorageEnv.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DataStorageEnv.debug,
    );
  }
}

/// Release 包固定正式环境，Debug 包固定测试环境。
DataStorageEnv get buildDataStorageEnv =>
    kReleaseMode ? DataStorageEnv.release : DataStorageEnv.debug;

Future<String> loadDataStorageBasePath() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(kDataStorageBasePathKey) ?? '';
  if (stored.isEmpty) return '';
  if (isMobileDataStorage) {
    // Ignore desktop-style paths saved on mobile; they are usually not writable.
    await prefs.remove(kDataStorageBasePathKey);
    return '';
  }
  if (!await isDataStoragePathWritable(stored)) {
    await prefs.remove(kDataStorageBasePathKey);
    return '';
  }
  return stored;
}

Future<DataStorageEnv> loadDataStorageEnv() async {
  final env = buildDataStorageEnv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDataStorageEnvKey, env.name);
  return env;
}

Future<void> saveDataStorageBasePath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  final trimmed = path.trim();
  if (isMobileDataStorage || trimmed.isEmpty) {
    await prefs.remove(kDataStorageBasePathKey);
    return;
  }
  if (!await isDataStoragePathWritable(trimmed)) {
    throw StateError('数据目录不可写：$trimmed');
  }
  await prefs.setString(kDataStorageBasePathKey, trimmed);
}

Future<void> saveDataStorageEnv(DataStorageEnv env) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDataStorageEnvKey, buildDataStorageEnv.name);
}

/// Resolves the data root actually used for persistence.
Future<String> resolveDataStorageRoot({required String basePath}) async {
  if (!isMobileDataStorage &&
      basePath.isNotEmpty &&
      await isDataStoragePathWritable(basePath)) {
    return basePath;
  }
  return defaultDataStorageRoot();
}

/// Ensures `{base}/{debug|release}/work` exists and returns the work dir.
Future<String> resolveWorkDir({
  required String basePath,
  required DataStorageEnv env,
}) async {
  final root = await resolveDataStorageRoot(basePath: basePath);

  for (final e in DataStorageEnv.values) {
    await Directory('$root/${e.dirName}').create(recursive: true);
  }

  final workDir = '$root/${env.dirName}/work';
  await Directory(workDir).create(recursive: true);
  return workDir;
}

Future<String?> pickDataStorageDirectory() async {
  if (isMobileDataStorage) return null;
  return getDirectoryPath(confirmButtonText: '选择');
}
