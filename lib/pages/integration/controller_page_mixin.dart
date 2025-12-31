part of 'controller.dart';

/// 一体化页面的“分页/配置页切换”能力集合
///
/// 说明：
/// - 该 mixin 负责维护右侧 PageView（入口页/设备配置页）的切换逻辑
/// - 通过点击隐藏入口（右下角区域）累计点击次数，触发进入“设备配置”页
/// - 通过 [isConfig] 作为当前是否处于配置页的标记，驱动 AppBar 返回按钮等 UI
mixin _IntegrationPageMixin on GetxController {
  /// 内部 PageView 控制器（用于页面切换动画）
  PageController get innerPageController;

  /// 当前是否处于“设备配置”页
  bool get isConfig;

  /// 更新当前是否处于“设备配置”页
  set isConfig(bool value);

  /// 连续点击计数（用于触发进入“设备配置”页）
  int _deviceConfigTapCount = 0;

  /// 上一次点击时间（用于判定是否重置计数窗口）
  DateTime? _lastDeviceConfigTapAt;

/// 处理“设备配置”项点击事件
  ///
  /// 说明：
  /// - 点击 5 次及以上，打开“设备配置”页
  void onDeviceConfigEntryTap() {
    if (isConfig) {
      return;
    }

    final now = DateTime.now();
    final last = _lastDeviceConfigTapAt;
    if (last == null || now.difference(last) > const Duration(milliseconds: 1200)) {
      _deviceConfigTapCount = 0;
    }

    _lastDeviceConfigTapAt = now;
    _deviceConfigTapCount += 1;

    if (_deviceConfigTapCount >= 5) {
      openConfig();
    }
  }

  /// 打开“设备配置”页（切换 PageView 到 index=1）
  void openConfig() {
    // 右→左滑入“关于我们”页
    innerPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = true;
    update(["integration"]);
  }

  /// 关闭“设备配置”页（切回入口页 index=0）
  void closeConfig() {
    // 左→右滑出返回设置列表
    innerPageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    isConfig = false;
    update(["integration"]);
  }

  /// PageView 页切换回调（用于同步 [isConfig]）
  void onInnerPageChanged(int index) {
    isConfig = index == 1;
    update(["integration"]);
  }

  /// 初始化入口页所需状态
  _initData() {
    update(["integration"]);
  }
}
