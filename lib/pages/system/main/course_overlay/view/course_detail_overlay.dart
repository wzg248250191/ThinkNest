import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:think_nest/common/index.dart';
import 'package:think_nest/common/values/course_introduces.dart';

import '../../../../index.dart';



class CourseDetailOverlay extends GetView<SingleCourseController> {
  const CourseDetailOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final mainController = Get.find<MainController>();
    return GetBuilder<SingleCourseController>(
      id: 'course_detail',
      builder: (_) {
        final title = controller.courseId ?? '课程';
        return Scaffold(
          backgroundColor: CustomAppColors.card,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(160.h),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: AppbarWidget(
                    title: title,
                    isBack: true,
                    onTap: mainController.closeCourseController,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ButtonWidget.ghost(
                    '课程介绍',
                    width: 120.w,
                    height: 48.h,
                    fontSize: 28.sp,
                    backgroundColor: CustomAppColors.primary,
                    textColor: Colors.white,
                    onTap: () => _openCourseIntroducePage(),
                  ).paddingRight(40.w),
                ),
              ],
            ),
          ),
          body: _buildView(context),
        );
      },
    );
  }

  Widget _buildView(BuildContext context) {
    return <Widget>[
      _buildLeft().width(1440.w).height(940.w).paddingLeft(45.w),
      _buildRight().width(420.w).height(940.w).paddingLeft(45.w),
    ].toRow().alignment(Alignment.center);
  }

  void _openCourseIntroducePage() {
    final String title = controller.courseId ?? '课程';
    final String content = courseIntroduces[title] ?? '暂无课程介绍';
    Get.to<void>(() => CourseIntroducePage(title: title, content: content));
  }

  Widget _buildLeft() {
    return <Widget>[
      TextWidget(
        text: "课程控制",
        fontSize: 36.w,
      ).alignment(Alignment.topLeft).paddingHorizontal(40.w).paddingTop(37.w),
      SizedBox(
        width: 1360.w,
        height: 3.h,
      ).decorated(color: CustomAppColors.border).paddingHorizontal(40.w).paddingTop(25.w),
      _buildCourseControlToggle().paddingHorizontal(40.w).paddingTop(30.w),
      GetBuilder<SingleCourseController>(
        id: 'type_switch',
        builder: (_) {
          final int selectedIndex = controller.controlSelectedIndex;
          return IndexedStack(
            index: selectedIndex,
            children: const <Widget>[
              Wallpart(),
              DeskPart(),
            ],
          ).expanded();
        },
      ),
    ].toColumn().decorated(
          color: Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(20.r),
        );
  }

  Widget _buildCourseControlToggle() {
    return GetBuilder<SingleCourseController>(
      id: 'type_switch',
      builder: (_) {
        final int selectedIndex = controller.controlSelectedIndex;
        return ExclusiveButtonGroup(
          labels: const <String>['墙面', '桌面'],
          selectedIndex: selectedIndex,
          onSelected: controller.setControlSelectedIndex,
          buttonWidth: 160.w,
          buttonHeight: 76.h,
          groupRadius: 12.r,
          fontSize: 36.sp,
          borderWidth: AppBorder.button,
          groupBackgroundColor: CustomAppColors.card,
          unselectedBackgroundColor: CustomAppColors.card,
          borderColor: CustomAppColors.border,
          dividerColor: CustomAppColors.border,
        );
      },
    );
  }

  Widget _buildRight() {
    return <Widget>[
      _buildControllToggle().paddingBottom(100.h),
      _buildVolume(),
    ].toColumn().decorated(
          color: Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(20.r),
        );
  }

  Widget _buildControllToggle() {
    return GetBuilder<SingleCourseController>(
      id: 'course_control_toggle',
      builder: (_) {
        final isWallConnected = controller.isWallConnected;
        final isDeskConnected = controller.isDeskConnected;

        return <Widget>[
          TextWidget(
            text: "课程开关",
            fontSize: 36.w,
          ).alignment(Alignment.topLeft).paddingHorizontal(40.w).paddingTop(37.w),
          SizedBox(
            width: 350.w,
            height: 3.h,
          )
              .decorated(color: CustomAppColors.border)
              .paddingHorizontal(40.w)
              .paddingTop(25.w),
          _buildConnectionStatus(isWallConnected, isDeskConnected).paddingTop(10.h),
          <Widget>[
            TextWidget.label('整体控制', fontSize: 28.sp).paddingLeft(37.w),
            const Spacer(),
            ToggleWidget(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
               // width: 90.w,
               height: 35.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
               // width: 90.w,
                height: 35.h,
              ),
              value: controller.wholeEnabled,
              onChanged: controller.setWholeEnabled,
            ).paddingRight(20.w),
          ].toRow().paddingTop(20.h),
          <Widget>[
            TextWidget.label('墙面', fontSize: 28.sp).paddingLeft(37.w),
            Icon(
              Icons.circle,
              size: 12.w,
              color: isWallConnected ? Colors.green : Colors.red,
            ).paddingLeft(8.w),
            const Spacer(),
            ToggleWidget(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
               // width: 90.w,
                height: 35.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
                //width: 90.w,
                height: 35.h,
              ),
              value: controller.wallEnabled,
              onChanged: controller.setWallEnabled,
            ).paddingRight(20.w),
          ].toRow().paddingTop(8.h),
          <Widget>[
            TextWidget.label('桌面', fontSize: 28.sp).paddingLeft(37.w),
            Icon(
              Icons.circle,
              size: 12.w,
              color: isDeskConnected ? Colors.green : Colors.red,
            ).paddingLeft(8.w),
            const Spacer(),
            ToggleWidget(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
               // width: 90.w,
                height: 35.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
               // width: 90.w,
                height: 35.h, 
              ),
              value: controller.deskEnabled,
              onChanged: controller.setDeskEnabled,
            ).paddingRight(20.w),
          ].toRow().paddingTop(8.h),
        ].toColumn();
      },
    );
  }

  Widget _buildConnectionStatus(bool isWallConnected, bool isDeskConnected) {
    if (isWallConnected && isDeskConnected) {
      return const SizedBox.shrink();
    }

    String message;
    if (!isWallConnected && !isDeskConnected) {
      message = '墙面和桌面服务器均未连接';
    } else if (!isWallConnected) {
      message = '墙面服务器未连接';
    } else {
      message = '桌面服务器未连接';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: <Widget>[
        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20.w),
        SizedBox(width: 8.w),
        Text(
          message,
          style: TextStyle(color: Colors.orange, fontSize: 24.sp),
        ).expanded(),
      ].toRow(),
    );
  }

  Widget _buildVolume() {
    return GetBuilder<SingleCourseController>(
      id: 'volume_slider',
      builder: (_) {
        return <Widget>[
          TextWidget(text: "音量", fontSize: 36.w)
              .alignment(Alignment.topLeft)
              .paddingHorizontal(40.w)
              .paddingTop(37.w),
          SizedBox(width: 350.w, height: 3.h)
              .decorated(color: CustomAppColors.border)
              .paddingHorizontal(40.w)
              .paddingTop(25.w),
          <Widget>[
            TextWidget(
              text: "墙面",
              fontSize: 28.w,
            ).paddingLeft(37.w),
            ImageWidget.svg(
              controller.wallVolume == 0 ? AssetsSvgs.muteSvg : AssetsSvgs.volumeSvg,
              width: 90.w,
              height: 30.h,
            ).paddingLeft(20.w),
            SliderWidget(
              value: controller.wallVolume,
              width: 190.w,
              onChanged: controller.setWallVolume,
              onChangeEnd: controller.commitWallVolume,
              activeColor: CustomAppColors.primary,
              inactiveColor: CustomAppColors.border,
              showValueOnLongPress: true,
            ),
          ].toRow().paddingTop(40.h),
          <Widget>[
            TextWidget(
              text: "桌面",
              fontSize: 28.w,
            ).paddingLeft(37.w),
            ImageWidget.svg(
              controller.deskVolume == 0 ? AssetsSvgs.muteSvg : AssetsSvgs.volumeSvg,
              width: 90.w,
              height: 30.h,
            ).paddingLeft(20.w),
            SliderWidget(
              value: controller.deskVolume,
              width: 190.w,
              onChanged: controller.setDeskVolume,
              onChangeEnd: controller.commitDeskVolume,
              activeColor: CustomAppColors.primary,
              inactiveColor: CustomAppColors.border,
              showValueOnLongPress: true,
            ),
          ].toRow().paddingTop(40.h),
        ].toColumn();
      },
    );
  }
}
