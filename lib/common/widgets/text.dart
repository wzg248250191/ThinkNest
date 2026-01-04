import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';

import '../index.dart';

// 排版类型
enum TextWidgetType {
  h1,//字号:36；字重:粗体 (Bold / 800);一般一个页面只出现一次，作为视觉焦点
  h2,//字号:30,字重:半粗 (Medium / 600);一般弹窗（Dialog）的标题
  h3,//字号:24,字重:中体 (Medium / 600);小节标题
  h4,//字号:20,字重:中体 (Medium / 600);
  body,//字号:16,字重 ：普通 (Regular / 400);
  label,//字号:14,字重 ：普通 (Regular / 400);
  muted,//字号:12,字重 ：普通 (Regular / 400);
}

class TextWidget extends StatelessWidget {
  const TextWidget({
    super.key,
    required this.text,
    this.type,
    this.fontSize,
    this.scale,
    this.textStyle,
    this.color,
    this.weight,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.fontStyle,
    this.inlineSpan,
  });

  /// 文字
  final String text;

  final InlineSpan? inlineSpan;

  /// 排版类型
  final TextWidgetType? type;

  /// 缩放 large medium small
  final WidgetScale? scale;

  /// 组件样式
  final TextStyle? textStyle;

  /// 字体样式
  final FontStyle? fontStyle;

  /// 颜色
  final Color? color;

  /// 大小
  final double? fontSize;

  /// 重量
  final FontWeight? weight;

  /// 行数
  final int? maxLines;

  /// 自动换行
  final bool? softWrap;

  /// 溢出
  final TextOverflow? overflow;

  /// 对齐方式
  final TextAlign? textAlign;

  /// h1
  const TextWidget.h1(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w800,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.h1,
        inlineSpan = null;

  /// h2
  const TextWidget.h2(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w600,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.h2,
        inlineSpan = null;

  /// h3
  const TextWidget.h3(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w600,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.h3,
        inlineSpan = null;

  /// h4
  const TextWidget.h4(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w600,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.h4,
        inlineSpan = null;

  /// body
  const TextWidget.body(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w400,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.body,
        inlineSpan = null;

  /// label
  const TextWidget.label(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w400,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.label,
        inlineSpan = null;

  /// muted
  const TextWidget.muted(
    this.text, {
    super.key,
    this.scale,
    this.fontSize,
    this.color,
    this.weight = FontWeight.w400,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.textStyle,
    this.fontStyle,
  })  : type = TextWidgetType.muted,
        inlineSpan = null;

  const TextWidget.rich(
    this.inlineSpan, {
    super.key,
    this.type,
    this.fontSize,
    this.scale,
    this.textStyle,
    this.color,
    this.weight,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
    this.fontStyle,
  }) : text = '';

  /// 文字尺寸
  double _fontSize() {
    // 计算字体
    // https://tailwindcss.com/docs/font-size
    double fontSize = this.fontSize ?? 0;
    if (fontSize == 0) {
      switch (type) {
        case TextWidgetType.h1:
          fontSize = 36;
        case TextWidgetType.h2:
          fontSize = 30;
        case TextWidgetType.h3:
          fontSize = 24;
        case TextWidgetType.h4:
          fontSize = 20;
        case TextWidgetType.body:
          fontSize = 16;
        case TextWidgetType.label:
          fontSize = 14;
        case TextWidgetType.muted:
          fontSize = 12;
        default:
          fontSize = 14;
      }
    }

    // 计算缩放
    // https://m3.material.io/styles/typography/type-scale-tokens
    switch (scale) {
      case WidgetScale.large:
        return fontSize * 1.3;
      case WidgetScale.medium:
        return fontSize;
      case WidgetScale.small:
        return fontSize * 0.8;
      default:
        return fontSize;
    }
  }

  Color _color(BuildContext context) {
    if (color != null) {
      return color!;
    }

    switch (type) {
      case TextWidgetType.h1:
      case TextWidgetType.h2:
      case TextWidgetType.h3:
      case TextWidgetType.h4:
      case TextWidgetType.body:
      case TextWidgetType.label:
        return context.colors.scheme.onSurface;
      case TextWidgetType.muted:
        return context.colors.scheme.onSurface.withValues(alpha: 0.8);
      default:
        return context.colors.scheme.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeTextStyle = theme.textTheme.bodyMedium;
    final baseStyle = TextStyle(
      color: _color(context),
      fontSize: _fontSize(),
      fontWeight: weight,
      fontStyle: fontStyle,
      fontFamily: themeTextStyle?.fontFamily,
      fontFamilyFallback: themeTextStyle?.fontFamilyFallback,
      decoration: TextDecoration.none,
    ).merge(textStyle);

    final span = inlineSpan;
    if (span != null) {
      return Text.rich(
        span,
        style: baseStyle,
        maxLines: maxLines,
        softWrap: softWrap,
        overflow: overflow,
        textAlign: textAlign,
      );
    }
    return Text(
      text,
      style: baseStyle,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
