class DeviceInfoConfig {
  final bool enabled;
  final String ip;
  final String port;
  final String openCmd;
  final String closeCmd;
  final String queryCmd;
  final int commandBase;

  const DeviceInfoConfig({
    this.enabled = true,
    this.ip = '',
    this.port = '',
    this.openCmd = '',
    this.closeCmd = '',
    this.queryCmd = '',
    this.commandBase = 16,
  });

  DeviceInfoConfig copyWith({
    bool? enabled,
    String? ip,
    String? port,
    String? openCmd,
    String? closeCmd,
    String? queryCmd,
    int? commandBase,
  }) {
    return DeviceInfoConfig(
      enabled: enabled ?? this.enabled,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      openCmd: openCmd ?? this.openCmd,
      closeCmd: closeCmd ?? this.closeCmd,
      queryCmd: queryCmd ?? this.queryCmd,
      commandBase: _normalizeCommandBase(commandBase ?? this.commandBase),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'ip': ip,
      'port': port,
      'openCmd': openCmd,
      'closeCmd': closeCmd,
      'queryCmd': queryCmd,
      'commandBase': commandBase,
    };
  }

  factory DeviceInfoConfig.fromJson(Map<String, dynamic> json) {
    final dynamic enabled = json['enabled'];
    final dynamic ip = json['ip'];
    final dynamic port = json['port'];
    final dynamic openCmd = json['openCmd'];
    final dynamic closeCmd = json['closeCmd'];
    final dynamic queryCmd = json['queryCmd'];
    final dynamic commandBase = json['commandBase'];

    return DeviceInfoConfig(
      enabled: enabled is bool ? enabled : true,
      ip: ip is String ? ip : '',
      port: port is String ? port : '',
      openCmd: openCmd is String ? openCmd : '',
      closeCmd: closeCmd is String ? closeCmd : '',
      queryCmd: queryCmd is String ? queryCmd : '',
      commandBase: _normalizeCommandBase(commandBase),
    );
  }

  static int _normalizeCommandBase(dynamic value) {
    if (value is int) {
      return value == 2 ? 2 : 16;
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed == 2 ? 2 : 16;
      }
    }
    return 16;
  }
}
