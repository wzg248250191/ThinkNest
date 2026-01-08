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

  /// 是否启用“全量构建全部课程”的模式
  /// 说明：
  /// - true：课程页会一次性构建全部课程卡片（不走 Sliver 懒构建）
  /// - 目的：进入课程页后，滚动/跳转主要只改变可视位置，避免边滑边构建造成卡顿
  bool _fullBuildAllModeEnabled = false;

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

  /// 课程清单应用批次标记，用于取消过期的“过滤/分组”任务，避免阻塞 UI
  int _applyCourseListGeneration = 0;

  /// 是否启用课程封面预缓存
  /// 说明：
  /// - 预缓存会触发图片解码，可能与首屏逐个渲染抢占主线程
  /// - 为验证“首屏不卡顿”目标，这里默认关闭；如需恢复可改为 true
  static const bool _enableCourseCoverPrecache = false;

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
    unawaited(_applyCourseList(cached));
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
      unawaited(_applyCourseList(_socketService.courseList));
    }

    _courseListWorker = ever<List<String>>(_socketService.courseList, (list) {
      if (_socketService.isCourseListLoading.value) {
        return;
      }
      unawaited(_applyCourseList(list));
    });

    _courseListLoadingWorker = ever<bool>(_socketService.isCourseListLoading, (loading) {
      isCourseListLoading = loading;
      if (loading) {
        update(["course_list", "course_sync_banner"]);
        return;
      }
      unawaited(_applyCourseList(_socketService.courseList));
    });
  }

  /// 将服务端返回的课程清单映射到本地 coursesByName，并按分类生成展示列表
  /// 说明：
  /// - 只展示服务端允许的课程
  /// - 更新后触发导航定位刷新，并预缓存当前/相邻分类的首屏图片，减少首次显示与切换卡顿
  Future<void> _applyCourseList(List<String> serverCourseList) async {
    final int generation = ++_applyCourseListGeneration;

    final allowed = serverCourseList.where(coursesByName.containsKey).toSet();
    final next = <String, List<String>>{};

    for (int i = 0; i < types.length; i++) {
      if (generation != _applyCourseListGeneration) {
        return;
      }

      final t = types[i];
      final all = _allCourseNamesByType[t] ?? const <String>[];
      final list = <String>[];
      for (final name in all) {
        if (allowed.contains(name)) {
          list.add(name);
        }
      }
      next[t] = list;

      if (i.isOdd) {
        await Future.delayed(Duration.zero);
      }
    }

    if (generation != _applyCourseListGeneration) {
      return;
    }

    typeCourseNames
      ..clear()
      ..addAll(next);

    update(["course_list", "course_sync_banner"]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 首屏优先：默认不进行课程封面预缓存，避免与渲染抢占解码资源
      if (_enableCourseCoverPrecache) {
        _precacheSectionImages(currentTypeIndex);
        _precacheAdjacentSections(currentTypeIndex);
      }
      // 关闭全量后台预缓存：优先保证首屏交互与动画流畅
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
    
    // 导航跳转前的预缓存可能触发解码抢占，默认关闭
    if (_enableCourseCoverPrecache) {
      unawaited(_precacheSectionImages(index, wait: true));
    }
    void animateToTargetWithRetry(int retry) {
      if (!scrollController.hasClients) return;
      final object = sectionKeys[index].currentContext?.findRenderObject();
      if (object == null) {
        if (retry <= 0) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          animateToTargetWithRetry(retry - 1);
        });
        return;
      }
      final viewport = RenderAbstractViewport.of(object);
      final offset = viewport.getOffsetToReveal(object, 0.0).offset;
      final pos = scrollController.position;
      scrollController.animateTo(
        offset.clamp(pos.minScrollExtent, pos.maxScrollExtent),
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeInOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      animateToTargetWithRetry(12);
    });

    Future.delayed(Duration(milliseconds: durationMs + 80), () {
      _isNavigating = false;
      update(["course_nav_overlay"]);
      if (_enableCourseCoverPrecache) {
        _precacheAdjacentSections(index);
      }
    });
  }
  
  /// 预缓存指定分类的课程图片（返回 Future 可等待完成）
  Future<void> _precacheSectionImages(int index, {bool wait = false}) {
    if (!_enableCourseCoverPrecache) {
      return Future.value();
    }
    final ctx = Get.context;
    if (ctx == null) return Future.value();

    final typeName = types[index];
    final courses = typeCourseNames[typeName] ?? [];

    // 分两档策略：
    // - 首屏/后台：只预缓存更小的数量，并且分批让出帧，避免瞬时解码导致动画卡顿
    // - 导航点击（wait=true）：预缓存更多图片，并允许短时间等待提升到位后的流畅度
    final int targetMax = wait ? 10 : 6;
    final int count = courses.length.clamp(0, targetMax);

    if (count <= 0) {
      return Future.value();
    }

    if (wait) {
      final futures = <Future<void>>[];
      for (int i = 0; i < count; i++) {
        // 注意：目录大小写需与真实资源一致，避免 Android 侧资源找不到
        final imgPath = '${AssetsImages.courseCoversDir}${courses[i]}.png';
        futures.add(precacheImage(AssetImage(imgPath), ctx));
      }
      return Future.wait<void>(futures).timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => const <void>[],
      );
    }

    void step(int i) {
      if (i >= count) return;

      // 注意：目录大小写需与真实资源一致，避免 Android 侧资源找不到
      final imgPath = '${AssetsImages.courseCoversDir}${courses[i]}.png';
      precacheImage(AssetImage(imgPath), ctx);

      if (i.isOdd) {
        Future.delayed(const Duration(milliseconds: 16), () => step(i + 1));
      } else {
        step(i + 1);
      }
    }

    step(0);
    return Future.value();
  }
  
  /// 预缓存相邻分类的图片（只预执行当前批次，后续批次会覆盖前一批次）
  void _precacheAdjacentSections(int index) {
    if (!_enableCourseCoverPrecache) {
      return;
    }
    // 使用 Future.microtask 避免阻塞当前帧
    Future.microtask(() {
      if (index > 0) _precacheSectionImages(index - 1);
      if (index < types.length - 1) _precacheSectionImages(index + 1);
    });
  }
  
  /// 🚀 后台预缓存所有分类的首屏图片（页面初始化时调用）
  void _precacheAllSectionsInBackground() {
    // 策略调整：关闭全量后台预缓存
    // 说明：
    // - 全量扫描会触发大量图片解码/栅格化，容易在启动阶段造成明显卡顿
    // - 仅保留“当前分类 + 相邻分类”的小范围预缓存
    return;
  }

  /// 启用“全量构建全部课程”模式
  /// 说明：
  /// - 该模式下不再做首屏裁剪、渐进展开、逐行展开
  /// - 由 Splash 在启动期打开，保证进入课程页后滚动/跳转更稳定
  void enableFullBuildAllMode() {
    if (_fullBuildAllModeEnabled) return;
    _fullBuildAllModeEnabled = true;
  }

  /// Splash 期间预加载：等待课程清单稳定，并预缓存课程图片资源
  /// 说明：
  /// - 预缓存不依赖 BuildContext，避免跨 async gap 使用 context 的风险
  /// - 预缓存会尽量按卡片实际尺寸做 ResizeImage，减少内存压力
  Future<void> preloadForSplash() async {
    // 绑定课程清单监听（避免 controller 提前创建却没有进入课程页，导致未绑定 socket）
    if (_courseListWorker == null || _courseListLoadingWorker == null) {
      _bindCourseList();
    }

    // 等待一次可用的课程清单（优先等服务端；超时则使用本地缓存已回显的数据）
    final int startMs = DateTime.now().millisecondsSinceEpoch;
    const int timeoutMs = 6500;
    while (DateTime.now().millisecondsSinceEpoch - startMs < timeoutMs) {
      final bool loading = _socketService.isCourseListLoading.value;
      final bool hasServerList = _socketService.courseList.isNotEmpty;
      final bool hasLocalReady = typeCourseNames.isNotEmpty &&
          typeCourseNames.values.any((e) => e.isNotEmpty);

      if (!loading && hasServerList) {
        await _applyCourseList(_socketService.courseList);
        break;
      }
      if (hasLocalReady) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // 预缓存页面固定资源（分割线、卡片背景等）
    await _precacheAssetImagesForCoursePage();
    // 预缓存所有课程封面
    await _precacheAllCourseCovers();
  }

  /// 预缓存课程页使用的固定资源图片
  Future<void> _precacheAssetImagesForCoursePage() async {
    final double dpr = _devicePixelRatioForPrecache();
    final List<ImageProvider> providers = <ImageProvider>[
      const AssetImage(AssetsImages.courseSplitPng),
      const AssetImage(AssetsImages.courseBgPng),
    ];

    for (final p in providers) {
      try {
        await _precacheImageProvider(p, devicePixelRatio: dpr);
      } catch (_) {
        // 忽略预缓存异常，避免启动期卡死
      }
    }
  }

  /// 预缓存所有课程封面（按卡片实际像素尺寸做 ResizeImage）
  Future<void> _precacheAllCourseCovers() async {
    // 根据课程页布局常量估算单个卡片宽度，从而推导封面解码尺寸
    final double dpr = _devicePixelRatioForPrecache();
    final double listWidth = 1480.w;
    final double contentWidth = listWidth - 2 * listPaddingHorizontal;
    final double totalSpacing = (crossAxisCount - 1) * crossAxisSpacing;
    final double cellWidth =
        ((contentWidth - totalSpacing) / crossAxisCount).clamp(1.0, double.infinity);
    final double imageSide = cellWidth * 0.887;
    final int targetPx = (imageSide * dpr).round().clamp(1, 4096);

    final List<String> allCourseNames = <String>[];
    for (final t in types) {
      final list = typeCourseNames[t] ?? const <String>[];
      if (list.isNotEmpty) {
        allCourseNames.addAll(list);
      }
    }

    for (int i = 0; i < allCourseNames.length; i++) {
      final String name = allCourseNames[i];
      // 注意：目录大小写需与真实资源一致，避免 Android 侧资源找不到
      final String imgPath = '${AssetsImages.courseCoversDir}$name.png';
      try {
        final ImageProvider provider = ResizeImage(
          AssetImage(imgPath),
          width: targetPx,
          height: targetPx,
        );
        await _precacheImageProvider(provider, devicePixelRatio: dpr);
      } catch (_) {
        // 忽略单个资源失败，继续预缓存后续图片
      }
      // 分批让出帧，避免启动阶段长时间占用 UI 线程
      if (i % 12 == 11) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// 获取启动期预缓存用的设备像素比
  /// 说明：不依赖 BuildContext，避免跨异步间隙使用 context 的风险
  double _devicePixelRatioForPrecache() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return 1.0;
    }
    return views.first.devicePixelRatio;
  }

  /// 预缓存指定 ImageProvider（不依赖 BuildContext）
  /// 说明：通过 resolve + ImageStreamListener 等待图片解码完成
  Future<void> _precacheImageProvider(
    ImageProvider provider, {
    required double devicePixelRatio,
  }) {
    final Completer<void> completer = Completer<void>();
    final ImageConfiguration config = ImageConfiguration(devicePixelRatio: devicePixelRatio);
    final ImageStream stream = provider.resolve(config);

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo image, bool synchronousCall) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

}
