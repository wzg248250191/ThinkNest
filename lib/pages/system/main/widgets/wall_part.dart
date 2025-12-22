import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:think_nest/common/index.dart';

class Wallpart extends StatelessWidget {
  const Wallpart({super.key});



  @override
  /// 构建墙面区域卡片
  Widget build(BuildContext context) {
    return _buildView(context);
  }
  Widget _buildView(BuildContext context) {
    return  <Widget>[
        _buildCard('学生互动区'),
        _buildCard('老师讲解区区'),
        _buildCard( '学生互动区')
        ].toRow(mainAxisAlignment: MainAxisAlignment.spaceEvenly,crossAxisAlignment: CrossAxisAlignment.center)
        .alignment(Alignment.center).expanded();
   }

  /// 构建墙面区域内容布局
  Widget _buildCard(String title) {
    return <Widget>[
      TextWidget.label(
        title,
        fontSize: 36.sp,
      ),
     ToggleButton(
            firstText: '关闭墙面',
            secondText: '开启墙面',
            width: 160.w,
            height: 76.h,
            fontSize: 28.sp,
            textColorOff: CustomAppColors.subText,
            textColorOn: CustomAppColors.subText,
            backgroundColorOff: CustomAppColors.card, // 白底
            backgroundColorOn: CustomAppColors.card, // 白底
           variantOff: ButtonWidgetVariant.outline,
           variantOn: ButtonWidgetVariant.outline,
             borderColor: CustomAppColors.text, // 可选：自定义边框色
            onChanged: (v) {},
          ),
           ToggleButton(
             firstText: '关闭互动',
            secondText: '开启互动',
            width: 160.w,
            height: 76.h,
            fontSize: 28.sp,
            textColorOff: CustomAppColors.subText,
            textColorOn: CustomAppColors.subText,
            backgroundColorOff: CustomAppColors.card, // 白底
            backgroundColorOn: CustomAppColors.card, // 白底
           variantOff: ButtonWidgetVariant.outline,
           variantOn: ButtonWidgetVariant.outline,
             borderColor: CustomAppColors.text, // 可选：自定义边框色
            onChanged: (v) {},
          ),
           ButtonWidget.outline(
            '重新开始',
            width: 160.w,
            height: 76.h,
            fontSize: 28.sp,
            textColor: CustomAppColors.subText,
            backgroundColor: CustomAppColors.card, // 白底
            borderColor: CustomAppColors.text, // 可选：自定义边框色
            onTap: () {},
          )
    ].toColumn(mainAxisAlignment: MainAxisAlignment.spaceAround).width(410.w).height(610.h).decorated(
          color: CustomAppColors.border,
          borderRadius: BorderRadius.circular(12.r),
        );
  }
}

