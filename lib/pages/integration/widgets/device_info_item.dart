import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../common/index.dart';
import '../models/device_info_config.dart';

class DeviceInfoItem extends StatefulWidget {
  const DeviceInfoItem({
    super.key,
    required this.title,
    this.enabled = true,
    this.commandBase = 16,
    this.ip,
    this.port,
    this.openCmd,
    this.closeCmd,
    this.queryCmd,
    this.onChanged,
  });
  
  final String title;//名字
  final bool enabled;//是否启用
  final int commandBase;//命令进制（2 或 16）
  final String? ip;//ip地址
  final String? port;//端口号
  final String? openCmd;//打开指令
  final String? closeCmd;//关闭指令  
  final String? queryCmd;//查询指令
  final ValueChanged<DeviceInfoConfig>? onChanged;

  @override
  State<DeviceInfoItem> createState() => _DeviceInfoItemState();
}

class _DeviceInfoItemState extends State<DeviceInfoItem> {
  late bool _enabled;
  late int _commandBase;
  final List<KeyValueModel<String>> _commandBaseOptions = <KeyValueModel<String>>[
    KeyValueModel<String>(key: '2', value: '2进制'),
    KeyValueModel<String>(key: '16', value: '16进制'),
  ];
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _openCmdController;
  late final TextEditingController _closeCmdController;
  late final TextEditingController _queryController;
  late final VoidCallback _fieldsListener;
  Timer? _emitDebounce;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _commandBase = widget.commandBase == 2 ? 2 : 16;
    _ipController = TextEditingController(text: widget.ip ?? '');
    _portController = TextEditingController(text: widget.port ?? '');
    _openCmdController = TextEditingController(text: widget.openCmd ?? '');
    _closeCmdController = TextEditingController(text: widget.closeCmd ?? '');
    _queryController = TextEditingController(text: widget.queryCmd ?? '');

    _fieldsListener = _onFieldsChanged;
    _ipController.addListener(_fieldsListener);
    _portController.addListener(_fieldsListener);
    _openCmdController.addListener(_fieldsListener);
    _closeCmdController.addListener(_fieldsListener);
    _queryController.addListener(_fieldsListener);
  }

  void _onEnabledChanged(bool value) {
    setState(() {
      _enabled = value;
    });
    _scheduleEmit();
  }

  void _onCommandBaseChanged(KeyValueModel? value) {
    if (value == null) {
      return;
    }
    final int? parsed = int.tryParse(value.key);
    if (parsed == null) {
      return;
    }
    final int next = parsed == 2 ? 2 : 16;
    if (next == _commandBase) {
      return;
    }
    setState(() {
      _commandBase = next;
    });
    _scheduleEmit();
  }

  void _onFieldsChanged() {
    _scheduleEmit();
  }

  void _scheduleEmit() {
    if (_syncing) {
      return;
    }
    if (widget.onChanged == null) {
      return;
    }
    _emitDebounce?.cancel();
    _emitDebounce = Timer(const Duration(milliseconds: 250), _emit);
  }

  void _emit() {
    final cb = widget.onChanged;
    if (cb == null) {
      return;
    }
    cb(_currentConfig());
  }

  DeviceInfoConfig _currentConfig() {
    return DeviceInfoConfig(
      enabled: _enabled,
      ip: _ipController.text,
      port: _portController.text,
      openCmd: _openCmdController.text,
      closeCmd: _closeCmdController.text,
      queryCmd: _queryController.text,
      commandBase: _commandBase,
    );
  }

  @override
  void didUpdateWidget(covariant DeviceInfoItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextIp = widget.ip ?? '';
    final nextPort = widget.port ?? '';
    final nextOpenCmd = widget.openCmd ?? '';
    final nextCloseCmd = widget.closeCmd ?? '';
    final nextQueryCmd = widget.queryCmd ?? '';
    final int nextCommandBase = widget.commandBase == 2 ? 2 : 16;

    final bool enabledChanged = widget.enabled != _enabled;
    final bool commandBaseChanged = nextCommandBase != _commandBase;
    final bool ipChanged = nextIp != _ipController.text;
    final bool portChanged = nextPort != _portController.text;
    final bool openCmdChanged = nextOpenCmd != _openCmdController.text;
    final bool closeCmdChanged = nextCloseCmd != _closeCmdController.text;
    final bool queryChanged = nextQueryCmd != _queryController.text;

    if (!enabledChanged &&
        !commandBaseChanged &&
        !ipChanged &&
        !portChanged &&
        !openCmdChanged &&
        !closeCmdChanged &&
        !queryChanged) {
      return;
    }

    _syncing = true;
    if (enabledChanged || commandBaseChanged) {
      setState(() {
        if (enabledChanged) {
          _enabled = widget.enabled;
        }
        if (commandBaseChanged) {
          _commandBase = nextCommandBase;
        }
      });
    }
    if (ipChanged) {
      _ipController.value = _ipController.value.copyWith(
        text: nextIp,
        selection: TextSelection.collapsed(offset: nextIp.length),
        composing: TextRange.empty,
      );
    }
    if (portChanged) {
      _portController.value = _portController.value.copyWith(
        text: nextPort,
        selection: TextSelection.collapsed(offset: nextPort.length),
        composing: TextRange.empty,
      );
    }
    if (openCmdChanged) {
      _openCmdController.value = _openCmdController.value.copyWith(
        text: nextOpenCmd,
        selection: TextSelection.collapsed(offset: nextOpenCmd.length),
        composing: TextRange.empty,
      );
    }
    if (closeCmdChanged) {
      _closeCmdController.value = _closeCmdController.value.copyWith(
        text: nextCloseCmd,
        selection: TextSelection.collapsed(offset: nextCloseCmd.length),
        composing: TextRange.empty,
      );
    }
    if (queryChanged) {
      _queryController.value = _queryController.value.copyWith(
        text: nextQueryCmd,
        selection: TextSelection.collapsed(offset: nextQueryCmd.length),
        composing: TextRange.empty,
      );
    }
    _syncing = false;
  }

  @override
  void dispose() {
    _emitDebounce?.cancel();
    _emitDebounce = null;
    _ipController.removeListener(_fieldsListener);
    _portController.removeListener(_fieldsListener);
    _openCmdController.removeListener(_fieldsListener);
    _closeCmdController.removeListener(_fieldsListener);
    _queryController.removeListener(_fieldsListener);
    _ipController.dispose();
    _portController.dispose();
    _openCmdController.dispose();
    _closeCmdController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }

  Widget _buildView() {
    final KeyValueModel<String> selectedCommandBase = _commandBaseOptions.firstWhere(
      (e) => int.tryParse(e.key) == _commandBase,
      orElse: () => _commandBaseOptions.last,
    );
    final Widget header = <Widget>[
      TextWidget.label(widget.title, fontSize: 36.sp, color: Colors.red), //名字
      
      DropdownWidget(
        items: _commandBaseOptions,
        selectedValue: selectedCommandBase,
        onChanged: _onCommandBaseChanged,
        fontSize: 24.sp,
        buttonHeight: 44.h,
        itemHeight: 40.h,
      ).width(180.w),

      ToggleWidget(
        firstIcon: ImageWidget.svg(AssetsSvgs.closeSvg),
        secondIcon: ImageWidget.svg(AssetsSvgs.openSvg),
        width: 90.w,
        height: 60.h,
        value: _enabled,
        onChanged: _onEnabledChanged,
      ),
    ].toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween);

    final Widget form = AbsorbPointer(
      absorbing: !_enabled,
      child: <Widget>[
        <Widget>[
          _buildInfoItem(
            'IP地址',
            controller: _ipController,
            placeholder: '请输入IP地址',
            readOnly: !_enabled,
          ),
          _buildInfoItem(
            '端口号',
            controller: _portController,
            placeholder: '请输入端口号',
            readOnly: !_enabled,
          ),
        ].toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween),
        <Widget>[
          _buildInfoItem(
            '开启指令',
            controller: _openCmdController,
            placeholder: '请输入开启指令',
            readOnly: !_enabled,
          ),
          _buildInfoItem(
            '关闭指令',
            controller: _closeCmdController,
            placeholder: '请输入关闭指令',
            readOnly: !_enabled,
          ),
          _buildInfoItem(
            '查询指令',
            controller: _queryController,
            placeholder: '请输入查询指令',
            readOnly: !_enabled,
          ),
        ].toRow(mainAxisAlignment: MainAxisAlignment.spaceBetween),
      ].toColumn(),
    );

    Widget content = <Widget>[
      header,
      form,
    ]
        .toColumn()
        .padding(
          vertical: 10.w,
          horizontal: 10.w,
        )
        .width(1700.w)
        .decorated(
          borderRadius: BorderRadius.circular(12.r),
          color: CustomAppColors.card,
          border: Border.all(
            color: CustomAppColors.text,
            width: 1.w,
          ),
        );

    if (!_enabled) {
      content = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: content,
      );
    }

    return AnimatedOpacity(
      opacity: _enabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 150),
      child: content,
    );
  }
 
  Widget _buildInfoItem(
    String label, {
    required TextEditingController controller,
    String? placeholder,
    bool readOnly = false,
  }) {
    return <Widget>[
        TextWidget.label('$label:', fontSize: 26.sp).constrained(width: 150.w),
        InputWidget(
          controller: controller,
          placeholder: placeholder,
          readOnly: readOnly,
          borderWidth: 2.w,
          focusBorderWidth: 2.w,
        ).expanded(),
      ].toRow(mainAxisAlignment: MainAxisAlignment.start).width(500.w); 
  }
}
