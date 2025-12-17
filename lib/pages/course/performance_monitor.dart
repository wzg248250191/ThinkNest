import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';

/// 性能监控工具 - 用于开发环境查看性能指标
/// 
/// 使用方法：
/// ```dart
/// // 在开发环境中启用
/// if (kDebugMode) {
///   PerformanceMonitor.enable();
/// }
/// 
/// // 在页面中显示性能叠加层
/// Stack(
///   children: [
///     YourPage(),
///     PerformanceOverlay(),
///   ],
/// )
/// ```
class PerformanceMonitor {
  static bool _enabled = false;
  static final List<Duration> _frameTimes = [];
  static int _rebuildCount = 0;
  static int _repaintCount = 0;
  
  /// 启用性能监控
  static void enable() {
    if (_enabled) return;
    _enabled = true;
    
    SchedulerBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        final frameTime = timing.totalSpan;
        _frameTimes.add(frameTime);
        
        // 只保留最近 60 帧的数据
        if (_frameTimes.length > 60) {
          _frameTimes.removeAt(0);
        }
      }
    });
    
    debugPrint('性能监控已启用');
  }
  
  /// 禁用性能监控
  static void disable() {
    _enabled = false;
    _frameTimes.clear();
    debugPrint('性能监控已禁用');
  }
  
  /// 记录 Widget 重建
  static void recordRebuild() {
    if (!_enabled) return;
    _rebuildCount++;
  }
  
  /// 记录重绘
  static void recordRepaint() {
    if (!_enabled) return;
    _repaintCount++;
  }
  
  /// 重置计数器
  static void resetCounters() {
    _rebuildCount = 0;
    _repaintCount = 0;
  }
  
  /// 获取平均帧时间（毫秒）
  static double get averageFrameTime {
    if (_frameTimes.isEmpty) return 0;
    final sum = _frameTimes.fold<int>(0, (prev, curr) => prev + curr.inMicroseconds);
    return sum / _frameTimes.length / 1000;
  }
  
  /// 获取当前 FPS
  static double get currentFps {
    if (_frameTimes.isEmpty) return 0;
    final avgMs = averageFrameTime;
    if (avgMs == 0) return 0;
    return 1000 / avgMs;
  }
  
  /// 获取最差帧时间（毫秒）
  static double get worstFrameTime {
    if (_frameTimes.isEmpty) return 0;
    return _frameTimes.map((e) => e.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;
  }
  
  /// 获取重建次数
  static int get rebuildCount => _rebuildCount;
  
  /// 获取重绘次数
  static int get repaintCount => _repaintCount;
  
  /// 是否已启用
  static bool get enabled => _enabled;
}

/// 性能监控叠加层 - 显示实时性能数据
class PerformanceOverlay extends StatefulWidget {
  const PerformanceOverlay({super.key});
  
  @override
  State<PerformanceOverlay> createState() => _PerformanceOverlayState();
}

class _PerformanceOverlayState extends State<PerformanceOverlay> {
  bool _visible = true;
  
  @override
  void initState() {
    super.initState();
    // 每秒更新一次
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {});
      }
      return mounted;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    if (!PerformanceMonitor.enabled || !_visible) {
      return const SizedBox.shrink();
    }
    
    final fps = PerformanceMonitor.currentFps;
    final avgTime = PerformanceMonitor.averageFrameTime;
    final worstTime = PerformanceMonitor.worstFrameTime;
    final rebuilds = PerformanceMonitor.rebuildCount;
    final repaints = PerformanceMonitor.repaintCount;
    
    // 根据 FPS 显示不同颜色
    Color fpsColor;
    if (fps >= 58) {
      fpsColor = Colors.green;
    } else if (fps >= 45) {
      fpsColor = Colors.orange;
    } else {
      fpsColor = Colors.red;
    }
    
    return Positioned(
      top: 100.h,
      right: 20.w,
      child: GestureDetector(
        onDoubleTap: () {
          setState(() {
            _visible = false;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _visible = true;
              });
            }
          });
        },
        onLongPress: () {
          PerformanceMonitor.resetCounters();
          setState(() {});
        },
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8.w),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTitle('性能监控'),
              SizedBox(height: 8.h),
              _buildMetric('FPS', fps.toStringAsFixed(1), fpsColor),
              _buildMetric('平均帧时间', '${avgTime.toStringAsFixed(2)}ms', Colors.white70),
              _buildMetric('最差帧时间', '${worstTime.toStringAsFixed(2)}ms', Colors.white70),
              _buildMetric('重建次数', '$rebuilds', Colors.blue),
              _buildMetric('重绘次数', '$repaints', Colors.purple),
              SizedBox(height: 8.h),
              _buildHint(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildMetric(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHint() {
    return Text(
      '双击隐藏 | 长按重置',
      style: TextStyle(
        color: Colors.white38,
        fontSize: 10.sp,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

/// 性能监控的 Widget 包装器
/// 自动记录重建次数
class PerformanceTracker extends StatelessWidget {
  const PerformanceTracker({
    super.key,
    required this.child,
    this.name = 'Widget',
    this.enabled = true,
  });
  
  final Widget child;
  final String name;
  final bool enabled;
  
  @override
  Widget build(BuildContext context) {
    if (enabled && PerformanceMonitor.enabled) {
      PerformanceMonitor.recordRebuild();
      debugPrint('[$name] 重建');
    }
    return child;
  }
}

/// 性能监控的 RepaintBoundary 包装器
/// 自动记录重绘次数
class TrackedRepaintBoundary extends StatelessWidget {
  const TrackedRepaintBoundary({
    super.key,
    required this.child,
    this.name = 'Boundary',
    this.enabled = true,
  });
  
  final Widget child;
  final String name;
  final bool enabled;
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _RepaintTracker(
        name: name,
        enabled: enabled,
        child: child,
      ),
    );
  }
}

class _RepaintTracker extends SingleChildRenderObjectWidget {
  const _RepaintTracker({
    required this.name,
    required this.enabled,
    required Widget child,
  }) : super(child: child);
  
  final String name;
  final bool enabled;
  
  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderRepaintTracker(name: name, enabled: enabled);
  }
  
  @override
  void updateRenderObject(BuildContext context, covariant _RenderRepaintTracker renderObject) {
    renderObject
      ..name = name
      ..enabled = enabled;
  }
}

class _RenderRepaintTracker extends RenderProxyBox {
  _RenderRepaintTracker({
    required String name,
    required bool enabled,
    RenderBox? child,
  })  : _name = name,
        _enabled = enabled,
        super(child);
  
  String _name;
  String get name => _name;
  set name(String value) {
    if (_name == value) return;
    _name = value;
    markNeedsPaint();
  }
  
  bool _enabled;
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
  }
  
  @override
  void paint(PaintingContext context, Offset offset) {
    if (_enabled && PerformanceMonitor.enabled) {
      PerformanceMonitor.recordRepaint();
      debugPrint('[$_name] 重绘');
    }
    super.paint(context, offset);
  }
}

