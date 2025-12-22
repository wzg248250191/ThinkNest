import 'package:flutter/material.dart';

/// 点击后在两个图标之间切换的按钮组件
class Toggle extends StatefulWidget {
  /// 第一种状态下展示的图标（value=false 时展示）
  final Widget firstIcon;

  /// 第二种状态下展示的图标（value=true 时展示）
  final Widget secondIcon;

  /// 当前状态（传入则为受控组件；不传则内部自管理）
  final bool? value;

  /// 状态变化回调
  final ValueChanged<bool>? onChanged;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 点击热区倍数：最终热区宽高 = (effectiveWidth * hitScale, effectiveHeight * hitScale)
  /// effectiveWidth/effectiveHeight 未传时默认 48
  final double hitScale;

  /// 未选中态图标颜色（通过 IconTheme 应用到图标）
  final Color? iconColorOff;

  /// 选中态图标颜色（通过 IconTheme 应用到图标）
  final Color? iconColorOn;

  /// 启用
  final bool enabled;

  const Toggle({
    super.key,
    required this.firstIcon,
    required this.secondIcon,
    this.value,
    this.onChanged,
    this.width,
    this.height,
    this.hitScale = 1.0,
    this.iconColorOff,
    this.iconColorOn,
    this.enabled = true,
  }) : assert(hitScale >= 1.0, 'hitScale 不能小于 1.0');

  @override
  /// 创建可切换按钮状态
  State<Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<Toggle> {
  late bool _value = widget.value ?? false;

  @override
  /// 同步外部受控 value 到内部状态
  void didUpdateWidget(covariant Toggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != oldWidget.value) {
      _value = widget.value!;
    }
  }

  /// 执行切换并通知外部
  void _toggle() {
    final bool current = widget.value ?? _value;
    final bool next = !current;

    if (widget.value == null) {
      setState(() => _value = next);
    }
    widget.onChanged?.call(next);
  }

  @override
  /// 构建可切换图标按钮
  Widget build(BuildContext context) {
    final bool current = widget.value ?? _value;
    final Widget icon = current ? widget.secondIcon : widget.firstIcon;
    final Color? iconColor = current ? widget.iconColorOn : widget.iconColorOff;
    final Widget themedIcon = iconColor == null
        ? icon
        : IconTheme.merge(data: IconThemeData(color: iconColor), child: icon);

    final Widget visual = (widget.width != null || widget.height != null)
        ? SizedBox(
            width: widget.width,
            height: widget.height,
            child: Center(child: themedIcon),
          )
        : themedIcon;

    final double baseWidth = widget.width ?? 48.0;
    final double baseHeight = widget.height ?? 48.0;
    final double minWidth = baseWidth * widget.hitScale;
    final double minHeight = baseHeight * widget.hitScale;

    final Widget hitBox = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: minHeight,
      ),
      child: Center(child: visual),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.enabled ? _toggle : null,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Opacity(
          opacity: widget.enabled ? 1.0 : 0.5,
          child: hitBox,
        ),
      ),
    );
  }
}
