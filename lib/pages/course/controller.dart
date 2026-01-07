import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'widgets/course_type.dart';
import '../../common/index.dart';

class CourseController extends GetxController {
  CourseController();

  SocketService get _socketService => Get.find<SocketService>();
  Storage get _storage => Storage();

  /// 本地缓存课程列表的 key（统一从 [StorageKeys] 取值）
  static const String _courseListCacheKey = StorageKeys.courseListCache;

  /// 滚动控制器
  final ScrollController scrollController = ScrollController();
  
  /// 所有分类名称
  late final List<String> types = courseType.keys.toList();
  
  /// 每个分类对应的课程名称列表
  final Map<String, List<String>> typeCourseNames = {};

  final Map<String, List<String>> _allCourseNamesByType = {};

  bool isCourseListLoading = true;

  Worker? _courseListWorker;
  Worker? _courseListLoadingWorker;
  
  /// 当前选中的分类索引
  int currentTypeIndex = 0;
  
  /// 是否正在执行导航跳转（防止滚动监听干扰）
  bool _isNavigating = false;
  
  /// 外部访问导航状态（用于控制脉冲动画）
  bool get isNavAnimating => _isNavigating;
  
  /// 每个分类标题的 GlobalKey（用于定位和跳转）
  late final List<GlobalKey> sectionKeys = List.generate(types.length, (_) => GlobalKey());
  
  /// 导航栏相关
  int navAnimDurationMs = 250;
  
  /// 滚动监听节流时间戳
  int _lastScrollMs = 0;

  // ============ 布局常量（供 view.dart 使用）============
  static const int crossAxisCount = 5;
  static double get crossAxisSpacing => 46.w;
  static double get mainAxisSpacing => 46.h;
  static double get listPaddingTop => 50.h;
  static double get listPaddingHorizontal => 40.w;

  @override
  /// 控制器初始化：构建本地课程索引，并尝试用缓存课程清单进行首屏回显
  void onInit() {
    super.onInit();
    _buildCourseIndex();
    _loadCachedCourseList();
  }

  @override
  void onReady() {
    super.onReady();
    _bindCourseList();
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCourseListLoading) {
        _precacheAllSectionsInBackground();
      }
    });
  }

  /// 基于静态 coursesByName 构建“分类 -> 课程名列表”的索引
  /// 用于在服务端课程清单到达时快速过滤，减少 UI 更新瞬间的计算量
  void _buildCourseIndex() {
    _allCourseNamesByType.clear();
    for (final t in types) {
      _allCourseNamesByType[t] = <String>[];
    }

    for (final entry in coursesByName.entries) {
      final name = entry.key;
      final type = entry.value['type'];
      if (type is! String) continue;
      final list = _allCourseNamesByType[type];
      if (list == null) continue;
      list.add(name);
    }
  }

  /// 读取本地缓存的课程清单，并用于首屏显示（不阻塞后续服务端同步）
  void _loadCachedCourseList() {
    final cached = _storage.getList(_courseListCacheKey);
    if (cached.isEmpty) {
      return;
    }
    _applyCourseList(cached);
  }

  @override
  void onClose() {
    _courseListWorker?.dispose();
    _courseListLoadingWorker?.dispose();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }

  /// 绑定 SocketService 的课程清单状态，并驱动课程列表显示与加载态
  void _bindCourseList() {
    isCourseListLoading = _socketService.isCourseListLoading.value;
    if (!isCourseListLoading) {
      _applyCourseList(_socketService.courseList);
    }

    _courseListWorker = ever<List<String>>(_socketService.courseList, (list) {
      if (_socketService.isCourseListLoading.value) {
        return;
      }
      _applyCourseList(list);
    });

    _courseListLoadingWorker = ever<bool>(_socketService.isCourseListLoading, (loading) {
      isCourseListLoading = loading;
      if (loading) {
        update(["course"]);
        return;
      }
      _applyCourseList(_socketService.courseList);
    });
  }

  /// 将服务端返回的课程清单映射到本地 coursesByName，并按分类生成展示列表
  /// 说明：
  /// - 只展示服务端允许的课程
  /// - 更新后触发导航定位刷新，并预缓存当前/相邻分类的首屏图片，减少首次显示与切换卡顿
  void _applyCourseList(List<String> serverCourseList) {
    final allowed = serverCourseList.where(coursesByName.containsKey).toSet();

    for (final t in types) {
      final all = _allCourseNamesByType[t] ?? const <String>[];
      typeCourseNames[t] = <String>[
        for (final name in all)
          if (allowed.contains(name)) name,
      ];
    }

    update(["course"]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheSectionImages(currentTypeIndex);
      _precacheAdjacentSections(currentTypeIndex);
      _precacheAllSectionsInBackground();
    });
  }

  /// 滚动监听 - 更新当前分类高亮（带节流）
  void _onScroll() {
    if (_isNavigating) return;
    if (!scrollController.hasClients) return;
    
    // 节流：每 80ms 最多执行一次
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastScrollMs < 80) return;
    _lastScrollMs = now;
    
    // 通过 RenderAbstractViewport 计算“标题对应的滚动偏移”，避免使用 localToGlobal
    // 造成在居中布局/嵌套 Stack 场景下判断不准的问题。
    final current = scrollController.position.pixels;
    final target = current + 150.0;
    int newIndex = 0;
    double bestOffset = double.negativeInfinity;

    for (int i = 0; i < sectionKeys.length; i++) {
      final object = sectionKeys[i].currentContext?.findRenderObject();
      if (object == null) continue;
      final viewport = RenderAbstractViewport.of(object);

      final offset = viewport.getOffsetToReveal(object, 0.0).offset;
      if (offset <= target && offset >= bestOffset) {
        bestOffset = offset;
        newIndex = i;
      }
    }
    
    if (newIndex != currentTypeIndex) {
      final delta = (newIndex - currentTypeIndex).abs();
      navAnimDurationMs = (140 + delta * 70).clamp(140, 520);
      currentTypeIndex = newIndex;
      update(["course_nav_name"]);
      update(["course_nav_overlay"]);
    }
  }

  /// 点击导航滚动到指定分类
  /// 说明：
  /// - 立即更新导航高亮，再执行滚动动画，让交互更跟手
  /// - 滚动前预缓存目标分类首屏图片，降低滚动到位时的图片解码卡顿
  void scrollToSection(int index) {
    if (index < 0 || index >= types.length) return;
    if (_isNavigating) return;
    
    _isNavigating = true;
    
    // 计算分类间隔距离
    final distance = (index - currentTypeIndex).abs();
    
    // 根据距离动态计算动画时长：基础 200ms + 每隔一个分类增加 80ms
    final durationMs = (200 + distance * 80).clamp(200, 600);
    
    // 立即更新导航状态（让用户看到响应）
    currentTypeIndex = index;
    navAnimDurationMs = durationMs;
    update(["course_nav_name"]);
    update(["course_nav_overlay"]);
    
    unawaited(_precacheSectionImages(index, wait: true));
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
      curve: Curves.easeInOutCubic,
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

}
