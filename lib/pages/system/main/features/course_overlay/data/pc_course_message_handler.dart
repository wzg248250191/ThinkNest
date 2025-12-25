import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';
import 'course_net_operation_table.dart';

/// 当前活跃课程的数据模型（用于持久化）
class ActiveCourseModel {
  final String courseId;
  final bool wallEnabled;
  final bool deskEnabled;
  final bool doubleControl;

  ActiveCourseModel({
    required this.courseId,
    required this.wallEnabled,
    required this.deskEnabled,
    this.doubleControl = false,
  });

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'wallEnabled': wallEnabled,
    'deskEnabled': deskEnabled,
    'doubleControl': doubleControl,
  };

  factory ActiveCourseModel.fromJson(Map<String, dynamic> json) {
    return ActiveCourseModel(
      courseId: json['courseId'],
      wallEnabled: json['wallEnabled'] ?? false,
      deskEnabled: json['deskEnabled'] ?? false,
      doubleControl: json['doubleControl'] ?? false,
    );
  }
}

class PcCourseMessageHandler extends GetxService {
  // 持久化 Key
  static const String _storageKey = 'active_course_session';

  final RxnString currentCourseId = RxnString();

  final RxBool wallCourseEnabled = false.obs;
  final RxBool deskCourseEnabled = false.obs;
  /// 是否开启墙面双控（左右同步）
  final RxBool isWallDoubleControl = false.obs;

  final RxInt wallVolume = 100.obs;
  final RxInt deskVolume = 100.obs;

  final Rxn<OperationStatus> lastOperationStatus = Rxn<OperationStatus>();
  final RxnString lastStatusInfo = RxnString();

  StreamSubscription<(ServerType, MESSAGE)>? _sub;

  SocketService get _socketService => Get.find<SocketService>();
  
  // 注入 Storage 工具
  Storage get _storage => Storage();

  @override
  void onInit() {
    super.onInit();
    _ensureSubscribed();
    
    // 1. 初始化时尝试恢复上次的状态
    _restoreState();

    // 2. 监听核心状态变化，自动持久化
    // 使用 ever 监听 wallCourseEnabled 和 deskCourseEnabled 的变化
    // 一旦发生变化，触发 _saveState
    ever(wallCourseEnabled, (_) => _saveState());
    ever(deskCourseEnabled, (_) => _saveState());
    ever(isWallDoubleControl, (_) => _saveState());
  }

  /// 从本地存储恢复状态
  void _restoreState() {
    try {
      final String jsonStr = _storage.getString(_storageKey);
      if (jsonStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(jsonStr);
        final model = ActiveCourseModel.fromJson(jsonMap);

        print('📦 恢复课程状态: ${model.courseId}, 墙面: ${model.wallEnabled}, 桌面: ${model.deskEnabled}, 双控: ${model.doubleControl}');

        // 恢复数据
        currentCourseId.value = model.courseId;
        wallCourseEnabled.value = model.wallEnabled;
        deskCourseEnabled.value = model.deskEnabled;
        isWallDoubleControl.value = model.doubleControl;
      }
    } catch (e) {
      print('❌ 恢复课程状态失败: $e');
      // 出错时清除脏数据
      _storage.remove(_storageKey);
    }
  }

  /// 保存当前状态到本地
  void _saveState() {
    final String? id = currentCourseId.value;
    final bool wall = wallCourseEnabled.value;
    final bool desk = deskCourseEnabled.value;
    final bool doubleCtrl = isWallDoubleControl.value;

    // 如果课程ID为空，或者（墙面和桌面都关闭了），则视为课程结束，清除存储
    if (id == null || (!wall && !desk)) {
      print('🗑️ 课程已结束或未开始，清除本地状态');
      _storage.remove(_storageKey);
      return;
    }

    // 否则，保存当前状态
    final model = ActiveCourseModel(
      courseId: id,
      wallEnabled: wall,
      deskEnabled: desk,
      doubleControl: doubleCtrl,
    );
    
    // 使用 setJson (实际上是 setString + jsonEncode)
    _storage.setJson(_storageKey, model.toJson());
    print('💾 保存课程状态: $id, 墙面: $wall, 桌面: $desk, 双控: $doubleCtrl');
  }

  void attachCourse(String courseId) {
    currentCourseId.value = courseId;
    // courseId 变化时，虽然不会立即触发 saveState (因为监听的是 enabled)，
    // 但后续 enabled 变化时会读取最新的 currentCourseId 进行保存。
    // 为了保险起见，如果当前已有 enabled 状态，切换 ID 后也应该触发一次保存
    if (wallCourseEnabled.value || deskCourseEnabled.value) {
      _saveState();
    }
  }

  void detachCourse() {
    currentCourseId.value = null;
    resetLocalState(enabled: false); 
    lastOperationStatus.value = null;
    lastStatusInfo.value = null;
  }

  void resetLocalState({
    bool enabled = false,
  }) {
    wallCourseEnabled.value = enabled;
    deskCourseEnabled.value = enabled;
  }

  void _ensureSubscribed() {
    if (_sub != null) {
      return;
    }
    _sub = _socketService.allMessageStream.listen((record) {
      final (serverType, message) = record;
      _handleMessage(serverType, message);
    });
  }

  void _handleMessage(ServerType serverType, MESSAGE message) {
    final String? courseId = currentCourseId.value;
    if (courseId == null) {
      return;
    }

    switch (message.mSGtype) {
      case MSGTYPE.ServerResponse:
        _handleServerResponse(serverType, message.serverMessage, courseId);
        break;
      case MSGTYPE.Status:
        // 强制触发更新，即使状态相同
        lastOperationStatus.value = null; 
        lastOperationStatus.value = message.mSGstatus.operationstatus;
        lastStatusInfo.value = message.mSGstatus.info;
        break;
      case MSGTYPE.UnityResponse:
        if (message.hasUnityMessage()) {
          final msg = message.unityMessage;
          if (msg.unityMSGtype == UNITYMSGTYPE.Operation) {
            if (serverType == ServerType.desktop) {
              handleDeskOperation(msg);
            } else if (serverType == ServerType.wall) {
              handleWallOperation(msg);
            }
          } else if (msg.unityMSGtype == UNITYMSGTYPE.Data) {
            if (serverType == ServerType.desktop) {
              handleDeskData(msg);
            }
          }
        }
        break;
      default:
        break;
    }
  }

  void handleDeskOperation(UnityMessage msg) {
    if (msg.operation == CourseNetOperationTable.desktopClassGeneral.code) {}
  }

  void handleWallOperation(UnityMessage msg) {
    //左右墙面一起控制
    if (msg.operation == CourseNetOperationTable.wallDoubleControl.code) {
      isWallDoubleControl.value = true;
    }
    //左右墙面单独控制
    else if (msg.operation == CourseNetOperationTable.wallSingleControl.code) {
      isWallDoubleControl.value = false;
    }
    else if (msg.operation == CourseNetOperationTable.wallClassGeneral.code) {
      _applyCourseEnabled(ServerType.wall, true);
    }
  }

  void handleDeskData(UnityMessage msg) {
    if (msg.hasUnityData()) {
      final data = msg.unityData;
      if (data.specifying == CourseNetOperationTable.desktopClassGeneral.code) {
        _applyCourseEnabled(ServerType.desktop, true);
      }
    }
  }

  void _handleServerResponse(
    ServerType serverType,
    ServerMessage serverMessage,
    String courseId,
  ) {
    if (serverMessage.gameName != courseId) {
      return;
    }

    switch (serverMessage.serverBehaviour) {
      case SERVERBEHAVIOUR.Application:
        _applyCourseEnabled(serverType, serverMessage.on);
        break;
      case SERVERBEHAVIOUR.Volume:
        _applyVolume(serverType, serverMessage.volumeValue);
        break;
      default:
        break;
    }
  }

  void _applyCourseEnabled(ServerType serverType, bool enabled) {
    switch (serverType) {
      case ServerType.wall:
        wallCourseEnabled.value = enabled;
        break;
      case ServerType.desktop:
        deskCourseEnabled.value = enabled;
        break;
    }
  }

  void _applyVolume(ServerType serverType, int volume) {
    final int v = volume.clamp(0, 100);
    switch (serverType) {
      case ServerType.wall:
        wallVolume.value = v;
        break;
      case ServerType.desktop:
        deskVolume.value = v;
        break;
    }
  }

  @override
  void onClose() {
    detachCourse();
    unawaited(_sub?.cancel());
    _sub = null;
    super.onClose();
  }
}
