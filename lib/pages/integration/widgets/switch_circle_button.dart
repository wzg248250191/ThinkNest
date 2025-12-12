import 'dart:math' as math;
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:think_nest/common/index.dart';
import '../models/switch_circle_state.dart';

class SwitchCircleButton extends StatelessWidget {
  final WidgetScale scale;
  final String name;
  final Widget? icon;
  final Widget Function(Color color)? iconBuilder;
  final bool enabled;
  final bool isOn;
  final SwitchCircleState? state;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? disabledColor;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onChanged;
  final ValueChanged<SwitchCircleState>? onStateChanged;
  final double? spacing;

  const SwitchCircleButton({
    super.key,
    this.scale = WidgetScale.medium,
    required this.name,
    this.icon,
    this.iconBuilder,
    this.enabled = true,
    this.isOn = false,
    this.state,
    this.size = 40,
    this.activeColor,
    this.inactiveColor,
    this.disabledColor,
    this.onTap,
    this.onChanged,
    this.onStateChanged,
    this.spacing,
  });

  double _size(double val) {
    switch (scale) {
      case WidgetScale.medium:
        return val;
      case WidgetScale.small:
        return val * (1 - 0.3);
      case WidgetScale.large:
        return val * (1 + 0.3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors.scheme;
    final Color active = activeColor ??  CustomAppColors.primary;
    final Color inactive = inactiveColor ?? const Color(0xFF9CA3AF);
    final Color disabledC = disabledColor ?? const Color(0xFFBDBDBD);

    final bool effectiveEnabled = state?.enabled ?? enabled;
    final bool effectiveIsOn = state?.isOn ?? isOn;
    final bool disabled = !effectiveEnabled;
    final Color borderColor = disabled
        ? disabledC
        : (effectiveIsOn ? active : inactive.withValues(alpha: 0.3));
    final double borderWidth = effectiveIsOn ? 3.0 : 1.5;
    final Color baseColor = disabled ? disabledC : (effectiveIsOn ? active : inactive);
    final Color iconColor = baseColor;
    final Color fillColor = disabled ? disabledC.withValues(alpha: 0.08) : scheme.surface;

    final double s = _size(size);
    final Widget iconWidget = iconBuilder != null
        ? iconBuilder!(iconColor)
        : (icon != null
            ? IconTheme.merge(
                data: IconThemeData(color: iconColor, size: s * 0.45),
                child: icon!,
              )
            : const SizedBox.shrink());

    Widget circle = SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: s,
            height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fillColor,
          ),
          ),
          Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
          ),
          iconWidget,
          if (disabled)
            Transform.rotate(
              angle: -math.pi / 4,
              child: Container(
                width: s * 1.1,
                height: 2,
                color: iconColor,
              ),
            ),
        ],
      ),
    );

    if (!disabled) {
      circle = GestureDetector(
        onTap: () {
          final bool nextOn = !effectiveIsOn;
          onChanged?.call(nextOn);
          final SwitchCircleState nextState = (state ?? SwitchCircleState(enabled: effectiveEnabled, isOn: effectiveIsOn))
              .copyWith(isOn: nextOn);
          onStateChanged?.call(nextState);
          onTap?.call();
        },
        child: circle,
      );
    }

    final double nameSpacing = spacing ?? _size(AppPadding.button.vertical) * 2;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        circle,
        SizedBox(height: nameSpacing),
        TextWidget.label(
          name,
          color: scheme.onSurfaceVariant,
          textAlign: TextAlign.center,
          size: 36.w,
        ),
      ],
    );

    content = AnimatedOpacity(
      opacity: disabled ? 0.6 : 1,
      duration: const Duration(milliseconds: 200),
      child: content,
    );

    return content;
  }
}

