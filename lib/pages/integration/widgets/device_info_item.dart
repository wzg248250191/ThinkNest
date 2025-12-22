import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../common/index.dart';

class DeviceInfoItem extends StatefulWidget {
  const DeviceInfoItem({
    super.key,
    required this.title,
    this.enabled = true,
    this.ip,
    this.port,
    this.openCmd,
    this.closeCmd,
    this.queryCmd,
  });
  
  final String title;//名字
  final bool enabled;//是否启用
  final String? ip;//ip地址
  final String? port;//端口号
  final String? openCmd;//打开指令
  final String? closeCmd;//关闭指令  
  final String? queryCmd;//查询指令

  @override
  State<DeviceInfoItem> createState() => _DeviceInfoItemState();
}

class _DeviceInfoItemState extends State<DeviceInfoItem> {
  late bool _enabled;
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _openCmdController;
  late final TextEditingController _closeCmdController;
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _ipController = TextEditingController(text: widget.ip ?? '');
    _portController = TextEditingController(text: widget.port ?? '');
    _openCmdController = TextEditingController(text: widget.openCmd ?? '');
    _closeCmdController = TextEditingController(text: widget.closeCmd ?? '');
    _queryController = TextEditingController(text: widget.queryCmd ?? '');
  }

  void _onEnabledChanged(bool value) {
    setState(() {
      _enabled = value;
    });
  }

  @override
  void dispose() {
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
    final Widget header = <Widget>[
      TextWidget.label(widget.title, fontSize: 36.sp, color: Colors.red), //名字
      Toggle(
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
