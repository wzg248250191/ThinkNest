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
  final int savedAtMs;

  ActiveCourseModel({
    required this.courseId,
    required this.wallEnabled,
    required this.deskEnabled,
    this.doubleControl = false,
    required this.savedAtMs,
  });

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'wallEnabled': wallEnabled,
    'deskEnabled': deskEnabled,
    'doubleControl': doubleControl,
    'savedAtMs': savedAtMs,
  };

  factory ActiveCourseModel.fromJson(Map<String, dynamic> json) {
    return ActiveCourseModel(
      courseId: json['courseId'],
      wallEnabled: json['wallEnabled'] ?? false,
      deskEnabled: json['deskEnabled'] ?? false,
      doubleControl: json['doubleControl'] ?? false,
      savedAtMs: _parseInt(json['savedAtMs']),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
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
  final Rxn<ServerType> lastStatusServerType = Rxn<ServerType>();

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

        final now = DateTime.now();
        final savedAtMs = model.savedAtMs;
        if (savedAtMs <= 0) {
          _storage.remove(_storageKey);
          currentCourseId.value = null;
          wallCourseEnabled.value = false;
          deskCourseEnabled.value = false;
          isWallDoubleControl.value = false;
          return;
        }
        final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
        if (!_isSameLocalDay(savedAt, now)) {
          _storage.remove(_storageKey);
          currentCourseId.value = null;
          wallCourseEnabled.value = false;
          deskCourseEnabled.value = false;
          isWallDoubleControl.value = false;
          return;
        }

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
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
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
    lastStatusServerType.value = null;
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
        break;
      case MSGTYPE.Status:
        // 强制触发更新，即使状态相同
        lastOperationStatus.value = null; 
        lastOperationStatus.value = message.mSGstatus.operationstatus;
        lastStatusInfo.value = message.mSGstatus.info;
        lastStatusServerType.value = serverType;
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

///桌面没有操作符
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
       wallCourseEnabled.value = true;
       ToastUtils.hide();
    }
  }

  void handleDeskData(UnityMessage msg) {
    if (msg.hasUnityData()) {
      final data = msg.unityData;
      if (data.specifying == CourseNetOperationTable.desktopClassGeneral.code) {      
         deskCourseEnabled.value = true;
          ToastUtils.hide();
      }
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
