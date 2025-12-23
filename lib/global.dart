import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'common/index.dart';

class Global {
  static Future<void> init() async {
    // 插件初始化：
    //这个表示先就行原生端（ios android）插件注册，然后再处理后续操作，这样能保证代码运行正确。
    WidgetsFlutterBinding.ensureInitialized();

   // 注册Socket服务（永久单例）
    Get.put(SocketService(), permanent: true);
    // 工具类
    await Storage().init();
    
    // 初始化队列
    await Future.wait([
      // 配置服务
      Get.putAsync<ConfigService>(() async => await ConfigService().init()),    
    ]).whenComplete(() {});
    
    // 应用启动后自动发现并连接服务器（异步执行，不阻塞启动）
    _autoConnectServers();
    
    // 如果自动发现失败，可以取消注释下面的代码，手动指定服务器 IP
    // _manualConnectServers();
  }
  
  /// 自动发现并连接局域网内的服务器
  static Future<void> _autoConnectServers() async {
    try {
      final socketService = Get.find<SocketService>();
      print('开始自动发现服务器...');
      
      // 扫描局域网内的服务器（超时3秒）
      final results = await socketService.autoDiscoverAndConnectAll(
        timeout: const Duration(seconds: 3),
      );
      
      if (results[ServerType.wall] == true) {
        print('✅ 墙面服务器已连接');
      } else {
        print('❌ 墙面服务器未找到或连接失败');
      }
      
      if (results[ServerType.desktop] == true) {
        print('✅ 桌面服务器已连接');
      } else {
        print('❌ 桌面服务器未找到或连接失败');
      }
    } catch (e) {
      print('自动发现服务器失败: $e');
    }
  }
  
  /// 手动连接服务器（当自动发现失败时使用）
  /// 请修改下面的 IP 地址为你的实际服务器地址
  // ignore: unused_element
  static Future<void> _manualConnectServers() async {
    try {
      print('手动连接服务器...');
      
      // ⚠️ 请修改为你的墙面服务器实际 IP 地址
      const wallServerIp = '192.168.1.100';
      // TCP 端口（默认 8000）
      const serverPort = 8000;
      
      // 连接墙面服务器
      final wallSuccess = await connectToWallServer(wallServerIp, port: serverPort);
      if (wallSuccess) {
        print('✅ 手动连接墙面服务器成功');
      }
      
      // 连接桌面服务器（如果需要，取消注释并修改 IP）
      // const deskServerIp = '192.168.1.101';
      // final deskSuccess = await connectToDesktopServer(deskServerIp, port: serverPort);
      // if (deskSuccess) {
      //   print('✅ 手动连接桌面服务器成功');
      // }
    } catch (e) {
      print('手动连接服务器失败: $e');
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
    print('尝试连接墙面服务器: $ip:$port');
    final success = await socketService.connectToWallServer(ip, port: port);
    if (success) {
      print('✅ 墙面服务器连接成功: $ip:$port');
    } else {
      print('❌ 墙面服务器连接失败: $ip:$port');
    }
    return success;
  }
  
  /// 手动连接到指定 IP 的桌面服务器
  static Future<bool> connectToDesktopServer(String ip, {int port = 8000}) async {
    final socketService = Get.find<SocketService>();
    print('尝试连接桌面服务器: $ip:$port');
    final success = await socketService.connectToDesktopServer(ip, port: port);
    if (success) {
      print('✅ 桌面服务器连接成功: $ip:$port');
    } else {
      print('❌ 桌面服务器连接失败: $ip:$port');
    }
    return success;
  }
  
  /// 打印当前服务器连接状态（用于调试）
  static void printConnectionStatus() {
    final socketService = Get.find<SocketService>();
    print('======== 服务器连接状态 ========');
    print('墙面服务器:');
    print('  - 已连接: ${socketService.isWallConnected}');
    print('  - IP: ${socketService.connectedWallServerIp.value ?? "未连接"}');
    print('  - 状态: ${socketService.wallConnectionState.value}');
    print('桌面服务器:');
    print('  - 已连接: ${socketService.isDesktopConnected}');
    print('  - IP: ${socketService.connectedDesktopServerIp.value ?? "未连接"}');
    print('  - 状态: ${socketService.desktopConnectionState.value}');
    print('================================');
  }
  
  /// 测试发送课程开启命令（用于调试）
  static void testOpenCourse(String courseName) {
    final socketService = Get.find<SocketService>();
    
    printConnectionStatus();
    
    if (!socketService.isWallConnected) {
      print('❌ 无法发送：墙面服务器未连接');
      return;
    }
    
    print('发送测试命令: 开启课程 "$courseName"');
    socketService.controlApplication(ServerType.wall, courseName, true);
    print('✅ 测试命令已发送');
  }
}

