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

  final Duration _mainTurnOffCooldownDuration = const Duration(seconds: 10);

  DateTime? _lastEnabledOpenedSubTurnedOffAt;

  bool _mainTurnOffCooldownDialogShowing = false;

  Timer? _mainTurnOffCooldownTimer;

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
    _clearMainTurnOffCooldown();
    _dismissMainTurnOffCooldownDialog();
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

  void _markLastEnabledOpenedSubTurnedOff() {
    _lastEnabledOpenedSubTurnedOffAt = DateTime.now();
  }

  void _clearMainTurnOffCooldown() {
    _lastEnabledOpenedSubTurnedOffAt = null;
  }

  int _enabledOpenedSubSwitchCount() {
    int count = 0;
    for (final type in IntegrationSwitchType.values) {
      if (type == IntegrationSwitchType.main) {
        continue;
      }
      final SwitchCircleState state = _mustSwitchState(type);
      if (state.enabled && state.isOn) {
        count++;
      }
    }
    return count;
  }

  int _remainingMainTurnOffCooldownSeconds() {
    final DateTime? turnedOffAt = _lastEnabledOpenedSubTurnedOffAt;
    if (turnedOffAt == null) {
      return 0;
    }
    if (!_mustSwitchState(IntegrationSwitchType.main).isOn) {
      return 0;
    }
    if (_enabledOpenedSubSwitchCount() > 0) {
      return 0;
    }
    final Duration elapsed = DateTime.now().difference(turnedOffAt);
    final Duration remaining = _mainTurnOffCooldownDuration - elapsed;
    if (remaining <= Duration.zero) {
      return 0;
    }
    final int seconds = (remaining.inMilliseconds / 1000).ceil();
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> _showMainTurnOffCooldownDialog() async {
    if (_mainTurnOffCooldownDialogShowing) {
      return;
    }
    final int initial = _remainingMainTurnOffCooldownSeconds();
    if (initial <= 0) {
      return;
    }
    _mainTurnOffCooldownDialogShowing = true;
    int remaining = initial;
    try {
      await Get.dialog<void>(
        StatefulBuilder(
          builder: (context, setState) {
            _mainTurnOffCooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              final int next = _remainingMainTurnOffCooldownSeconds();
              if (next <= 0) {
                _dismissMainTurnOffCooldownDialog();
                return;
              }
              if (next != remaining) {
                remaining = next;
                setState(() {});
              }
            });

            final message = '最后设备刚关闭，还需 $remaining 秒才能关闭总开关';
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
                onTap: _dismissMainTurnOffCooldownDialog,
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
      _mainTurnOffCooldownDialogShowing = false;
      _mainTurnOffCooldownTimer?.cancel();
      _mainTurnOffCooldownTimer = null;
    }
  }

  void _dismissMainTurnOffCooldownDialog() {
    _mainTurnOffCooldownTimer?.cancel();
    _mainTurnOffCooldownTimer = null;
    if (_mainTurnOffCooldownDialogShowing && (Get.isDialogOpen ?? false)) {
      Get.back<void>();
    }
  }

  /// 单开关冷却时长（对同一开关再次切换需间隔 10 秒）
  final Duration _switchCooldownDuration = const Duration(seconds: 10);

  /// 记录每个开关最近一次用户操作时间
  final Map<IntegrationSwitchType, DateTime> _switchLastOpAt = <IntegrationSwitchType, DateTime>{};

  /// 防止重复弹出“单开关冷却”弹窗
  bool _switchCooldownDialogShowing = false;

  /// 单开关冷却倒计时计时器
  Timer? _switchCooldownTimer;

  /// 计算指定开关的冷却期剩余秒数
  int _remainingSwitchCooldownSeconds(IntegrationSwitchType type) {
    final DateTime? last = _switchLastOpAt[type];
    if (last == null) {
      return 0;
    }
    final Duration elapsed = DateTime.now().difference(last);
    final Duration remaining = _switchCooldownDuration - elapsed;
    if (remaining <= Duration.zero) {
      return 0;
    }
    final int seconds = (remaining.inMilliseconds / 1000).ceil();
    return seconds < 0 ? 0 : seconds;
  }

  /// 标记指定开关发生了一次用户操作（用于开启 10 秒冷却）
  void _markSwitchOperated(IntegrationSwitchType type) {
    _switchLastOpAt[type] = DateTime.now();
  }

  /// 显示“单开关冷却期”提示弹窗（倒计时）
  Future<void> _showSwitchCooldownDialog(IntegrationSwitchType type) async {
    if (_switchCooldownDialogShowing) {
      return;
    }
    final int initial = _remainingSwitchCooldownSeconds(type);
    if (initial <= 0) {
      return;
    }
    _switchCooldownDialogShowing = true;
    int remaining = initial;
    try {
      await Get.dialog<void>(
        StatefulBuilder(
          builder: (context, setState) {
            _switchCooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              final int next = _remainingSwitchCooldownSeconds(type);
              if (next <= 0) {
                _dismissSwitchCooldownDialog();
                return;
              }
              if (next != remaining) {
                remaining = next;
                setState(() {});
              }
            });

            final message = '该开关刚操作，还需 $remaining 秒才能再次操作';
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
                onTap: _dismissSwitchCooldownDialog,
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
      _switchCooldownDialogShowing = false;
      _switchCooldownTimer?.cancel();
      _switchCooldownTimer = null;
    }
  }

  /// 关闭“单开关冷却期”弹窗并清理计时器
  void _dismissSwitchCooldownDialog() {
    _switchCooldownTimer?.cancel();
    _switchCooldownTimer = null;
    if (_switchCooldownDialogShowing && (Get.isDialogOpen ?? false)) {
      Get.back<void>();
    }
  }
}
