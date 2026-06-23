import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  return prefs.getString(kDataStorageBasePathKey) ?? '';
}

Future<DataStorageEnv> loadDataStorageEnv() async {
  final env = buildDataStorageEnv;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDataStorageEnvKey, env.name);
  return env;
}

Future<void> saveDataStorageBasePath(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDataStorageBasePathKey, path.trim());
}

Future<void> saveDataStorageEnv(DataStorageEnv env) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kDataStorageEnvKey, buildDataStorageEnv.name);
}

/// Ensures `{base}/{debug|release}/work` exists and returns the work dir.
Future<String> resolveWorkDir({
  required String basePath,
  required DataStorageEnv env,
}) async {
  final root = basePath.isNotEmpty
      ? basePath
      : '${(await getApplicationDocumentsDirectory()).path}/waar_hook_data';

  for (final e in DataStorageEnv.values) {
    await Directory('$root/${e.dirName}').create(recursive: true);
  }

  final workDir = '$root/${env.dirName}/work';
  await Directory(workDir).create(recursive: true);
  return workDir;
}

Future<String?> pickDataStorageDirectory() async {
  return getDirectoryPath(confirmButtonText: '选择');
}
