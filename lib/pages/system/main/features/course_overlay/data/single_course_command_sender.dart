import 'package:get/get.dart';

import 'package:think_nest/common/index.dart';

import 'course_net_operation_table.dart';

class PcCourseCommandSender {
  SocketService get _socketService => Get.find<SocketService>();

  Future<bool> openWallCourse({required String courseId}) async {
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

    print('📤 正在发送开启课程命令...');
    _socketService.controlApplication(ServerType.wall, courseId, true);
    print('✅ 开启课程命令已发送: $courseId');
    print('');
    return true;
  }

  Future<bool> closeWallCourse({required String courseId}) async {
    print('📤 关闭墙面课程: $courseId');

    if (!_socketService.isWallConnected) {
      print('❌ 墙面服务器未连接，无法关闭课程');
      return true;
    }

    _socketService.controlApplication(ServerType.wall, courseId, false);
    print('✅ 已发送关闭墙面课程命令: $courseId');
    return true;
  }

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

  Future<bool> closeDeskCourse({required String courseId}) async {
    print('📤 关闭桌面课程: $courseId');

    if (!_socketService.isDesktopConnected) {
      print('❌ 桌面服务器未连接，无法关闭课程');
      return true;
    }

    _socketService.controlApplication(ServerType.desktop, courseId, false);
    print('✅ 已发送关闭桌面课程命令: $courseId');
    return true;
  }

  Future<bool> setWallCourseVolume({required int volume}) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法设置音量');
      return false;
    }

    _socketService.setWallVolume(volume);
    print('已发送墙面音量设置命令: $volume');
    return true;
  }

  Future<bool> setDeskCourseVolume({required int volume}) async {
    if (!_socketService.isDesktopConnected) {
      print('桌面服务器未连接，无法设置音量');
      return false;
    }

    _socketService.setDesktopVolume(volume);
    print('已发送桌面音量设置命令: $volume');
    return true;
  }

  Future<bool> startDeskGame(bool isOn) async {
    if (!_socketService.isDesktopConnected) {
      print('桌面服务器未连接，无法开启游戏');
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.desktop,
      isOn ? CourseNetOperationTable.deskPlayTest.code : CourseNetOperationTable.deskTestOver.code,
    );
    print('已发送开启桌面游戏命令');
    return true;
  }

  Future<bool> leftWallOpenOrClose(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    print('已发送开启/关闭左墙面命令');
    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallLClose.code : CourseNetOperationTable.wallLOpen.code,
    );
    return true;
  }

  Future<bool> midWallOpenOrClose(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }

    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallMClose.code : CourseNetOperationTable.wallMOpen.code,
    );
    return true;
  }

  Future<bool> rightWallOpenOrClose(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallRClose.code : CourseNetOperationTable.wallROpen.code,
    );
    return true;
  }

  Future<bool> leftWallEnbale(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallLPause.code : CourseNetOperationTable.wallLPlay.code,
    );
    return true;
  }

  Future<bool> midWallEnbale(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallMPause.code : CourseNetOperationTable.wallMPlay.code,
    );
    return true;
  }

  Future<bool> rightWallEnbale(bool isOn) async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(
      ServerType.wall,
      isOn ? CourseNetOperationTable.wallRPause.code : CourseNetOperationTable.wallRPlay.code,
    );
    return true;
  }

  Future<bool> leftWallRestart() async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(ServerType.wall, CourseNetOperationTable.wallLRestart.code);
    return true;
  }

  Future<bool> midWallRestart() async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(ServerType.wall, CourseNetOperationTable.wallMRestart.code);
    return true;
  }

  Future<bool> rightWallRestart() async {
    if (!_socketService.isWallConnected) {
      print('墙面服务器未连接，无法关闭课程');
      return false;
    }
    _socketService.sendUnityOperation(ServerType.wall, CourseNetOperationTable.wallRRestart.code);
    return true;
  }
}
