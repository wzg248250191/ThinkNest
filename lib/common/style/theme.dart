import 'package:flutter/material.dart';

import 'colors.dart';

/// 主题
class AppTheme {
  /////////////////////////////////////////////////
  /// 自定义颜色
  /////////////////////////////////////////////////
  static const primary = Color(0xFF5F84FF);
  static const secondary = Color(0xFFFF6969);
  static const success = Color(0xFF23A757);
  static const warning = Color(0xFFFF1843);
  static const error = Color(0xFFDA1414);
  static const info = Color(0xFF2E5AAC);

  /////////////////////////////////////////////////
  /// 主题
  /////////////////////////////////////////////////

  /// 亮色主题
  static ThemeData get light {
    ColorScheme scheme = MaterialTheme.lightScheme();
    return _getTheme(scheme);
  }

  /// 暗色主题
  static ThemeData get dark {
    ColorScheme scheme = MaterialTheme.darkScheme();
    return _getTheme(scheme);
  }

  /// 自定义主题
  static ThemeData get custom {
    ColorScheme scheme = MaterialTheme.lightScheme().copyWith(
      primary: CustomAppColors.primary,
      onPrimary: Colors.white,
      surface: CustomAppColors.card,
      onSurface: CustomAppColors.text,
      onSurfaceVariant: CustomAppColors.subText,
      outline: CustomAppColors.border,
    );
    return _getTheme(scheme).copyWith(
      //设置背景色
      scaffoldBackgroundColor: CustomAppColors.background,
    );
  }


  /// 获取主题
  static ThemeData _getTheme(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: false,
      colorScheme: scheme,
       fontFamily: "Alibaba-PuHuiTi", // 字体
    );
  }
}
class CustomAppColors {
  static const Color primary = Color(0xFF3A9F7F); // 设计主绿
  static const Color background = Color.fromARGB(255, 247, 247, 247);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFDFE4EA);
  static const Color text = Color(0xFF1B1C1F);
  static const Color subText = Color(0xFF55606D);
}

class CustomAppRadius {
  static const Radius r12 = Radius.circular(12);
  static const Radius r20 = Radius.circular(20);
}

class CustomAppSpacing {
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}
