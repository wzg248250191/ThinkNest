/// 常量
class Constants {
  /// 服务 api 基础地址
  static const String apiUrl = 'https://api.example.com';

  /// App 文件存储父目录名称
  ///
  /// 说明：
  /// - 用于统一管理日志、设备配置导入导出等文件
  static const String appFilesRootDirName = 'think_nest_files';
}

/// 本地存储 Key 统一常量
///
/// 说明：
/// - 所有 SharedPreferences/Storage 相关 key 请集中在此处维护
/// - 命名保持前缀 + 业务含义 + 版本号，例如：course_list_cache_v1
class StorageKeys {
  /// 课程列表缓存 key（用于课程页与 Socket 服务共享）
  static const String courseListCache = 'course_list_cache_v1';

  /// Socket 记住的“墙面服务器 IP” key
  static const String lastWallServerIp = 'socket_last_wall_server_ip_v1';

  /// Socket 记住的“墙面服务器端口” key
  static const String lastWallServerPort = 'socket_last_wall_server_port_v1';

  /// Socket 记住的“桌面服务器 IP” key
  static const String lastDesktopServerIp = 'socket_last_desktop_server_ip_v1';

  /// Socket 记住的“桌面服务器端口” key
  static const String lastDesktopServerPort = 'socket_last_desktop_server_port_v1';

  /// Socket 日志开关（重要日志）
  static const String socketLogEnabled = 'socket_log_enabled_v1';

  /// 一体化页面“设备配置”本地存储 key
  static const String integrationDeviceConfigs = 'integration_device_configs_v1';

  /// 一体化页面“开关状态集合”本地存储 key（当日有效）
  static const String integrationSwitchStates = 'integration_switch_states_v1';

  /// 课程会话状态存储 key（课程是否启用、双控等）
  static const String activeCourseSession = 'active_course_session';

  /// 课程墙面音量存储 key
  static const String courseWallVolume = 'course_wall_volume_v1';

  /// 课程桌面音量存储 key
  static const String courseDeskVolume = 'course_desk_volume_v1';
}
