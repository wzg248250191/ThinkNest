import 'package:flutter/material.dart';

import 'button.dart';
import '../style/scale.dart';
import '../style/border.dart';
import '../style/radius.dart';

/// 点击后在两段文案之间切换的按钮组件
class SwitchButton extends StatefulWidget {
  /// 第一段文案（value=false 时展示）
  final String firstText;

  /// 第二段文案（value=true 时展示）
  final String secondText;

  /// 当前状态（传入则为受控组件；不传则内部自管理）
  final bool? value;

  /// 状态变化回调
  final ValueChanged<bool>? onChanged;

  /// 未选中态样式
  final ButtonWidgetVariant variantOff;

  /// 选中态样式
  final ButtonWidgetVariant variantOn;

  /// 按钮尺寸
  final WidgetScale scale;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 文本字号
  final double? fontSize;

  /// 圆角
  final double? borderRadius;

  /// 未选中态背景色（仅当 variantOff 支持时生效）
  final Color? backgroundColorOff;

  /// 选中态背景色（仅当 variantOn 支持时生效）
  final Color? backgroundColorOn;

  /// 未选中态文字颜色
  final Color? textColorOff;

  /// 选中态文字颜色
  final Color? textColorOn;

  /// 启用
  final bool enabled;

  /// 外层边框颜色（当所选 variant 非 outline 时生效）
  final Color? borderColor;

  const SwitchButton({
    super.key,
    required this.firstText,
    required this.secondText,
    this.value,
    this.onChanged,
    this.variantOff = ButtonWidgetVariant.ghost,
    this.variantOn = ButtonWidgetVariant.primary,
    this.scale = WidgetScale.medium,
    this.width,
    this.height,
    this.fontSize,
    this.borderRadius,
    this.backgroundColorOff,
    this.backgroundColorOn,
    this.textColorOff,
    this.textColorOn,
    this.enabled = true,
    this.borderColor,
  }) : assert(firstText != '' && secondText != '', '文案不能为空');

  @override
  /// 创建可切换按钮状态
  State<SwitchButton> createState() => _SwitchButtonState();
}

class _SwitchButtonState extends State<SwitchButton> {
  late bool _value = widget.value ?? false;

  @override
  /// 同步外部受控 value 到内部状态
  void didUpdateWidget(covariant SwitchButton oldWidget) {
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
  /// 构建可切换文案按钮
  Widget build(BuildContext context) {
    final bool current = widget.value ?? _value;
    final String text = current ? widget.secondText : widget.firstText;
    final bool isOutlineVariantCurrent =
        (current ? widget.variantOn : widget.variantOff) ==
            ButtonWidgetVariant.outline;

    final ButtonWidget child = ButtonWidget(
      variant: current ? widget.variantOn : widget.variantOff,
      scale: widget.scale,
      text: text,
      fontSize: widget.fontSize,
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius,
      borderColor: isOutlineVariantCurrent ? widget.borderColor : null,
      backgroundColor:
          current ? widget.backgroundColorOn : widget.backgroundColorOff,
      textColor: current ? widget.textColorOn : widget.textColorOff,
      enabled: widget.enabled,
      onTap: widget.enabled ? _toggle : null,
    );

    final bool isOutlineVariant =
        (current ? widget.variantOn : widget.variantOff) ==
            ButtonWidgetVariant.outline;

    if (widget.borderColor != null && !isOutlineVariant) {
      final BorderRadius br =
          BorderRadius.circular(widget.borderRadius ?? AppRadius.button);
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: widget.borderColor!, width: AppBorder.button),
          borderRadius: br,
        ),
        child: ClipRRect(borderRadius: br, child: child),
      );
    }

    return child;
  }
}
