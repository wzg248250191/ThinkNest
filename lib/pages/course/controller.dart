import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'widgets/course_type.dart';
import '../../common/index.dart';

class CourseController extends GetxController {
  CourseController();

  final ScrollController scrollController = ScrollController();
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  //所有的课程
  late final List<String> types = courseType.keys.toList();
  late final List<GlobalKey> sectionKeys =
      List.generate(types.length, (index) => GlobalKey());
  int currentTypeIndex = 0;
  bool _navAnimating = false;
  bool get isNavAnimating => _navAnimating;
  late final List<GlobalKey> navItemKeys =
      List.generate(types.length, (index) => GlobalKey());
  late final List<GlobalKey> dotKeys =
      List.generate(types.length, (index) => GlobalKey());
  final GlobalKey navContainerKey = GlobalKey();
  double overlayCenterY = 0.0;
  int overlayIndex = 0;
  VoidCallback? _positionsCallback;
  bool _positionsListening = false;
  Timer? _settleTimer;
  bool _settling = false;
  List<double> navCenters = [];
  bool _navCentersReady = false;
  int navAnimDurationMs = 300;
  Map<String, List<String>> typeCourseNames = {};
  int _lastPositionsMs = 0;

  
  void _refreshAllNavCenters() {
    final navCtx = navContainerKey.currentContext;
    if (navCtx == null) return;
    final navBox = navCtx.findRenderObject() as RenderBox?;
    if (navBox == null) return;
    final navTop = navBox.localToGlobal(Offset.zero).dy;
    final centers = List<double>.filled(navItemKeys.length, 0);
    for (int i = 0; i < navItemKeys.length; i++) {
      final dotCtx = dotKeys[i].currentContext;
      final dotBox = dotCtx?.findRenderObject() as RenderBox?;
      if (dotBox == null) continue;
      final dotTop = dotBox.localToGlobal(Offset.zero).dy;
      final dotHeight = dotBox.size.height;
      centers[i] = dotTop - navTop + dotHeight / 2;
    }
    navCenters = centers;
    overlayCenterY = centers[overlayIndex];
    _navCentersReady = true;
    update(["course_nav_line","course_nav_overlay"]);
  }
  
  void _ensureNavCenters() {
    if (!_navCentersReady) {
      _refreshAllNavCenters();
    }
  }
  
  void _updateOverlayFromCenters() {
    _ensureNavCenters();
    if (overlayIndex >= 0 && overlayIndex < navCenters.length) {
      overlayCenterY = navCenters[overlayIndex];
      update(["course_nav_overlay"]);
    }
  }
  _initData() {
    update(["course"]);
  }

  void onTap() {}
  void _onPositionsChanged() {
    if (_navAnimating || _settling) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPositionsMs < 120) return;
    final positions = itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    int best = currentTypeIndex;
    double minLead = double.infinity;
    for (final p in positions) {
      if (p.itemLeadingEdge >= 0 && p.itemLeadingEdge < minLead) {
        minLead = p.itemLeadingEdge;
        best = p.index;
      }
    }
    if (best != currentTypeIndex && minLead <= 0.35) {
      currentTypeIndex = best;
      overlayIndex = best;
      update(["course_nav_name"]);
      _updateOverlayFromCenters();
    }
    _lastPositionsMs = now;
  }
  void _pausePositionsListening() {
    if (_positionsListening && _positionsCallback != null) {
      itemPositionsListener.itemPositions.removeListener(_positionsCallback!);
      _positionsListening = false;
    }
    _settleTimer?.cancel();
    _settling = false;
  }
  void _resumePositionsListening() {
    if (!_positionsListening && _positionsCallback != null) {
      itemPositionsListener.itemPositions.addListener(_positionsCallback!);
      _positionsListening = true;
    }
  }

  Future<void> scrollToSection(int index) async {
    if (index < 0 || index >= sectionKeys.length) return;
    _pausePositionsListening();
    if (!itemScrollController.isAttached) {
      overlayIndex = index;
      _updateOverlayFromCenters();
      navAnimDurationMs = 300;
      update(["course_nav_line","course_nav_overlay"]);
      const duration = Duration(milliseconds: 300);
      await Future.delayed(duration);
      currentTypeIndex = index;
      update(["course_nav_name"]);
      _settling = true;
      _settleTimer = Timer(const Duration(milliseconds: 180), () {
        _settling = false;
        _resumePositionsListening();
      });
      return;
    }
    if (_navAnimating) return;
    _navAnimating = true;
    
    // 【修复】在更新 currentTypeIndex 之前先计算滚动距离
    final int fromIndex = currentTypeIndex;
    final int distance = (index - fromIndex).abs();
    
    // 优化：减少预加载数量，避免瞬间主线程压力过大
    _precacheSectionImages(index, limit: 6);

    // 先立即更新导航状态，提升响应速度
    overlayIndex = index;
    currentTypeIndex = index;
    update(["course_nav_name"]);
    _updateOverlayFromCenters();
    
    // 优化策略：根据距离选择不同的滚动方式
    const int jumpThreshold = 2;
    
    if (distance > jumpThreshold) {
      // 大距离跳转：直接跳转，避免渲染中间所有 section
      navAnimDurationMs = 200;
      update(["course_nav_line","course_nav_overlay"]);
      
      // 直接跳转到目标
      itemScrollController.jumpTo(index: index, alignment: 0.0);
      
      // 等待目标 section 完成渲染（它会使用帧调度逐步加载）
      // 给多一些时间让首屏内容稳定
      await Future.delayed(const Duration(milliseconds: 120));
      
    } else {
      // 短距离：使用较快的滚动动画
      // 动画时间缩短，减少等待感
      final int durationMs = (80 * distance).clamp(150, 280);
      navAnimDurationMs = durationMs;
      update(["course_nav_line","course_nav_overlay"]);
      final duration = Duration(milliseconds: durationMs);
      
      // 使用更快的曲线
      itemScrollController.scrollTo(
        index: index,
        duration: duration,
        curve: Curves.easeOut,
        alignment: 0.0,
      );
      await Future.delayed(duration);
    }
    
    _navAnimating = false;
    _updateOverlayFromCenters();
    
    // 恢复监听的冷却时间
    const int cooldownMs = 150;
    _settling = true;
    _settleTimer = Timer(const Duration(milliseconds: cooldownMs), () {
      _settling = false;
      _resumePositionsListening();
    });
    
    // 预加载相邻 section 的图片
    Future.microtask(() {
      final prev = index - 1;
      final next = index + 1;
      if (prev >= 0) _precacheSectionImages(prev, limit: 4);
      if (next < types.length) _precacheSectionImages(next, limit: 4);
    });
  }

  void handleScroll() {
    int best = currentTypeIndex;
    double minDy = double.infinity;
    for (int i = 0; i < sectionKeys.length; i++) {
      final ctx = sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy >= 0 && dy < minDy) {
        minDy = dy;
        best = i;
      }
    }
    if (best != currentTypeIndex) {
      currentTypeIndex = best;
      overlayIndex = best;
      update(["course_nav_name"]);
      _updateOverlayFromCenters();
    }
  }

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  @override
  void onReady() {
    super.onReady();
    _initData();
    for (final t in types) {
      typeCourseNames[t] = coursesByName.entries.where((e) => e.value['type'] == t).map((e) => e.key).toList();
    }
    _positionsCallback = _onPositionsChanged;
    _resumePositionsListening();
    overlayIndex = currentTypeIndex;
    navCenters = List<double>.filled(types.length, 0);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshAllNavCenters());
  }

  // @override
  // void onClose() {
  //   super.onClose();
  // }
  @override
  void onClose() {
    scrollController.dispose();
    _pausePositionsListening();
    super.onClose();
  }

  void _precacheSectionImages(int index, {int limit = 12}) {
    final ctx = Get.context;
    if (ctx == null) return;
    final String t = types[index];
    final names = typeCourseNames[t] ?? [];
    if (names.isEmpty) return;
    final double dpr = MediaQuery.of(ctx).devicePixelRatio;
    final int w = (210 * dpr).round();
    final int h = (210 * dpr).round();
    final int count = limit.clamp(0, names.length);
    for (int i = 0; i < count; i++) {
      final provider = ResizeImage(AssetImage('assets/images/courses/${names[i]}.png'), width: w, height: h);
      precacheImage(provider, ctx);
    }
  }
}
