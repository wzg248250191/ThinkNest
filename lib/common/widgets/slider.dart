import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../style/theme.dart';
import '../values/svgs.dart';

class SliderWidget extends StatefulWidget {
  const SliderWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = CustomAppColors.primary,
    this.inactiveColor = CustomAppColors.border,
    this.trackHeight = 2.0,
    this.thumbRadius = 10.0,
    this.width,
    this.enabled = true,
    this.showValueOnLongPress = false,
    this.longPressOverlaySize = const Size(44, 32),
    this.longPressOverlaySpacing = -5.0,
  }) : assert(max > min, 'max 必须大于 min');

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;
  final int? divisions;
  final ValueChanged<int>? onChangeStart;
  final ValueChanged<int>? onChangeEnd;

  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;
  final double thumbRadius;
  final double? width;
  final bool enabled;

  final bool showValueOnLongPress;
  final Size longPressOverlaySize;
  final double longPressOverlaySpacing;

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  OverlayEntry? _overlayEntry;
  double _overlayThumbCenterX = 0.0;
  int _overlayValue = 0;
  bool _longPressActive = false;
  bool _overlayRebuildScheduled = false;
  bool _pointerOverlayActive = false;
  bool _dragActive = false;

  bool _isThumbHit({
    required Offset localPosition,
    required double thumbCenterX,
    required double minHeight,
  }) {
    final Offset c = Offset(thumbCenterX, minHeight / 2);
    final double dx = localPosition.dx - c.dx;
    final double dy = localPosition.dy - c.dy;
    final double r = (widget.thumbRadius * 2.2).clamp(18.0, 44.0);
    return (dx * dx + dy * dy) <= r * r;
  }

  void _showOverlay({
    required double thumbCenterX,
    required int value,
  }) {
    if (!widget.enabled || !widget.showValueOnLongPress) {
      return;
    }
    _overlayThumbCenterX = thumbCenterX;
    _overlayValue = value;

    if (_overlayEntry != null) {
      _scheduleOverlayRebuild();
      return;
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    _overlayEntry = OverlayEntry(
      builder: (_) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) {
          return const SizedBox.shrink();
        }

        final double overlayW = widget.longPressOverlaySize.width;
        final double overlayH = widget.longPressOverlaySize.height;
        final Offset topLeft = box.localToGlobal(
          Offset(
            _overlayThumbCenterX - overlayW / 2,
            -overlayH - widget.longPressOverlaySpacing,
          ),
        );

        final Size screen = MediaQuery.of(context).size;
        final double left = topLeft.dx.clamp(0.0, (screen.width - overlayW).clamp(0.0, screen.width));
        final double top = topLeft.dy.clamp(0.0, (screen.height - overlayH).clamp(0.0, screen.height));

        return Positioned(
          left: left,
          top: top,
          width: overlayW,
          height: overlayH,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                AssetsSvgs.volumeBgSvg,
                width: overlayW,
                height: overlayH,
                fit: BoxFit.contain,
              ),
              Text(
                '$_overlayValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _scheduleOverlayRebuild() {
    if (_overlayEntry == null || _overlayRebuildScheduled) {
      return;
    }
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay({
    required double thumbCenterX,
    required int value,
  }) {
    if (_overlayEntry == null) {
      return;
    }
    _overlayThumbCenterX = thumbCenterX;
    _overlayValue = value;
    _scheduleOverlayRebuild();
  }

  int _clampValue(int value) => value.clamp(widget.min, widget.max);

  int _snapValue(int value) {
    final int v = _clampValue(value);
    final int divisions = widget.divisions ?? (widget.max - widget.min);
    if (divisions <= 0) {
      return v;
    }
    final int range = widget.max - widget.min;
    if (range <= 0) {
      return _clampValue(widget.min);
    }
    final double step = range / divisions;
    final double raw = (v - widget.min) / step;
    final int snapped = (widget.min + raw.round() * step).round();
    return _clampValue(snapped);
  }

  int _valueFromDx({
    required double dx,
    required double trackWidth,
  }) {
    final int range = widget.max - widget.min;
    if (range <= 0 || trackWidth <= 0) {
      return _clampValue(widget.min);
    }
    final double ratio = (dx / trackWidth).clamp(0.0, 1.0);
    final int raw = (widget.min + ratio * range).round();
    return _snapValue(raw);
  }

  int _valueFromLocalPosition({
    required Offset localPosition,
    required double trackWidth,
  }) {
    final double dx =
        (localPosition.dx - widget.thumbRadius).clamp(0.0, trackWidth);
    return _valueFromDx(dx: dx, trackWidth: trackWidth);
  }

  double _thumbCenterXForValue({
    required int value,
    required double trackWidth,
  }) {
    final int v = _clampValue(value);
    final int range = widget.max - widget.min;
    final double ratio = range <= 0 ? 0.0 : (v - widget.min) / range;
    return widget.thumbRadius + ratio * trackWidth;
  }

  int _updateValueFromPosition({
    required Offset localPosition,
    required double trackWidth,
  }) {
    final int next =
        _valueFromLocalPosition(localPosition: localPosition, trackWidth: trackWidth);
    widget.onChanged?.call(next);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final int clamped = _clampValue(widget.value);
    final double minHeight =
        (widget.thumbRadius * 2).clamp(widget.trackHeight, double.infinity);

    Widget body = LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (widget.width ?? 0);
        final double trackWidth = (w - widget.thumbRadius * 2).clamp(0.0, double.infinity);
        final int range = widget.max - widget.min;
        final double ratio = range <= 0 ? 0.0 : (clamped - widget.min) / range;
        final double thumbCenterX = widget.thumbRadius + ratio * trackWidth;

        if (widget.showValueOnLongPress && _overlayEntry != null) {
          _overlayThumbCenterX = thumbCenterX;
          _overlayValue = clamped;
          _scheduleOverlayRebuild();
        }

        final Widget track = SizedBox(
          height: minHeight,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.trackHeight / 2),
              child: SizedBox(
                height: widget.trackHeight,
                width: w,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: widget.inactiveColor),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: thumbCenterX,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: widget.activeColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final Widget thumb = Positioned(
          left: thumbCenterX - widget.thumbRadius,
          top: (minHeight - widget.thumbRadius * 2) / 2,
          width: widget.thumbRadius * 2,
          height: widget.thumbRadius * 2,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (d) {
                  if (widget.showValueOnLongPress &&
                      _isThumbHit(
                        localPosition: d.localPosition,
                        thumbCenterX: thumbCenterX,
                        minHeight: minHeight,
                      )) {
                    return;
                  }
                  final int next = _updateValueFromPosition(
                    localPosition: d.localPosition,
                    trackWidth: trackWidth,
                  );
                  widget.onChangeEnd?.call(_clampValue(next));
                  final double nextThumbCenterX = _thumbCenterXForValue(
                    value: next,
                    trackWidth: trackWidth,
                  );
                  _updateOverlay(
                    thumbCenterX: nextThumbCenterX,
                    value: _clampValue(next),
                  );
                }
              : null,
          onPanStart: widget.enabled
              ? (d) {
                  _dragActive = true;
                  if (widget.showValueOnLongPress) {
                    _pointerOverlayActive = true;
                    _showOverlay(
                      thumbCenterX: thumbCenterX,
                      value: clamped,
                    );
                  }
                  widget.onChangeStart?.call(clamped);
                  final int next = _valueFromLocalPosition(
                    localPosition: d.localPosition,
                    trackWidth: trackWidth,
                  );
                  widget.onChanged?.call(next);
                  if (widget.showValueOnLongPress) {
                    final double nextThumbCenterX = _thumbCenterXForValue(
                      value: next,
                      trackWidth: trackWidth,
                    );
                    _showOverlay(thumbCenterX: nextThumbCenterX, value: next);
                  }
                }
              : null,
          onPanUpdate: widget.enabled
              ? (d) {
                  final int next = _valueFromLocalPosition(
                    localPosition: d.localPosition,
                    trackWidth: trackWidth,
                  );
                  widget.onChanged?.call(next);
                  if (widget.showValueOnLongPress &&
                      (_pointerOverlayActive || _longPressActive)) {
                    final double nextThumbCenterX = _thumbCenterXForValue(
                      value: next,
                      trackWidth: trackWidth,
                    );
                    _showOverlay(thumbCenterX: nextThumbCenterX, value: next);
                  }
                }
              : null,
          onPanEnd: widget.enabled
              ? (_) {
                  _dragActive = false;
                  _pointerOverlayActive = false;
                  widget.onChangeEnd?.call(_clampValue(widget.value));
                  if (!_longPressActive) {
                    _hideOverlay();
                  }
                }
              : null,
          onLongPressStart: widget.enabled && widget.showValueOnLongPress
              ? (d) {
                  if (!mounted) {
                    return;
                  }
                  if (!_isThumbHit(
                    localPosition: d.localPosition,
                    thumbCenterX: thumbCenterX,
                    minHeight: minHeight,
                  )) {
                    return;
                  }
                  _longPressActive = true;
                  _showOverlay(
                    thumbCenterX: thumbCenterX,
                    value: clamped,
                  );
                }
              : null,
          onLongPressMoveUpdate: widget.enabled && widget.showValueOnLongPress
              ? (d) {
                  if (!_longPressActive) {
                    return;
                  }
                  final double dx = (d.localPosition.dx - widget.thumbRadius)
                      .clamp(0.0, trackWidth);
                  final int next = _valueFromDx(dx: dx, trackWidth: trackWidth);
                  widget.onChanged?.call(next);

                  final int nextRange = widget.max - widget.min;
                  final double nextRatio = nextRange <= 0
                      ? 0.0
                      : (next - widget.min) / nextRange;
                  final double nextThumbCenterX =
                      widget.thumbRadius + nextRatio * trackWidth;
                  _showOverlay(thumbCenterX: nextThumbCenterX, value: next);
                }
              : null,
          onLongPressEnd: widget.enabled && widget.showValueOnLongPress
              ? (_) {
                  _longPressActive = false;
                  _hideOverlay();
                }
              : null,
          onLongPressCancel: widget.enabled && widget.showValueOnLongPress
              ? () {
                  _longPressActive = false;
                  _hideOverlay();
                }
              : null,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.5,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                track,
                thumb,
              ],
            ),
          ),
        );
      },
    );

    if (widget.width != null) {
      body = SizedBox(width: widget.width, height: minHeight, child: body);
    } else {
      body = SizedBox(height: minHeight, child: body);
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.enabled && widget.showValueOnLongPress
          ? (e) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) {
                return;
              }
              final double w = widget.width ?? box.size.width;
              final double trackWidth =
                  (w - widget.thumbRadius * 2).clamp(0.0, double.infinity);
              final int v = _clampValue(widget.value);
              final int range = widget.max - widget.min;
              final double ratio = range <= 0 ? 0.0 : (v - widget.min) / range;
              final double thumbCenterX = widget.thumbRadius + ratio * trackWidth;
              _pointerOverlayActive = true;
              _showOverlay(thumbCenterX: thumbCenterX, value: v);
            }
          : null,
      onPointerUp: widget.enabled && widget.showValueOnLongPress
          ? (_) {
              if (_pointerOverlayActive && !_longPressActive && !_dragActive) {
                _pointerOverlayActive = false;
                _hideOverlay();
              }
            }
          : null,
      onPointerCancel: widget.enabled && widget.showValueOnLongPress
          ? (_) {
              _pointerOverlayActive = false;
              if (!_longPressActive && !_dragActive) {
                _hideOverlay();
              }
            }
          : null,
      child: body,
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }
}
