import 'dart:async';
import 'dart:io';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:think_nest/common/index.dart';

class SettingsUpdateService {
  SettingsUpdateService();

  static const String updateApkUrl = 'https://web-1320069022.cos.ap-shanghai.myqcloud.com/apk/ThinkingNest.apk';

  bool _isCheckingUpdate = false;
  bool _androidMediaStoreReady = false;

  /// 手动检查更新并触发下载安装
  Future<void> checkUpdateManually() async {
    if (_isCheckingUpdate) return;
    if (!Platform.isAndroid) {
      ToastUtils.show('仅支持 Android 安装包更新');
      return;
    }
    _isCheckingUpdate = true;
    try {
      ToastUtils.showLoading('正在检查更新');
      final _RemoteVersionInfo? remote = await _fetchRemoteVersionInfo(updateApkUrl);
      ToastUtils.hide();
      if (remote == null) {
        ToastUtils.show('下载链接无效或已失效', type: ToastType.error);
        return;
      }
      final int localVersionCode = await _readLocalVersionCode();
      // 关键：仅在远端版本号大于本地版本号时提示更新，避免重复下载安装
      if (remote.versionCode <= localVersionCode) {
        ToastUtils.show('已是最新版本');
        return;
      }
      final bool ok = (await ConfirmDialog.show<bool>(
            title: '发现新版本 v${remote.versionName}:${remote.versionCode}，是否下载并安装？',
            leftText: '取消',
            rightText: '下载',
            returnBoolResult: true,
            barrierDismissible: true,
          )) ??
          false;
      if (!ok) return;
      ToastUtils.showLoading('正在下载，请稍候');
      final File? apkFile = await _downloadApkToDownloads(updateApkUrl);
      ToastUtils.hide();
      if (apkFile == null) {
        ToastUtils.show('下载失败', type: ToastType.error);
        return;
      }
      final result = await OpenFilex.open(apkFile.path);
      if (result.type != ResultType.done) {
        await ConfirmDialog.show<void>(
          title:
              '未弹出安装界面，请到文件管理器打开以下路径并安装：\n${apkFile.path}\n如仍失败，请在系统设置中允许本应用安装未知来源应用。',
          rightText: '知道了',
          leftText: '关闭',
          barrierDismissible: true,
        );
        return;
      }
      ToastUtils.show('已尝试打开安装器，请完成安装');
    } catch (_) {
      ToastUtils.hide();
      ToastUtils.show('更新检查失败', type: ToastType.error);
    } finally {
      _isCheckingUpdate = false;
    }
  }

  /// 获取远端版本信息（COS 元数据）
  Future<_RemoteVersionInfo?> _fetchRemoteVersionInfo(String url) async {
    final headers = await _requestHeaders(url);
    if (headers == null) {
      return null;
    }
    final String versionCodeRaw =
        headers['x-cos-meta-versioncode']?.trim() ?? '';
    final String versionName =
        headers['x-cos-meta-versionname']?.trim() ?? '';
    final int? versionCode = int.tryParse(versionCodeRaw);
    if (versionCode == null) {
      return null;
    }
    return _RemoteVersionInfo(
      versionCode: versionCode,
      versionName: versionName.isEmpty ? '-' : versionName,
    );
  }

  /// 读取本地版本号
  Future<int> _readLocalVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    final buildNumber = info.buildNumber.trim();
    return int.tryParse(buildNumber) ?? 0;
  }

  /// 请求远端资源头信息
  Future<Map<String, String>?> _requestHeaders(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(url);
      try {
        final request = await client.headUrl(uri);
        request.followRedirects = true;
        final response = await request.close();
        if (response.statusCode == 200) {
          return _headersToMap(response.headers);
        }
        // 关键：部分对象存储会禁用 HEAD，这里回退到 GET 以避免误判链接失效
        if (response.statusCode != 405 && response.statusCode != 403) {
          return null;
        }
      } catch (_) {}
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode == 200 || response.statusCode == 206) {
        return _headersToMap(response.headers);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 下载 APK 到 Downloads/ThinkNest 并返回文件
  Future<File?> _downloadApkToDownloads(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      final response = await request.close();
      // 关键：允许 206 响应，避免部分对象存储开启分段传输导致误判失败
      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }
      await _ensureAndroidMediaStoreReady();
      final String fileName = 'ThinkingNest_update.apk';
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      final IOSink sink = tempFile.openWrite();
      final int total = response.contentLength;
      int received = 0;
      int lastPercent = -1;
      int lastUpdateMs = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final int now = DateTime.now().millisecondsSinceEpoch;
          if (total > 0) {
            final int percent = ((received * 100) / total).floor().clamp(0, 100);
            if (percent != lastPercent && now - lastUpdateMs > 200) {
              ToastUtils.showLoading('正在下载 $percent%');
              lastPercent = percent;
              lastUpdateMs = now;
            }
          } else {
            if (now - lastUpdateMs > 500) {
              final double mb = received / 1024 / 1024;
              ToastUtils.showLoading('正在下载 ${mb.toStringAsFixed(1)}MB');
              lastUpdateMs = now;
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (total > 0 && lastPercent < 100) {
        ToastUtils.showLoading('正在下载 100%');
      }
      final String? savedPath = await _saveApkToAndroidDownloads(tempFile, fileName);
      if (savedPath == null) {
        return null;
      }
      return File(savedPath);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _ensureAndroidMediaStoreReady() async {
    if (!Platform.isAndroid) return;
    if (_androidMediaStoreReady) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'ThinkNest';
    _androidMediaStoreReady = true;
  }

  Future<String?> _saveApkToAndroidDownloads(File tempFile, String fileName) async {
    final String expectedPath =
        '/storage/emulated/0/Download/${_androidUpdatesRelativePath().replaceAll('/', Platform.pathSeparator)}${Platform.pathSeparator}$fileName';
    try {
      final SaveInfo? info = await MediaStore().saveFile(
        tempFilePath: tempFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: _androidUpdatesRelativePath(),
      );
      if (info == null) {
        return expectedPath;
      }
      final String displayName = info.name.trim();
      final String safeDisplayName = displayName.isEmpty ? fileName : displayName;
      if (safeDisplayName.isEmpty) {
        return null;
      }
      return '/storage/emulated/0/Download/${_androidUpdatesRelativePath().replaceAll('/', Platform.pathSeparator)}${Platform.pathSeparator}$safeDisplayName';
    } catch (_) {
      return expectedPath;
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  String _androidUpdatesRelativePath() {
    return 'ThinkNest/updates';
  }

  /// 将响应头转为普通 Map
  Map<String, String> _headersToMap(HttpHeaders headers) {
    final Map<String, String> result = <String, String>{};
    headers.forEach((name, values) {
      result[name.toLowerCase()] = values.join(',');
    });
    return result;
  }
}

class _RemoteVersionInfo {
  const _RemoteVersionInfo({
    required this.versionCode,
    required this.versionName,
  });

  final int versionCode;
  final String versionName;
}
