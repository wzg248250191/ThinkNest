import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


import '../../../common/index.dart';
import '../../index.dart';

class CourseDetailOverlay extends GetView<SingleCourseController> {
  const CourseDetailOverlay({super.key});

  
  @override
  /// 渲染全屏课程详情覆盖层
  Widget build(BuildContext context) {
    final mainController = Get.find<MainController>();
    final title = controller.courseId ?? '课程';
    return Scaffold(
      backgroundColor: CustomAppColors.card,
      appBar: AppbarWidget(
        title: title,
        isBack: true,
        onTap: mainController.closeCourseController,
      ),
      body: _buildView(context),
    );
  }

  Widget _buildView(BuildContext context)
  {
     return <Widget>
     [
       _buildLeft().width(1440.w).height(940.w).paddingLeft(45.w),
       _buildRight().width(420.w).height(940.w).paddingLeft(45.w),
     ].toRow()
     .alignment(Alignment.center);
  }

  Widget _buildLeft()
  {
     return  
     <Widget>
     [
        TextWidget(
          text: "课程控制",
          fontSize: 36.w,
        ).alignment(Alignment.topLeft).paddingHorizontal(40.w).paddingTop(37.w),
        SizedBox(//横线
          width: 1360.w,
          height: 3.h,
        ).decorated(color: CustomAppColors.border).paddingHorizontal(40.w).paddingTop(25.w),
      //2个选择按钮，同时只能选择一个,用ButtonWidget创建
        _buildCourseControlToggle().paddingHorizontal(40.w).paddingTop(30.w),
        GetBuilder<SingleCourseController>(
          id: 'type_switch',
          builder: (_) {
            final int selectedIndex = controller.controlSelectedIndex;
            return selectedIndex == 0 ? Wallpart() : DeskPart();
          },
        ),
     ].toColumn()
     .decorated(
       color: CustomAppColors.background,
      borderRadius: BorderRadius.circular(20.r),
     );
  }

  /// 构建左侧互斥选择按钮组
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
    return  <Widget>[
      _buildControllToggle().paddingBottom(100.h) ,
     _buildVolume()
    ].toColumn()
     .decorated(
       color: CustomAppColors.background,
      borderRadius: BorderRadius.circular(20.r),
     );
  }

///课程控制Toggle
   Widget _buildControllToggle()
  {
    return GetBuilder<SingleCourseController>(
      id: 'course_control_toggle',
      builder: (_) {
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
          <Widget>[
            TextWidget.label('整体控制', fontSize: 28.sp).paddingLeft(37.w),
            const Spacer(),
            Toggle(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
                width: 90.w,
                height: 30.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
                width: 90.w,
                height: 30.h,
              ),
              value: controller.wholeEnabled,
              onChanged: controller.setWholeEnabled,
            ).paddingRight(40.w),
          ].toRow().paddingTop(20.h),
          <Widget>[
            TextWidget.label('墙面', fontSize: 28.sp).paddingLeft(37.w),
            const Spacer(),
            Toggle(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
                width: 90.w,
                height: 30.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
                width: 90.w,
                height: 30.h,
              ),
              value: controller.wallEnabled,
              onChanged: controller.setWallEnabled,
            ).paddingRight(40.w),
          ].toRow().paddingTop(8.h),
           <Widget>[
            TextWidget.label('桌面', fontSize: 28.sp).paddingLeft(37.w),
            const Spacer(),
            Toggle(
              firstIcon: ImageWidget.svg(
                AssetsSvgs.openSvg,
                width: 90.w,
                height: 30.h,
              ),
              secondIcon: ImageWidget.svg(
                AssetsSvgs.closeSvg,
                width: 90.w,
                height: 30.h,
              ),
              value: controller.deskEnabled,
              onChanged: controller.setDeskEnabled,
            ).paddingRight(40.w),
          ].toRow().paddingTop(8.h),
        ]
            .toColumn();
      },
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
            TextWidget(text: "墙面",fontSize: 28.w,).paddingLeft(37.w),
            ImageWidget.svg(controller.wallVolume==0?AssetsSvgs.muteSvg:AssetsSvgs.volumeSvg, width: 90.w, height: 30.h).paddingLeft(20.w),
           SliderWidget(
              value: controller.wallVolume,
              width: 190.w,
              onChanged: controller.setWallVolume,
              activeColor: CustomAppColors.primary,
              inactiveColor: CustomAppColors.border,
              showValueOnLongPress: true,
            ) 
          ].toRow().paddingTop(40.h),
           <Widget>[
            TextWidget(text: "桌面",fontSize: 28.w,).paddingLeft(37.w),
            ImageWidget.svg(controller.deskVolume==0?AssetsSvgs.muteSvg:AssetsSvgs.volumeSvg, width: 90.w, height: 30.h).paddingLeft(20.w),
           SliderWidget(
              value: controller.deskVolume,
              width: 190.w,
              onChanged: controller.setDeskVolume,
              activeColor: CustomAppColors.primary,
              inactiveColor: CustomAppColors.border,
              showValueOnLongPress: true,
            ) 
          ].toRow().paddingTop(40.h),
        ].toColumn();
      },
    );
  }
}
