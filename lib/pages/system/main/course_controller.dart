import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/pages/index.dart';
import 'package:think_nest/pages/system/main/widgets/wall_part.dart';

import '../../../common/index.dart';

class CourseControllerWidget extends GetView<MainController> {
  const CourseControllerWidget({super.key});

  
  @override
  /// 渲染全屏课程详情覆盖层（从 MainController 读取当前课程）
  Widget build(BuildContext context) {
    final title = controller.currentCourseName ?? '课程';
    return Scaffold(
      backgroundColor: CustomAppColors.card,
      appBar: AppbarWidget(
        title: title,
        isBack: true,
        onTap: controller.closeCourseController,
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
          size: 36.w,
        ).alignment(Alignment.topLeft).paddingHorizontal(40.w).paddingTop(37.w),
        SizedBox(//横线
          width: 1360.w,
          height: 3.h,
        ).decorated(color: CustomAppColors.border).paddingHorizontal(40.w).paddingTop(25.w),
      //2个选择按钮，同时只能选择一个,用ButtonWidget创建
        _buildCourseControlToggle().paddingHorizontal(40.w).paddingTop(30.w),
        
        Wallpart(),
     
     ].toColumn()
     .decorated(
       color: CustomAppColors.background,
      borderRadius: BorderRadius.circular(20.r),
     );
  }

  /// 构建左侧互斥选择按钮组
  Widget _buildCourseControlToggle() {
    return GetBuilder<MainController>(
      id: 'course_control_toggle',
      builder: (_) {
        final int selectedIndex = controller.courseControlSelectedIndex;
        return ToggleButton(
          labels: const <String>['墙面', '桌面'],
          selectedIndex: selectedIndex,
          onSelected: controller.setCourseControlSelectedIndex,
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
    return <Widget>
     [
      
     ].toColumn()
     .decorated(
       color: CustomAppColors.background,
       borderRadius: BorderRadius.circular(20.r),
     );
  }
}
