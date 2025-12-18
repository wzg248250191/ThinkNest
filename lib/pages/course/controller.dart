import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'widgets/course_type.dart';
import '../../common/index.dart';

class CourseController extends GetxController {
  CourseController();

  /// 滚动控制器
  final ScrollController scrollController = ScrollController();
  
  /// 所有分类名称
  late final List<String> types = courseType.keys.toList();
  
  /// 每个分类对应的课程名称列表
  final Map<String, List<String>> typeCourseNames = {};
  
  /// 当前选中的分类索引
  int currentTypeIndex = 0;
  
  /// 是否正在执行导航跳转（防止滚动监听干扰）
  bool _isNavigating = false;
  
  /// 外部访问导航状态（用于控制脉冲动画）
  bool get isNavAnimating => _isNavigating;
  
  /// 每个分类标题的 GlobalKey（用于定位和跳转）
  late final List<GlobalKey> sectionKeys = List.generate(types.length, (_) => GlobalKey());
  
  /// 导航栏相关
  late final List<GlobalKey> dotKeys = List.generate(types.length, (_) => GlobalKey());
  final GlobalKey navContainerKey = GlobalKey();
  List<double> navCenters = [];
  double overlayCenterY = 0.0;
  int overlayIndex = 0;
  int navAnimDurationMs = 250;
  bool _navCentersReady = false;
  
  /// 滚动监听节流时间戳
  int _lastScrollMs = 0;

  // ============ 布局常量（供 view.dart 使用）============
  static const int crossAxisCount = 5;
  static double get crossAxisSpacing => 46.w;
  static double get mainAxisSpacing => 46.h;
  static double get listPaddingTop => 50.h;
  static double get listPaddingHorizontal => 40.w;

  @override
  void onReady() {
    super.onReady();
    _initData();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAllNavCenters();
      // 🚀 页面渲染完成后，后台预缓存所有分类的首屏图片
      _precacheAllSectionsInBackground();
    });
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  void _initData() {
    for (final t in types) {
      typeCourseNames[t] = coursesByName.entries
          .where((e) => e.value['type'] == t)
          .map((e) => e.key)
          .toList();
    }
    update(["course"]);
  }

  /// 滚动监听 - 更新当前分类高亮（带节流）
  void _onScroll() {
    if (_isNavigating) return;
    
    // 节流：每 80ms 最多执行一次
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollMs < 80) return;
    _lastScrollMs = now;
    
    // 通过 GlobalKey 判断哪个分类标题最接近顶部
    int newIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < sectionKeys.length; i++) {
      final ctx = sectionKeys[i].currentContext;
      if (ctx == null) continue;
      
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      
      // 获取标题相对于屏幕顶部的距离
      final dy = box.localToGlobal(Offset.zero).dy;
      
      // 找到最接近顶部（但不超过太多）的分类
      if (dy <= 150 && dy > -100) {
        if (dy.abs() < minDistance) {
          minDistance = dy.abs();
          newIndex = i;
        }
      } else if (dy < 0 && dy > -500) {
        // 已经滚过去的分类
        newIndex = i;
      }
    }
    
    if (newIndex != currentTypeIndex) {
      currentTypeIndex = newIndex;
      overlayIndex = newIndex;
      update(["course_nav_name"]);
      _updateOverlayFromCenters();
    }
  }

  /// 点击导航滚动到指定分类
  void scrollToSection(int index) {
    if (index < 0 || index >= types.length) return;
    if (_isNavigating) return;
    
    _isNavigating = true;
    
    // 计算分类间隔距离
    final distance = (index - currentTypeIndex).abs();
    
    // 根据距离动态计算动画时长：基础 200ms + 每隔一个分类增加 80ms
    final durationMs = 300/*(200 + distance * 80).clamp(200, 600)*/;
    
    // 立即更新导航状态（让用户看到响应）
    currentTypeIndex = index;
    overlayIndex = index;
    navAnimDurationMs = durationMs;
    update(["course_nav_name"]);
    _updateOverlayFromCenters();
    
    _precacheSectionImages(index);
    final object = sectionKeys[index].currentContext?.findRenderObject();
    double? targetOffset;
    if (object != null) {
      final viewport = RenderAbstractViewport.of(object);
      targetOffset = viewport.getOffsetToReveal(object, 0.0).offset;
    }
    Future.delayed(const Duration(milliseconds: 16), () {
      if (!scrollController.hasClients) return;
      final offset = targetOffset;
      if (offset == null) return;
      final pos = scrollController.position;
      scrollController.animateTo(
        offset.clamp(pos.minScrollExtent, pos.maxScrollExtent),
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOutCubic,
      );
    });

    Future.delayed(Duration(milliseconds: durationMs + 80), () {
      _isNavigating = false;
      update(["course_nav_overlay"]);
      _precacheAdjacentSections(index);
    });
  }
  
  /// 预缓存指定分类的课程图片（返回 Future 可等待完成）
  Future<void> _precacheSectionImages(int index, {bool wait = false}) async {
    final ctx = Get.context;
    if (ctx == null) return;
    
    final typeName = types[index];
    final courses = typeCourseNames[typeName] ?? [];
    
    // 只预缓存前 10 张图片（首屏可见的）
    final count = courses.length.clamp(0, 10);
    final futures = <Future>[];
    
    for (int i = 0; i < count; i++) {
      final imgPath = 'assets/images/courses/${courses[i]}.png';
      final future = precacheImage(AssetImage(imgPath), ctx);
      if (wait) futures.add(future);
    }
    
    // 如果需要等待，则等待所有图片加载完成
    if (wait && futures.isNotEmpty) {
      await Future.wait(futures).timeout(
        const Duration(milliseconds: 300), // 最多等 300ms
        onTimeout: () => [], // 超时则不等了
      );
    }
  }
  
  /// 预缓存相邻分类的图片
  void _precacheAdjacentSections(int index) {
    // 使用 Future.microtask 避免阻塞当前帧
    Future.microtask(() {
      if (index > 0) _precacheSectionImages(index - 1);
      if (index < types.length - 1) _precacheSectionImages(index + 1);
    });
  }
  
  /// 🚀 后台预缓存所有分类的首屏图片（页面初始化时调用）
  void _precacheAllSectionsInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _precacheAllSectionsStep(0);
    });
  }

  void _precacheAllSectionsStep(int index) {
    if (!scrollController.hasClients) return;
    if (index < 0 || index >= types.length) return;
    final ctx = Get.context;
    if (ctx == null) return;

    final typeName = types[index];
    final courses = typeCourseNames[typeName] ?? [];
    _precacheCourses(ctx, courses);

    Future.delayed(const Duration(milliseconds: 16), () {
      _precacheAllSectionsStep(index + 1);
    });
  }

  void _precacheCourses(BuildContext ctx, List<String> courses) {
    final count = courses.length.clamp(0, 10);
    for (int i = 0; i < count; i++) {
      final imgPath = 'assets/images/courses/${courses[i]}.png';
      precacheImage(AssetImage(imgPath), ctx);
    }
  }

  // ============ 导航栏辅助方法 ============
  
  void _refreshAllNavCenters() {
    final navCtx = navContainerKey.currentContext;
    if (navCtx == null) return;
    final navBox = navCtx.findRenderObject() as RenderBox?;
    if (navBox == null) return;
    final navTop = navBox.localToGlobal(Offset.zero).dy;
    
    final centers = List<double>.filled(dotKeys.length, 0);
    for (int i = 0; i < dotKeys.length; i++) {
      final dotCtx = dotKeys[i].currentContext;
      final dotBox = dotCtx?.findRenderObject() as RenderBox?;
      if (dotBox == null) continue;
      final dotTop = dotBox.localToGlobal(Offset.zero).dy;
      final dotHeight = dotBox.size.height;
      centers[i] = dotTop - navTop + dotHeight / 2;
    }
    navCenters = centers;
    overlayCenterY = centers.isNotEmpty ? centers[overlayIndex] : 0;
    _navCentersReady = true;
    update(["course_nav_line", "course_nav_overlay"]);
  }
  
  void _updateOverlayFromCenters() {
    if (!_navCentersReady) {
      _refreshAllNavCenters();
    }
    if (overlayIndex >= 0 && overlayIndex < navCenters.length) {
      overlayCenterY = navCenters[overlayIndex];
      update(["course_nav_overlay"]);
    }
  }
}
