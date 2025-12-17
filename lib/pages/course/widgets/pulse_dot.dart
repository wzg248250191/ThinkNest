import 'package:flutter/material.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

///脉冲实心圆点(当前选择的点)
class PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  final bool enabled;
  const PulseDot({super.key, required this.size, required this.color, this.enabled = true});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _ctrl.repeat(reverse: true);
    }
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  void didUpdateWidget(covariant PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算一次，避免在 builder 中重复计算
    final maxDelta = 24.w;
    final rippleSize = widget.size + 2 * maxDelta;
    
    // 核心圆点部分保持不变
    final core = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
      ),
    );
    
    if (!widget.enabled) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: core,
      );
    }
    
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final v = _ctrl.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              child!, // 使用缓存的 child
              IgnorePointer(
                child: SizedBox(
                  width: rippleSize,
                  height: rippleSize,
                  child: CustomPaint(
                    painter: _RipplePainter(
                      color: widget.color,
                      progress: v,
                      coreSize: widget.size,
                      maxDelta: maxDelta,
                      rings: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: core, // 传递 child 避免每次重建
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double coreSize;
  final double maxDelta;
  final int rings;
  
  const _RipplePainter({
    required this.color,
    required this.progress,
    required this.coreSize,
    required this.maxDelta,
    required this.rings,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 1.2.w;
    
    // 预计算避免在循环中重复计算
    final coreSizeHalf = coreSize / 2;
    
    for (int i = 0; i < rings; i++) {
      final t = (progress + i / rings) % 1.0;
      final r = coreSizeHalf + maxDelta * t;
      final op = (1.0 - t).clamp(0.0, 1.0);
      
      // 创建 Paint 对象
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: op)
        ..isAntiAlias = true; // 启用抗锯齿
      
      canvas.drawCircle(center, r, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    // 只有 progress 变化时才重绘，其他属性应该保持不变
    return oldDelegate.progress != progress;
  }
  
  @override
  bool shouldRebuildSemantics(covariant _RipplePainter oldDelegate) => false;
}
