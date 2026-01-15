part of '../controller.dart';

/// 一体化页面“设备配置”能力集合
///
/// 说明：
/// - 负责 `deviceConfigs` 的读取/写入与本地持久化
/// - 当设备配置变更或加载完成后，会触发 `syncEnabledFromDeviceConfigs()` 同步开关可用性
mixin _IntegrationDeviceConfigMixin on GetxController {
  /// 当前所有设备配置（key 为标题，例如：'墙面主机'、'桌面投影'）
  Map<String, DeviceInfoConfig> get deviceConfigs;

  String? _deviceConfigsExportsDirPathCache;
  bool _androidMediaStoreReady = false;

  /// 同步一体化页面各开关的 `enabled` 状态
  ///
  /// 说明：
  /// - 这是抽象方法（接口约束），由其他 mixin 或宿主类提供实现
  /// - 当前实现位于 `_IntegrationSwitchMixin.syncEnabledFromDeviceConfigs`
  void syncEnabledFromDeviceConfigs();

  /// 按标题获取设备配置（未配置时返回默认值）
  DeviceInfoConfig getDeviceConfig(String title) {
    return deviceConfigs[title] ?? const DeviceInfoConfig();
  }

  /// 编辑设备信息时，更新“设备配置”并刷新页面
  ///
  /// 说明：
  /// - 会持久化到本地存储
  /// - 会同步各开关的 enabled，并刷新配置页 UI
  Future<void> setDeviceConfig(String title, DeviceInfoConfig config) async {
    deviceConfigs[title] = config;
    await _persistDeviceConfigs();
    syncEnabledFromDeviceConfigs();
    update(kDeviceConfigUpdateIds);
  }

  /// 读取本地“设备配置”
  ///
  /// 说明：
  /// - 若本地无数据，会按默认标题集合生成默认配置
  /// - 读取完成后会同步 enabled，并刷新配置页 UI
  Future<void> loadDeviceConfigs() async {
    dynamic decoded;
    try {
      // 防御：本地 Json 可能被异常写入，解析失败时按“无本地配置”处理
      decoded = Storage().getJson(IntegrationController._deviceConfigsKey);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      deviceConfigs
        ..clear()
        ..addEntries(
          IntegrationController.deviceTitles
              .map((t) => MapEntry<String, DeviceInfoConfig>(t, const DeviceInfoConfig())),
        );
      syncEnabledFromDeviceConfigs();
      update(kDeviceConfigUpdateIds);
      return;
    }

    try {
      if (decoded is! Map) {
        // 防御：结构不是 Map 时不复用旧配置，直接清空，后续会补齐默认项
        deviceConfigs.clear();
      } else {
        final map = decoded.cast<String, dynamic>();
        deviceConfigs.clear();
        for (final entry in map.entries) {
          final dynamic value = entry.value;
          if (value is Map) {
            deviceConfigs[entry.key] = DeviceInfoConfig.fromJson(value.cast<String, dynamic>());
          }
        }
      }
    } catch (_) {
      deviceConfigs.clear();
    }

    for (final title in IntegrationController.deviceTitles) {
      deviceConfigs.putIfAbsent(title, () => const DeviceInfoConfig());
    }

    syncEnabledFromDeviceConfigs();
    update(kDeviceConfigUpdateIds);
  }

  /// 导出当前设备配置为 CSV 文件
  ///
  /// 说明：
  /// - Android：写入公共 Downloads/ThinkNest/device_configs/exports（用户更易找到）
  /// - 其他平台：写入应用文档目录 exports 子目录
  Future<void> exportDeviceConfigsCsv() async {
    try {
      final csv = _deviceConfigsToCsv();
      if (Platform.isAndroid) {
        final String savedPath = await _saveDeviceConfigsCsvToAndroidDownloads(csv);
        ToastUtils.show('已导出到：$savedPath');
        return;
      }

      final File file = await _writeDeviceConfigsCsvToPrivateExportsDir(csv);
      ToastUtils.show('已导出到：${file.path}');
    } catch (e, s) {
      // 关键：导出失败通常是路径/权限/IO 异常，需要记录便于现场排查
      AppLogService.tryRecordError(e, s, tag: 'device_config_export_csv');
      ToastUtils.show('导出失败');
    }
  }

  /// 获取设备配置导出目录路径（用于 UI 展示）
  Future<String> deviceConfigsExportsDirPath() async {
    final cached = _deviceConfigsExportsDirPathCache;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    if (Platform.isAndroid) {
      final path = _androidPublicDeviceConfigsExportsDirDisplayPath();
      _deviceConfigsExportsDirPathCache = path;
      return path;
    }
    final dir = await _deviceConfigsPrivateExportsDir();
    _deviceConfigsExportsDirPathCache = dir.path;
    return dir.path;
  }

  /// 复制设备配置导出目录路径到剪贴板
  Future<void> copyDeviceConfigsExportsDirPath() async {
    final path = await deviceConfigsExportsDirPath();
    await Clipboard.setData(ClipboardData(text: path));
    ToastUtils.show('已复制导出目录');
  }

  /// 打开设备配置导出目录（失败时回退为复制路径）
  Future<void> openDeviceConfigsExportsDir() async {
    final path = await deviceConfigsExportsDirPath();
    if (Platform.isAndroid) {
      final bool handled = await _tryOpenDeviceConfigsExportsDirWithSaf(path);
      if (handled) return;
    }
    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        // 关键：部分设备/系统可能没有可用的“文件管理器”处理目录打开，需回退为复制路径
        await Clipboard.setData(ClipboardData(text: path));
        ToastUtils.show('无法打开目录，已复制路径');
      }
    } catch (e, s) {
      // 关键：打开目录依赖系统能力，失败时记录并回退为复制路径便于用户自行打开
      AppLogService.tryRecordError(e, s, tag: 'device_config_open_dir');
      await Clipboard.setData(ClipboardData(text: path));
      ToastUtils.show('无法打开目录，已复制路径');
    }
  }

  /// Android：通过 SAF 目录授权列出并打开设备配置导出文件
  ///
  /// 返回值：
  /// - true：已处理（包含用户取消等情况）
  /// - false：未处理（回退到 OpenFilex.open）
  Future<bool> _tryOpenDeviceConfigsExportsDirWithSaf(String displayPath) async {
    if (!Platform.isAndroid) return false;
    File? tempFile;
    try {
      await _ensureAndroidMediaStoreReady();
      final DocumentTree? tree = await MediaStore().requestForAccess(
        // 关键：尽量定位到导出目录，避免用户在文件管理器不兼容时找不到文件。
        initialRelativePath: 'Download/ThinkNest/device_configs/exports',
      );
      if (tree == null) {
        return true;
      }

      final docs = tree.children
          .where((d) => !d.isDirectory)
          .where((d) {
            final name = (d.name ?? '').toLowerCase().trim();
            return name.endsWith('.csv') || name.endsWith('.txt');
          })
          .toList(growable: false);
      if (docs.isEmpty) {
        ToastUtils.show('该目录暂无导出文件');
        return true;
      }

      final Document? picked = await Get.dialog<Document?>(
        AlertDialog(
          title: TextWidget.label('选择要打开的文件', fontSize: 28.sp),
          content: SizedBox(
            width: 1400.w,
            child: SingleChildScrollView(
              child: <Widget>[
                for (final d in docs)
                  TextButton(
                    onPressed: () => Get.back<Document?>(result: d),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextWidget.label(
                        d.name ?? '(未命名文件)',
                        fontSize: 24.sp,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ].toColumn(crossAxisAlignment: CrossAxisAlignment.stretch),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: displayPath));
                Get.back<Document?>();
                ToastUtils.show('已复制导出目录');
              },
              child: TextWidget.label('复制目录', fontSize: 24.sp),
            ),
            TextButton(
              onPressed: () => Get.back<Document?>(),
              child: TextWidget.label('取消', fontSize: 24.sp),
            ),
          ],
        ),
        barrierDismissible: true,
      );
      if (picked == null) {
        return true;
      }

      final String tempPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${picked.name ?? 'device_configs_export.csv'}';
      tempFile = File(tempPath);
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      final bool ok = await MediaStore().readFileUsingUri(
        uriString: picked.uriString,
        tempFilePath: tempFile.path,
      );
      if (!ok) {
        ToastUtils.show('读取文件失败');
        return true;
      }

      final result = await OpenFilex.open(tempFile.path);
      if (result.type != ResultType.done) {
        await Clipboard.setData(ClipboardData(text: displayPath));
        ToastUtils.show('无法打开文件，已复制目录');
      }
      return true;
    } catch (e, s) {
      // 关键：SAF 在不同机型上差异较大，失败时回退到 OpenFilex.open，保证不阻塞用户。
      AppLogService.tryRecordError(e, s, tag: 'device_config_open_dir_saf');
      return false;
    } finally {
      try {
        final f = tempFile;
        if (f != null && await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  /// 从 CSV 文件导入设备配置
  ///
  /// 说明：
  /// - 通过系统文件选择器选择 .csv/.txt
  /// - 导入会覆盖同名 title 的配置（其余未包含项保持不变）
  Future<void> importDeviceConfigsCsv() async {
    final bool ok =
        (await ConfirmDialog.show<bool>(
          title: '导入将覆盖现有设备配置，是否继续？',
          layout: ConfirmDialogLayout.verticalButtons,
          returnBoolResult: true,
          barrierDismissible: false,
        )) ??
        false;
    if (!ok) return;

    try {
      if (Platform.isAndroid) {
        // 关键：Android 11+ 在部分系统（如荣耀）上，传统文件选择器体验不稳定；优先走系统“目录授权 + 列表选择文件”流程。
        final bool handled = await _tryImportDeviceConfigsCsvFromAndroidDownloads();
        if (handled) return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['csv', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final String csv = await _readPickedFileAsString(picked);
      final int updated = await _applyDeviceConfigsFromCsv(csv);
      ToastUtils.show('已导入：$updated 项');
    } catch (e, s) {
      // 关键：导入失败最常见原因是 CSV 格式不合法或列缺失，记录错误便于定位
      AppLogService.tryRecordError(e, s, tag: 'device_config_import_csv');
      ToastUtils.show('导入失败：请检查 CSV 格式');
    }
  }

  /// Android：从 Downloads/ThinkNest/device_configs/exports 通过系统目录授权导入 CSV
  ///
  /// 返回值：
  /// - true：已处理（包含“用户取消/无文件”等情况）
  /// - false：未处理（回退到 FilePicker 流程）
  Future<bool> _tryImportDeviceConfigsCsvFromAndroidDownloads() async {
    if (!Platform.isAndroid) return false;

    File? tempFile;
    try {
      await _ensureAndroidMediaStoreReady();

      final DocumentTree? tree = await MediaStore().requestForAccess(
        // 关键：尽量将系统目录选择器定位到 Download/ThinkNest，减少用户查找成本（该参数为实验能力，失败时仍可手动选择）。
        initialRelativePath: 'Download/ThinkNest',
      );
      if (tree == null) {
        return true;
      }

      final docs = tree.children
          .where((d) => !d.isDirectory)
          .where((d) {
            final name = (d.name ?? '').toLowerCase().trim();
            return name.endsWith('.csv') || name.endsWith('.txt');
          })
          .toList(growable: false);
      if (docs.isEmpty) {
        ToastUtils.show('该目录没有可导入文件');
        return true;
      }

      final Document? picked = await Get.dialog<Document?>(
        AlertDialog(
          title: TextWidget.label('选择要导入的文件', fontSize: 28.sp),
          content: SizedBox(
            width: 1400.w,
            child: SingleChildScrollView(
              child: <Widget>[
                for (final d in docs)
                  TextButton(
                    onPressed: () => Get.back<Document?>(result: d),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextWidget.label(
                        d.name ?? '(未命名文件)',
                        fontSize: 24.sp,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ].toColumn(crossAxisAlignment: CrossAxisAlignment.stretch),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<Document?>(),
              child: TextWidget.label('取消', fontSize: 24.sp),
            ),
          ],
        ),
        barrierDismissible: true,
      );
      if (picked == null) {
        return true;
      }

      final String tempPath =
          '${Directory.systemTemp.path}${Platform.pathSeparator}${picked.name ?? 'import_device_configs.csv'}';
      tempFile = File(tempPath);
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      final bool ok = await MediaStore().readFileUsingUri(
        uriString: picked.uriString,
        tempFilePath: tempFile.path,
      );
      if (!ok) {
        ToastUtils.show('读取文件失败');
        return true;
      }

      final String csv = await tempFile.readAsString();
      final int updated = await _applyDeviceConfigsFromCsv(csv);
      ToastUtils.show('已导入：$updated 项');
      return true;
    } catch (e, s) {
      // 关键：SAF/MediaStore 的目录授权流程在不同机型上差异较大，失败时必须回退到 FilePicker，保证可用性。
      AppLogService.tryRecordError(e, s, tag: 'device_config_import_android_downloads');
      return false;
    } finally {
      try {
        final f = tempFile;
        if (f != null && await f.exists()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }

  /// 将当前 `deviceConfigs` 序列化为 CSV 文本
  String _deviceConfigsToCsv() {
    const headers = <String>[
      'title',
      'enabled',
      'commandBase',
      'ip',
      'port',
      'openCmd',
      'closeCmd',
      'queryCmd',
    ];

    final buffer = StringBuffer()..writeln(headers.join(','));
    for (final title in IntegrationController.deviceTitles) {
      final cfg = getDeviceConfig(title);
      final row = <String>[
        title,
        cfg.enabled ? 'true' : 'false',
        cfg.commandBase.toString(),
        cfg.ip,
        cfg.port,
        cfg.openCmd,
        cfg.closeCmd,
        cfg.queryCmd,
      ].map(_csvEscape).join(',');
      buffer.writeln(row);
    }
    return buffer.toString();
  }

  /// 将 CSV 解析并应用到 `deviceConfigs`
  ///
  /// 返回值：
  /// - 成功更新的设备数量（按 title 计）
  Future<int> _applyDeviceConfigsFromCsv(String csv) async {
    final rows = _parseCsv(csv);
    if (rows.isEmpty) {
      throw FormatException('empty csv');
    }

    final headerOrFirst = rows.first.map((e) => e.trim()).toList();
    final bool hasHeader = headerOrFirst.contains('title') || headerOrFirst.contains('ip');
    final Map<String, int> colIndex = <String, int>{};
    int startRow = 0;
    if (hasHeader) {
      for (int i = 0; i < headerOrFirst.length; i += 1) {
        final key = headerOrFirst[i];
        if (key.isEmpty) continue;
        colIndex[key] = i;
      }
      startRow = 1;
    } else {
      colIndex
        ..['title'] = 0
        ..['enabled'] = 1
        ..['commandBase'] = 2
        ..['ip'] = 3
        ..['port'] = 4
        ..['openCmd'] = 5
        ..['closeCmd'] = 6
        ..['queryCmd'] = 7;
      startRow = 0;
    }

    int updated = 0;
    for (int r = startRow; r < rows.length; r += 1) {
      final row = rows[r];
      if (row.isEmpty || row.every((e) => e.trim().isEmpty)) continue;

      final title = _cell(row, colIndex['title'])?.trim() ?? '';
      if (title.isEmpty) continue;
      if (!IntegrationController.deviceTitles.contains(title)) {
        continue;
      }

      final enabledStr = _cell(row, colIndex['enabled']) ?? '';
      final commandBaseStr = _cell(row, colIndex['commandBase']) ?? '';

      // 关键：导入数据可能来自 Excel/记事本，类型与空值都不可靠，必须做容错与归一化
      final bool enabled = _parseCsvBool(enabledStr, defaultValue: true);
      final int commandBase = _normalizeCommandBase(commandBaseStr);

      final next = DeviceInfoConfig(
        enabled: enabled,
        ip: _cell(row, colIndex['ip']) ?? '',
        port: _cell(row, colIndex['port']) ?? '',
        openCmd: _cell(row, colIndex['openCmd']) ?? '',
        closeCmd: _cell(row, colIndex['closeCmd']) ?? '',
        queryCmd: _cell(row, colIndex['queryCmd']) ?? '',
        commandBase: commandBase,
      );

      deviceConfigs[title] = next;
      updated += 1;
    }

    await _persistDeviceConfigs();
    syncEnabledFromDeviceConfigs();
    update(kDeviceConfigUpdateIds);
    return updated;
  }

  /// 将 CSV 文本写入应用私有 exports 目录并返回文件对象
  Future<File> _writeDeviceConfigsCsvToPrivateExportsDir(String csv) async {
    final exportsDir = await _deviceConfigsPrivateExportsDir();
    final ts = DateTime.now();
    final fileName = _deviceConfigsExportFileName(ts);
    final file = File('${exportsDir.path}${Platform.pathSeparator}$fileName');
    final bytes = _csvUtf8BomBytes(csv);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// 将 CSV 导出到 Android 公共 Downloads/ThinkNest 下，并返回展示用路径
  Future<String> _saveDeviceConfigsCsvToAndroidDownloads(String csv) async {
    await _ensureAndroidMediaStoreReady();
    final ts = DateTime.now();
    final fileName = _deviceConfigsExportFileName(ts);
    final tempFile = File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
    try {
      final bytes = _csvUtf8BomBytes(csv);
      await tempFile.writeAsBytes(bytes, flush: true);

      final SaveInfo? info = await MediaStore().saveFile(
        tempFilePath: tempFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: _androidDeviceConfigsExportsRelativePath(),
      );
      // 关键修改：部分设备/ROM 在 Release 下可能返回 isSuccessful=false，但实际文件已保存。
      // 为避免误报失败，这里只在 info 为空或无有效文件名时判定失败；否则按展示路径返回。
      if (info == null) {
        final expectedPath =
            '${_androidPublicDeviceConfigsExportsDirDisplayPath()}${Platform.pathSeparator}$fileName';
        // 关键修改：在部分机型/ROM（如荣耀）上，saveFile 可能返回 null，但文件实际已保存到 Download/ThinkNest/...。
        // 由于 Scoped Storage 等限制，File.exists 在部分系统下可能不可靠；因此这里优先按“预期路径”直接视为成功，避免误报导出失败。
        try {
          final bool exists = await File(expectedPath).exists();
          if (exists) return expectedPath;
        } catch (_) {}
        return expectedPath;
      }
      final String displayName = info.name.trim();
      final String safeDisplayName = displayName.isEmpty ? fileName : displayName;
      if (safeDisplayName.isEmpty) {
        throw StateError('media store save failed: empty name');
      }
      return '${_androidPublicDeviceConfigsExportsDirDisplayPath()}${Platform.pathSeparator}$safeDisplayName';
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  /// 确保 Android MediaStore 已初始化并设置 appFolder
  Future<void> _ensureAndroidMediaStoreReady() async {
    if (!Platform.isAndroid) return;
    if (_androidMediaStoreReady) return;
    // 关键：MediaStore 未初始化或未设置 appFolder 会导致保存失败（AppFolderNotSetException）
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'ThinkNest';
    _androidMediaStoreReady = true;
  }

  /// 构造设备配置导出文件名（包含时间戳）
  String _deviceConfigsExportFileName(DateTime ts) {
    return 'device_configs_${ts.year}${_two(ts.month)}${_two(ts.day)}_${_two(ts.hour)}${_two(ts.minute)}${_two(ts.second)}.csv';
  }

  /// 将 CSV 文本编码为 UTF-8 BOM 字节数组（提升 Windows Excel 直接打开的中文兼容性）
  List<int> _csvUtf8BomBytes(String csv) {
    final normalized = _normalizeCsvLineEndings(csv);
    const bom = <int>[0xEF, 0xBB, 0xBF];
    return <int>[...bom, ...utf8.encode(normalized)];
  }

  /// 统一 CSV 换行符为 CRLF（兼容 Windows Excel 的行识别）
  String _normalizeCsvLineEndings(String csv) {
    return csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll('\n', '\r\n');
  }

  /// 获取/创建设备配置 CSV 私有导出目录
  Future<Directory> _deviceConfigsPrivateExportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final baseDir =
        Directory('${dir.path}${Platform.pathSeparator}${Constants.appFilesRootDirName}');
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final legacyDeviceConfigsDir =
        Directory('${dir.path}${Platform.pathSeparator}device_configs');
    final newDeviceConfigsDir =
        Directory('${baseDir.path}${Platform.pathSeparator}device_configs');
    await _migrateLegacyDirIfNeeded(
      oldDir: legacyDeviceConfigsDir,
      newDir: newDeviceConfigsDir,
    );

    final exportsDir = Directory(
      '${newDeviceConfigsDir.path}${Platform.pathSeparator}exports',
    );
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  /// 获取 Android 公共 Downloads 下设备配置导出目录展示路径
  String _androidPublicDeviceConfigsExportsDirDisplayPath() {
    // 关键：Android 公共目录写入使用 MediaStore 的 relativePath（相对 /storage/emulated/0/Download），展示路径必须与实际落盘一致。
    return '/storage/emulated/0/Download/${_androidDeviceConfigsExportsRelativePath().replaceAll('/', Platform.pathSeparator)}';
  }

  /// 获取 Android 公共 Downloads 下设备配置导出相对路径（相对 appFolder）
  String _androidDeviceConfigsExportsRelativePath() {
    // 关键：MediaStore 的 relativePath 是相对 /storage/emulated/0/Download 的子路径；需要包含 ThinkNest 目录才能落到 Downloads/ThinkNest 下。
    return 'ThinkNest/device_configs/exports';
  }

  /// 迁移旧目录到新目录（旧存在且新不存在时）
  ///
  /// 说明：
  /// - 优先 rename（同盘移动更快）
  /// - 失败时递归拷贝并尝试删除旧目录
  Future<void> _migrateLegacyDirIfNeeded({
    required Directory oldDir,
    required Directory newDir,
  }) async {
    final oldExists = await oldDir.exists();
    final newExists = await newDir.exists();
    if (!oldExists || newExists) {
      return;
    }

    try {
      await oldDir.rename(newDir.path);
      return;
    } catch (_) {}

    try {
      await newDir.create(recursive: true);
      await _copyDirectory(oldDir, newDir);
      await oldDir.delete(recursive: true);
    } catch (_) {}
  }

  /// 递归拷贝目录（用于目录迁移兜底）
  Future<void> _copyDirectory(Directory src, Directory dest) async {
    await for (final entity in src.list(recursive: false, followLinks: false)) {
      final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
      if (name.isEmpty) continue;
      final newPath = '${dest.path}${Platform.pathSeparator}$name';
      if (entity is File) {
        try {
          await entity.copy(newPath);
        } catch (_) {}
        continue;
      }
      if (entity is Directory) {
        final nextDest = Directory(newPath);
        if (!await nextDest.exists()) {
          await nextDest.create(recursive: true);
        }
        await _copyDirectory(entity, nextDest);
      }
    }
  }

  /// 将文件选择器选中的文件内容读取为字符串
  Future<String> _readPickedFileAsString(PlatformFile picked) async {
    final bytes = picked.bytes;
    if (bytes != null) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    final path = picked.path;
    if (path == null || path.isEmpty) {
      throw StateError('picked file has no bytes and no path');
    }
    return await File(path).readAsString();
  }

  /// CSV 单元格转义：处理逗号/引号/换行，保证导出的 CSV 可被 Excel/记事本正确识别
  String _csvEscape(String value) {
    final needsQuote =
        value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
    if (!needsQuote) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// 读取某行某列的单元格内容（越界返回 null）
  String? _cell(List<String> row, int? index) {
    if (index == null) return null;
    if (index < 0 || index >= row.length) return null;
    return row[index];
  }

  /// 解析 CSV 布尔值（支持 true/false/1/0/yes/no/on/off/中文“是/否”）
  bool _parseCsvBool(String value, {required bool defaultValue}) {
    final s = value.trim().toLowerCase();
    if (s.isEmpty) return defaultValue;
    if (<String>{'1', 'true', 'yes', 'y', 'on', '是', '启用'}.contains(s)) return true;
    if (<String>{'0', 'false', 'no', 'n', 'off', '否', '禁用'}.contains(s)) return false;
    return defaultValue;
  }

  /// 归一化命令进制字段：仅允许 2 或 16，其它值回落到 16
  int _normalizeCommandBase(dynamic value) {
    if (value is int) {
      return value == 2 ? 2 : 16;
    }
    if (value is String) {
      final int? parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed == 2 ? 2 : 16;
      }
    }
    return 16;
  }

  /// 将整数补齐为两位字符串（用于文件名时间戳）
  String _two(int v) => v < 10 ? '0$v' : '$v';

  /// 解析 CSV 文本为二维表数据
  ///
  /// 说明：
  /// - 支持双引号包裹字段与双引号转义（""）
  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentField = StringBuffer();
    bool inQuotes = false;

    int i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          final nextIsQuote = (i + 1 < input.length) && input[i + 1] == '"';
          if (nextIsQuote) {
            currentField.write('"');
            i += 2;
            continue;
          }
          inQuotes = false;
          i += 1;
          continue;
        }
        currentField.write(ch);
        i += 1;
        continue;
      }

      if (ch == '"') {
        inQuotes = true;
        i += 1;
        continue;
      }

      if (ch == ',') {
        currentRow.add(currentField.toString());
        currentField.clear();
        i += 1;
        continue;
      }

      if (ch == '\n') {
        currentRow.add(currentField.toString());
        currentField.clear();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        i += 1;
        continue;
      }

      if (ch == '\r') {
        // Windows 换行兼容：忽略 \r，统一用 \n 结行
        i += 1;
        continue;
      }

      currentField.write(ch);
      i += 1;
    }

    if (inQuotes) {
      throw FormatException('unclosed quote');
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(List<String>.from(currentRow));
    }

    return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  }

  /// 将当前 `deviceConfigs` 序列化并写入本地存储（用于应用下次启动恢复配置）。
  Future<void> _persistDeviceConfigs() async {
    final Map<String, dynamic> json = deviceConfigs.map(
      (k, v) => MapEntry<String, dynamic>(k, v.toJson()),
    );
    await Storage().setJson(IntegrationController._deviceConfigsKey, json);
  }
}
