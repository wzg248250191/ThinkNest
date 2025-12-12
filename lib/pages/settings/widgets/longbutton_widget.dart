import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:think_nest/common/index.dart';

class LongbuttonWidget extends StatefulWidget {
  const LongbuttonWidget({
    super.key,
    this.icon,
    this.name,
    this.title,
    this.subIcon,
    this.onTap,
    this.scale = WidgetScale.medium,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.enabled = true,
    this.nameColor,
    this.titleColor,
  });

  final Widget? icon;
  final Widget? name;
  final Widget? title;
  final Widget? subIcon;
  final Function()? onTap;
  final WidgetScale scale;
  final double? width;
  final double? height;
  final double? borderRadius;
  final Color? backgroundColor;
  final bool enabled;
  final Color? nameColor;
  final Color? titleColor;

  @override
  State<LongbuttonWidget> createState() => _LongbuttonWidgetState();
}

class _LongbuttonWidgetState extends State<LongbuttonWidget> {
  bool pressed = false;

  double _size(double val) {
    switch (widget.scale) {
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
    final colorScheme = context.colors.scheme;

    final List<Widget> ws = [];
    if (widget.icon != null) {
      ws.add(widget.icon!.paddingLeft(90.w));
    }

    if (widget.name != null) {
      final double nameLeft = widget.icon != null ? 50.w : 90.w;
      ws.add(widget.name!.paddingLeft(nameLeft));
    }

    // 左侧内容结束后，使用 Expanded 将右侧区域推到最右侧
    ws.add(const SizedBox.shrink().expanded());
    if (widget.title != null) {
      ws.add(widget.title!);
      ws.add(SizedBox(width: 33.w));
    }

    if (widget.subIcon != null) {
      ws.add(widget.subIcon!.paddingRight(82.w));
    }

    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: ws,
    );

    child = child.alignment(Alignment.centerLeft);
    if (widget.height != null || widget.width != null) {
      child = child.constrained(width: widget.width, height: widget.height);
    }

    child = child.padding(
      vertical: _size(AppPadding.listTile.vertical),
      horizontal: 0,
    );

    child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled ? widget.onTap : null,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) {
            if (!widget.enabled) return Colors.transparent;
            if (states.contains(WidgetState.pressed)) {
              return colorScheme.onSurface.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          },
        ),
        onHighlightChanged: widget.enabled
            ? (val) => setState(() => pressed = val)
            : null,
        child: child.scale(all: pressed ? 0.98 : 1.0),
      ),
    );

    return child;
  }
}

