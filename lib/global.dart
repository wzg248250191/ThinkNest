import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    // 注册Socket服务（永久单例）
    Get.put(SocketService(), permanent: true);
    // 工具类
    await Storage().init();

    // 注册并初始化配置服务（GetX 常驻服务），确保主题/版本等信息在首屏前可用
    await Get.putAsync<ConfigService>(() async => await ConfigService().init());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 启动首帧渲染完成后，延迟一段时间再恢复服务器连接，
      // 避免网络发现/重连逻辑与首屏 UI 抢占主线程资源。
      Future.delayed(const Duration(milliseconds: 1500), () {
        _recoverServersFromCache();
      });
    });
    
    // 如果自动发现失败，可以取消注释下面的代码，手动指定服务器 IP
    // _manualConnectServers();
  }
  
  /// 启动阶段尝试恢复服务器连接（墙面/桌面两条链路）
  ///
  /// 说明：
  /// - 优先用历史 IP 直连
  /// - 必要时做短 UDP 扫描兜底
  static Future<void> _recoverServersFromCache() async {
    try {
      final socketService = Get.find<SocketService>();
      _log('开始恢复历史服务器连接...');

      final results = await socketService.recoverConnectionsAtStartup();
      
      if (results[ServerType.wall] == true) {
        _log('✅ 墙面服务器已连接');
      } else {
        _log('❌ 墙面服务器未恢复连接');
      }
      
      if (results[ServerType.desktop] == true) {
        _log('✅ 桌面服务器已连接');
      } else {
        _log('❌ 桌面服务器未恢复连接');
      }
    } catch (e) {
      _log('恢复历史服务器连接失败: $e');
    }
  }

  // 首屏资源预热逻辑已下线：
  // - 实测环境中，SVG 预热带来的卡顿收益有限，
  // - 反而会在部分设备上与其它初始化任务叠加，形成新的卡顿峰值。
  // 如后续需要重新启用，请根据实际机型再评估。
  
  /// 手动连接服务器（当自动发现失败时使用）
  /// 请修改下面的 IP 地址为你的实际服务器地址
  // ignore: unused_element
  static Future<void> _manualConnectServers() async {
    try {
      _log('手动连接服务器...');
      
      // ⚠️ 请修改为你的墙面服务器实际 IP 地址
      const wallServerIp = '192.168.1.100';
      // TCP 端口（默认 8000）
      const serverPort = 8000;
      
      // 连接墙面服务器
      final wallSuccess = await connectToWallServer(wallServerIp, port: serverPort);
      if (wallSuccess) {
        _log('✅ 手动连接墙面服务器成功');
      }
      
      // 连接桌面服务器（如果需要，取消注释并修改 IP）
      // const deskServerIp = '192.168.1.101';
      // final deskSuccess = await connectToDesktopServer(deskServerIp, port: serverPort);
      // if (deskSuccess) {
      //   _log('✅ 手动连接桌面服务器成功');
      // }
    } catch (e) {
      _log('手动连接服务器失败: $e');
    }
  }
  
  /// 手动重新扫描并连接服务器
  static Future<Map<ServerType, bool>> reconnectServers() async {
    final socketService = Get.find<SocketService>();
    return await socketService.autoDiscoverAndConnectAll(
      timeout: const Duration(seconds: 5),
    );
  }
  
  /// 手动连接到指定 IP 的墙面服务器
  static Future<bool> connectToWallServer(String ip, {int port = 8000}) async {
    final socketService = Get.find<SocketService>();
    _log('尝试连接墙面服务器: $ip:$port');
    final success = await socketService.connect(ServerType.wall, ip, port);
    if (success) {
      _log('✅ 墙面服务器连接成功: $ip:$port');
    } else {
      _log('❌ 墙面服务器连接失败: $ip:$port');
    }
    return success;
  }
  
  /// 手动连接到指定 IP 的桌面服务器
  static Future<bool> connectToDesktopServer(String ip, {int port = 8000}) async {
    final socketService = Get.find<SocketService>();
    _log('尝试连接桌面服务器: $ip:$port');
    final success = await socketService.connect(ServerType.desktop, ip, port);
    if (success) {
      _log('✅ 桌面服务器连接成功: $ip:$port');
    } else {
      _log('❌ 桌面服务器连接失败: $ip:$port');
    }
    return success;
  }
  
  /// 打印当前服务器连接状态（用于调试）
  static void printConnectionStatus() {
    final socketService = Get.find<SocketService>();
    _log('======== 服务器连接状态 ========');
    _log('墙面服务器:');
    _log('  - 已连接: ${socketService.isConnected(ServerType.wall)}');
    _log('  - IP: ${socketService.connectedServerIp(ServerType.wall).value ?? "未连接"}');
    _log('  - 状态: ${socketService.connectionState(ServerType.wall).value}');
    _log('桌面服务器:');
    _log('  - 已连接: ${socketService.isConnected(ServerType.desktop)}');
    _log('  - IP: ${socketService.connectedServerIp(ServerType.desktop).value ?? "未连接"}');
    _log('  - 状态: ${socketService.connectionState(ServerType.desktop).value}');
    _log('================================');
  }
  
  /// 测试发送课程开启命令（用于调试）
  static void testOpenCourse(String courseName) {
    final socketService = Get.find<SocketService>();
    
    printConnectionStatus();
    
    if (!socketService.isConnected(ServerType.wall)) {
      _log('❌ 无法发送：墙面服务器未连接');
      return;
    }
    
    _log('发送测试命令: 开启课程 "$courseName"');
    socketService.controlApplication(ServerType.wall, courseName, true);
    _log('✅ 测试命令已发送');
  }
}
