part of '../controller.dart';

/// 一体化页面“总开关冷却期”能力集合
///
/// 说明：
/// - 总开关开启后，限制一段时间内子开关的操作
/// - 冷却期间触发操作时弹出倒计时提示弹窗
/// - 通过覆写 [_IntegrationSwitchStateMixin] 的主开关钩子实现自动启停
mixin _IntegrationSwitchCooldownMixin on GetxController, _IntegrationSwitchStateMixin {
  /// 总开关开启后的冷却时长
  final Duration _mainCooldownDuration = const Duration(seconds: 10);

  /// 记录总开关最近一次开启时间
  DateTime? _mainTurnedOnAt;

  /// 标记下一次“总开关关->开”是否由用户手动触发，用于决定是否启动冷却倒计时。
  bool _mainCooldownArmed = false;

  /// 防止重复弹窗
  bool _mainCooldownDialogShowing = false;

  /// 倒计时刷新计时器（每秒刷新一次）
  Timer? _mainCooldownTimer;

  /// 标记总开关即将由用户手动打开，用于启动 10 秒冷却倒计时。
  void _armMainCooldownForUserTurnOn() {
    _mainCooldownArmed = true;
  }

  @override
  /// 总开关从关->开：记录开启时间，开始冷却计时
  void _onMainSwitchTurnedOn() {
    if (!_mainCooldownArmed) {
      return;
    }
    _mainCooldownArmed = false;
    _mainTurnedOnAt = DateTime.now();
  }

  @override
  /// 总开关从开->关：清空开启时间，并关闭可能存在的冷却弹窗
  void _onMainSwitchTurnedOff() {
    _mainCooldownArmed = false;
    _mainTurnedOnAt = null;
    _dismissMainCooldownDialog();
  }

  /// 计算总开关冷却期剩余秒数
  int _remainingMainCooldownSeconds() {
    final DateTime? turnedOnAt = _mainTurnedOnAt;
    if (turnedOnAt == null) {
      return 0;
    }
    if (!_mustSwitchState(IntegrationSwitchType.main).isOn) {
      return 0;
    }
    final Duration elapsed = DateTime.now().difference(turnedOnAt);
    final Duration remaining = _mainCooldownDuration - elapsed;
    if (remaining <= Duration.zero) {
      return 0;
    }
    final int seconds = (remaining.inMilliseconds / 1000).ceil();
    return seconds < 0 ? 0 : seconds;
  }

  /// 显示冷却期提示弹窗（倒计时）
  Future<void> _showMainCooldownDialog() async {
    if (_mainCooldownDialogShowing) {
      return;
    }
    final int initial = _remainingMainCooldownSeconds();
    if (initial <= 0) {
      return;
    }

    _mainCooldownDialogShowing = true;
    int remaining = initial;
    try {
      await Get.dialog<void>(
        StatefulBuilder(
          builder: (context, setState) {
            _mainCooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              final int next = _remainingMainCooldownSeconds();
              if (next <= 0) {
                _dismissMainCooldownDialog();
                return;
              }
              if (next != remaining) {
                remaining = next;
                setState(() {});
              }
            });

            final message = '等待设备预处理，还需 $remaining 秒才能操作';
            final messageStyle = TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w400,
              color: CustomAppColors.text,
              decoration: TextDecoration.none,
            );
            final resolvedStyle = DefaultTextStyle.of(context).style.merge(messageStyle);
            const double containerPaddingH = 5.0;
            final painter = TextPainter(
              text: TextSpan(text: message, style: resolvedStyle),
              textDirection: Directionality.of(context),
              locale: Localizations.localeOf(context),
              maxLines: 1,
              textAlign: TextAlign.center,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final dialogWidth =
                (painter.width + (containerPaddingH.w * 2)).clamp(500.w, 1200.w).toDouble();

            return <Widget>[
              Icon(
                Icons.info_outline,
                size: 44.sp,
                color: CustomAppColors.primary,
              ).paddingOnly(top: 28.h),
              TextWidget.label(
                message,
                textAlign: TextAlign.center,
                fontSize: 28.sp,
                color: CustomAppColors.text,
                weight: FontWeight.w400,
                textStyle: const TextStyle(decoration: TextDecoration.none),
              ).padding(horizontal: containerPaddingH.w, vertical: 20.h),
              SizedBox(height: 22.h),
              ButtonWidget.ghost(
                '确定',
                fontSize: 28.sp,
                width: double.infinity,
                onTap: _dismissMainCooldownDialog,
              ),
            ]
                .toColumn(mainAxisSize: MainAxisSize.min)
                .constrained(
                  width: dialogWidth,
                  minHeight: 200.h,
                  maxHeight: 620.h,
                )
                .decorated(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                )
                .center();
          },
        ),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.3),
      );
    } finally {
      _mainCooldownDialogShowing = false;
      _mainCooldownTimer?.cancel();
      _mainCooldownTimer = null;
    }
  }

  /// 关闭冷却期弹窗并清理计时器
  void _dismissMainCooldownDialog() {
    _mainCooldownTimer?.cancel();
    _mainCooldownTimer = null;
    if (_mainCooldownDialogShowing && (Get.isDialogOpen ?? false)) {
      Get.back<void>();
    }
  }
}
