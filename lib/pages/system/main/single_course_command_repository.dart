import 'package:get/get.dart';

import '../../../common/index.dart';

/// 课程详情相关指令仓库（封装协议与发送逻辑）
class SingleCourseCommandRepository {
  /// CommandChannelService（可选，用于 WebSocket 通信）
  CommandChannelService? get _channel {
    if (Get.isRegistered<CommandChannelService>()) {
      return Get.find<CommandChannelService>();
    }
    return null;
  }
  
  /// 获取 SocketService 实例（用于 TCP 通信）
  SocketService get _socketService => Get.find<SocketService>();

  /// 订阅指定课程的实时事件（WebSocket，可选）
  Future<void> subscribeCourse({required String courseId}) async {
    await _send(
      type: 'course.subscribe',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 取消订阅指定课程的实时事件（WebSocket，可选）
  Future<void> unsubscribeCourse({required String courseId}) async {
    await _send(
      type: 'course.unsubscribe',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 请求服务器推送当前课程的初始状态（WebSocket，可选）
  Future<void> requestInitialState({required String courseId}) async {
    await _send(
      type: 'course.state.get',
      courseId: courseId,
      data: const <String, dynamic>{},
    );
  }

  /// 设置墙面开关（WebSocket，可选）
  Future<void> setWallEnabled({
    required String courseId,
    required bool enabled,
  }) async {
    await _send(
      type: 'course.wall.set',
      courseId: courseId,
      data: <String, dynamic>{'enabled': enabled},
    );
  }

  /// 设置桌面开关（WebSocket，可选）
  Future<void> setDeskEnabled({
    required String courseId,
    required bool enabled,
  }) async {
    await _send(
      type: 'course.desk.set',
      courseId: courseId,
      data: <String, dynamic>{'enabled': enabled},
    );
  }

  /// 设置音量（WebSocket，可选）
  Future<void> setWallVolume({
    required String courseId,
    required int volume,
  }) async {
    await _send(
      type: 'course.volume.set',
      courseId: courseId,
      data: <String, dynamic>{'volume': volume},
    );
  }
  /// 设置桌面音量（WebSocket，可选）
  Future<void> setDeskVolume({
    required String courseId,
    required int volume,
  }) async {
    await _send(
      type: 'course.volume.set',
      courseId: courseId,
      data: <String, dynamic>{'volume': volume},
    );
  }

  // ==================== TCP Socket 通信方法（通过 SocketService）====================

  /// 开启墙面课程（通过 TCP Socket 发送到墙面 PC 服务器）
  /// 
  /// [courseId] 课程名称/ID
  /// 返回 true 表示命令已发送（不保证服务器执行成功）
  /// 
  /// 说明：
  /// - 关键路径：`controlApplication(ServerType.wall, courseId, true)`
  /// - 最终会封装为 `MESSAGE(MSGTYPE.ServerRequest)`，并按 `COMMON_REQUEST(10000)` 封包发送
  Future<bool> openWallCourse({required String courseId}) async {
    // 详细调试日志
    print('');
    print('╔════════════════════════════════════════╗');
    print('║         开启墙面课程                    ║');
    print('╠════════════════════════════════════════╣');
    print('║ 课程名称: $courseId');
    print('║ 墙面服务器连接: ${_socketService.isWallConnected}');
    print('║ 墙面服务器IP: ${_socketService.connectedWallServerIp.value ?? "未连接"}');
    print('║ 连接状态: ${_socketService.wallConnectionState.value}');
    print('╚════════════════════════════════════════╝');
    
    if (!_socketService.isWallConnected) {
      print('❌ 错误: 墙面服务器未连接，无法开启课程');
      print('   请先连接服务器后再试');
      return false;
    }
    
    // 使用 SocketService 的 controlApplication 方法（已验证的方法）
    print('📤 正在发送开启课程命令...');
    _socketService.controlApplication(ServerType.wall, courseId, true);
    print('✅ 开启课程命令已发送: $courseId');
    print('');
    return true;
  }

  /// 关闭墙面课程（通过 TCP Socket 发送到墙面 PC 服务器）
  /// 
  /// 说明：
  /// - 关键路径：`controlApplication(ServerType.wall, courseId, false)`
  Future<bool> closeWallCourse({required String courseId}) async {
    print('📤 关闭墙面课程: $courseId');
    
    if (!_socketService.isWallConnected) {
      print('❌ 墙面服务器未连接，无法关闭课程');
      return false;
    }
    
    _socketService.controlApplication(ServerType.wall, courseId, false);
    print('✅ 已发送关闭墙面课程命令: $courseId');
    return true;
  }

  /// 开启桌面课程（通过 TCP Socket 发送到桌面 PC 服务器）
  /// 
  /// 说明：
  /// - 关键路径：`controlApplication(ServerType.desktop, courseId, true)`
  Future<bool> openDeskCourse({required String courseId}) async {
    print('📤 开启桌面课程: $courseId');
    print('   桌面服务器连接: ${_socketService.isDesktopConnected}');
    
    if (!_socketService.isDesktopConnected) {
      print('❌ 桌面服务器未连接，无法开启课程');
      return false;
    }
    
    _socketService.controlApplication(ServerType.desktop, courseId, true);
    print('✅ 已发送开启桌面课程命令: $courseId');
    return true;
  }

  /// 关闭桌面课程（通过 TCP Socket 发送到桌面 PC 服务器）
  /// 
  /// 说明：
  /// - 关键路径：`controlApplication(ServerType.desktop, courseId, false)`
  Future<bool> closeDeskCourse({required String courseId}) async {
    print('📤 关闭桌面课程: $courseId');
    
    if (!_socketService.isDesktopConnected) {
      print('❌ 桌面服务器未连接，无法关闭课程');
      return false;
    }
    
    _socketService.controlApplication(ServerType.desktop, courseId, false);
    print('✅ 已发送关闭桌面课程命令: $courseId');
    return true;
  }

  /// 设置墙面课程音量（通过 TCP Socket）
  Future<bool> setWallCourseVolume({required int volume}) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法设置音量');
      return false;
    }
    
    _socketService.setWallVolume(volume);
    print('已发送墙面音量设置命令: $volume');
    return true;
  }

  /// 设置桌面课程音量（通过 TCP Socket）
  Future<bool> setDeskCourseVolume({required int volume}) async {
    if (!_socketService.isDesktopConnected) {
      print('桌面服务器未连接，无法设置音量');
      return false;
    }
    
    _socketService.setDesktopVolume(volume);
    print('已发送桌面音量设置命令: $volume');
    return true;
  }

  /// 发送课程相关指令（通过 WebSocket，可选）
  Future<void> _send({
    required String type,
    required String courseId,
    required Map<String, dynamic> data,
  }) async {
    final channel = _channel;
    if (channel == null) {
      print('WebSocket 服务未初始化，跳过发送: $type');
      return;
    }
    await channel.send(_buildMessage(
      type: type,
      courseId: courseId,
      data: data,
    ));
  }

  /// 构建指令消息
  CommandMessage _buildMessage({
    required String type,
    required String courseId,
    required Map<String, dynamic> data,
  }) {
    return CommandMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      courseId: courseId,
      data: data,
      timestamp: DateTime.now(),
    );
  }
}
