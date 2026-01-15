import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_store_plus/media_store_plus.dart';

import 'common/index.dart';

class Global {
  /// 仅在 Debug 下打印日志，避免 Release 额外开销
  static void _log(String message) {
    DebugUtils.log(message, name: 'global');
  }

  /// 全局初始化入口
  ///
  /// 说明：
  /// - 注册常驻服务（GetX）
  /// - 初始化本地存储
  /// - 启动后异步恢复 Socket 连接（不阻塞启动）
  static Future<void> init() async {
    // 关键：优先初始化日志落盘，确保启动阶段的错误/打印也能被记录
    final logService = Get.put(AppLogService(), permanent: true);
    await logService.init();

    if (Platform.isAndroid) {
      try {
        // 关键：Android 公共 Downloads 写入依赖 MediaStore 初始化与 appFolder 设置
        await MediaStore.ensureInitialized();
        MediaStore.appFolder = 'ThinkNest';
      } catch (e, s) {
        // 关键：初始化失败不应阻塞启动，记录错误便于排查
        AppLogService.tryRecordError(e, s, tag: 'media_store_init');
      }
    }

    // 注册Socket服务（永久单例）
    Get.put(SocketService(), permanent: true);
    // 工具类
    await Storage().init();
    // 关键逻辑：从本地存储加载 Socket 日志开关；首次启动默认开启，便于排查连接/重连问题。
    await DebugUtils.initSocketLogSwitch();

    // 注册并初始化配置服务（GetX 常驻服务），确保主题/版本等信息在首屏前可用
    await Get.putAsync<ConfigService>(() async => await ConfigService().init());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 启动首帧渲染完成后，延迟一段时间再恢复服务器连接，
      // 避免网络发现/重连逻辑与首屏 UI 抢占主线程资源。
      Future.delayed(const Duration(milliseconds: 1500), () {
        _recoverServersFromCache();
      });
    });
  }
  
  /// 启动阶段尝试恢复服务器连接（墙面/桌面两条链路）
  ///
  /// 说明：
  /// - 优先用历史 IP 直连
  /// - 必要时做短 UDP 扫描兜底
  static Future<void> _recoverServersFromCache() async {
    try {
      final socketService = Get.find<SocketService>();
      // 关键逻辑：只有在确实存在未连接链路时才触发启动恢复，避免“已连接仍输出/仍触发”的误导。
      if (socketService.isConnected(ServerType.wall) && socketService.isConnected(ServerType.desktop)) {
        return;
      }

      final results = await socketService.recoverConnectionsAtStartup();
      
      if (results[ServerType.wall] == true) {
        _log('app启动->连接结果|墙面|成功');
      } else {
        _log('app启动->连接结果|墙面|失败');
      }
      
      if (results[ServerType.desktop] == true) {
        _log('app启动->连接结果|桌面|成功');
      } else {
        _log('app启动->连接结果|桌面|失败');
      }
    } catch (e) {
      _log('恢复历史服务器连接失败: $e');
    }
  }
}
