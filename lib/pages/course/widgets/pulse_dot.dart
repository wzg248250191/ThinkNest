import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

///脉冲实心圆点(当前选择的点)
class PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  final bool enabled;
  const PulseDot({super.key, required this.size, required this.color, this.enabled = false});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    }
  }
  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }
  @override
  void didUpdateWidget(covariant PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        final ctrl = _ctrl ??
            AnimationController(
              vsync: this,
              duration: const Duration(milliseconds: 900),
            );
        _ctrl = ctrl;
        ctrl.repeat(reverse: true);
      } else {
        _ctrl?.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxDelta = 8.w;
    final coreSize = widget.size * 0.7;
    final rippleSize = coreSize + 2 * maxDelta;
    final rippleStrokeWidth = 1.2.w;
    final staticProgress = 0.35;
    
    // 核心圆点部分保持不变
    final core = Container(
      width: coreSize,
      height: coreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
      ),
    );
    
    if (!widget.enabled) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IgnorePointer(
              child: SizedBox(
                width: rippleSize,
                height: rippleSize,
                child: CustomPaint(
                  painter: _RipplePainter(
                    color: widget.color,
                    progress: staticProgress,
                    coreSize: coreSize,
                    maxDelta: maxDelta,
                    rings: 3,
                    strokeWidth: rippleStrokeWidth,
                  ),
                ),
              ),
            ),
            core,
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _ctrl!,
      builder: (context, child) {
        final v = _ctrl!.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              child!,
              IgnorePointer(
                child: SizedBox(
                  width: rippleSize,
                  height: rippleSize,
                  child: CustomPaint(
                    painter: _RipplePainter(
                      color: widget.color,
                      progress: v,
                      coreSize: coreSize,
                      maxDelta: maxDelta,
                      rings: 3,
                      strokeWidth: rippleStrokeWidth,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: core,
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double coreSize;
  final double maxDelta;
  final int rings;
  final double strokeWidth;
  
  const _RipplePainter({
    required this.color,
    required this.progress,
    required this.coreSize,
    required this.maxDelta,
    required this.rings,
    required this.strokeWidth,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    final coreSizeHalf = coreSize / 2;
    
    for (int i = 0; i < rings; i++) {
      final t = (progress + i / rings) % 1.0;
      final r = coreSizeHalf + maxDelta * t;
      final op = (1.0 - t).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: op)
        ..isAntiAlias = true;
      canvas.drawCircle(center, r, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
  
  @override
  bool shouldRebuildSemantics(covariant _RipplePainter oldDelegate) => false;
}
