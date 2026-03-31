import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

class CourseIntroducePage extends StatelessWidget {
  const CourseIntroducePage({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  /// 规整课程介绍 HTML 的段距与行高，保留原有结构与大部分样式，仅去掉导致间距过大的内联样式
  String _normalizeHtmlSpacing(String rawHtml) {
    return rawHtml
        // 关键：原始数据里大量 p 标签带 margin-bottom:20px，会导致段落之间空白过大，这里统一移除。
        .replaceAll(
          RegExp(r'margin-bottom\s*:\s*[\d.]+px;?', caseSensitive: false),
          '',
        )
        // 关键：原始数据里 line-height:32px 会让正文行距偏大，这里统一移除，交给渲染默认行高。
        .replaceAll(
          RegExp(r'line-height\s*:\s*[\d.]+px;?', caseSensitive: false),
          '',
        )
        // 关键：清理因移除样式产生的空 style=""，避免无效属性残留。
        .replaceAll(RegExp(r'\sstyle="\s*"'), '');
  }

  @override
  /// 构建课程介绍全屏页，顶部使用通用返回 AppBar，正文按 HTML 富文本渲染
  Widget build(BuildContext context) {
    return MediaQuery(
      // 关键逻辑：课程介绍页统一放大 1.5 倍文本缩放，仅作用于当前页面，避免影响全局页面排版。
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
      child: Scaffold(
        backgroundColor: CustomAppColors.card,
        appBar: AppbarWidget(
          title: '$title - 课程介绍',
          isBack: true,
          onTap: () => Get.back<void>(),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 30.h),
          child: Html(data: _normalizeHtmlSpacing(content)),
        ),
      ),
    );
  }
}
