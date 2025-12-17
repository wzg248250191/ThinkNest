import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'widgets/course_type.dart';

class CourseController extends GetxController {
  CourseController();

  final ScrollController scrollController = ScrollController();
  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();
  late final List<String> types = courseType.keys.toList();
  late final List<GlobalKey> sectionKeys =
      List.generate(types.length, (index) => GlobalKey());
  int currentTypeIndex = 0;
  bool _navAnimating = false;
  bool get isNavAnimating => _navAnimating;
  late final List<GlobalKey> navItemKeys =
      List.generate(types.length, (index) => GlobalKey());
  final GlobalKey navContainerKey = GlobalKey();
  double overlayCenterY = 0.0;
  int overlayIndex = 0;
  VoidCallback? _positionsCallback;
  bool _positionsListening = false;
  late List<double> navCenters;
  bool _navCentersReady = false;
  int navAnimDurationMs = 300;

  void _refreshOverlayCenter() {
    final navCtx = navContainerKey.currentContext;
    if (navCtx == null) return;
    final currKey = navItemKeys[overlayIndex];
    final itemCtx = currKey.currentContext;
    if (itemCtx == null) return;
    final navBox = navCtx.findRenderObject() as RenderBox?;
    final itemBox = itemCtx.findRenderObject() as RenderBox?;
    if (navBox == null || itemBox == null) return;
    final navTop = navBox.localToGlobal(Offset.zero).dy;
    final itemTop = itemBox.localToGlobal(Offset.zero).dy;
    final itemHeight = itemBox.size.height;
    overlayCenterY = itemTop - navTop + itemHeight / 2;
    update(["course_nav_overlay"]);
  }

  void _refreshAllNavCenters() {
    final navCtx = navContainerKey.currentContext;
    if (navCtx == null) return;
    final navBox = navCtx.findRenderObject() as RenderBox?;
    if (navBox == null) return;
    final navTop = navBox.localToGlobal(Offset.zero).dy;
    final centers = List<double>.filled(navItemKeys.length, 0);
    for (int i = 0; i < navItemKeys.length; i++) {
      final itemCtx = navItemKeys[i].currentContext;
      final itemBox = itemCtx?.findRenderObject() as RenderBox?;
      if (itemBox == null) continue;
      final itemTop = itemBox.localToGlobal(Offset.zero).dy;
      final itemHeight = itemBox.size.height;
      centers[i] = itemTop - navTop + itemHeight / 2;
    }
    navCenters = centers;
    overlayCenterY = centers[overlayIndex];
    _navCentersReady = true;
    update(["course_nav_overlay"]);
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
    if (_navAnimating) return;
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
      update(["course_nav"]);
      _updateOverlayFromCenters();
    }
  }
  void _pausePositionsListening() {
    if (_positionsListening && _positionsCallback != null) {
      itemPositionsListener.itemPositions.removeListener(_positionsCallback!);
      _positionsListening = false;
    }
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
      update(["course_nav_overlay"]);
      const duration = Duration(milliseconds: 300);
      await Future.delayed(duration);
      currentTypeIndex = index;
      update(["course_nav"]);
      _resumePositionsListening();
      return;
    }
    if (_navAnimating) return;
    _navAnimating = true;
    
    // 计算滚动距离
    final distance = (index - currentTypeIndex).abs();
    
    // 先立即更新导航状态，提升响应速度
    overlayIndex = index;
    currentTypeIndex = index;
    update(["course_nav"]);
    _updateOverlayFromCenters();
    
    final int durationMs = (90 * distance).clamp(220, 450);
    navAnimDurationMs = durationMs;
    update(["course_nav_overlay"]);
    final duration = Duration(milliseconds: durationMs);
    itemScrollController.scrollTo(
      index: index,
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
    await Future.delayed(duration);
    
    _navAnimating = false;
    _updateOverlayFromCenters();
    _resumePositionsListening();
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
      update(["course_nav"]);
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
}
