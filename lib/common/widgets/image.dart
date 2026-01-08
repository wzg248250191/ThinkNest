import 'package:cached_network_image/cached_network_image.dart';
import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg_lib;

import '../index.dart';

/// 图片类型
enum ImageWidgetType {
  img,//本地/远程 图片
  svg,//本地/远程 svg图片
  svgRaw,//raw 数据
}
/// 图片组件
class ImageWidget extends StatefulWidget {
  const ImageWidget({
    super.key,
    required this.path,
    required this.type,
    this.radius,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.placeholder,
    this.errorWidget,
    this.elevation,
    this.color,
  });

  /// 文件路径
  final String path;

  /// 类型
  final ImageWidgetType type;

  /// 圆角
  final double? radius;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 自适应方式
  final BoxFit? fit;

  final AlignmentGeometry? alignment;

  /// 占位图
  final Widget? placeholder;

  /// 错误图
  final Widget? errorWidget;

  /// 阴影
  final double? elevation;

  /// 颜色
  final Color? color;

  const ImageWidget.img(
    this.path, {
    super.key,
    this.radius,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.placeholder,
    this.errorWidget,
    this.elevation,
    this.color,
  }) : type = ImageWidgetType.img;

  const ImageWidget.svg(
    this.path, {
    super.key,
    this.radius,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.placeholder,
    this.errorWidget,
    this.elevation,
    this.color,
  }) : type = ImageWidgetType.svg;

  const ImageWidget.svgRaw(
    String raw, {
    super.key,
    this.radius,
    this.width,
    this.height,
    this.fit,
    this.alignment,
    this.placeholder,
    this.errorWidget,
    this.elevation,
    this.color,
  })  : type = ImageWidgetType.svgRaw,
        path = raw;

  /// 预热一组本地 SVG 资源，降低首次渲染解析/光栅化带来的卡顿
  ///
  /// 说明：
  /// - 使用 flutter_svg 的 Picture 缓存机制，将解析结果提前放入缓存
  /// - 通过分批 + 帧间让出，避免一次性预热阻塞首帧动画
  static Future<void> precacheSvgAssets(
    List<String> assetPaths, {
    int batchSize = 2,
    Duration yieldDuration = const Duration(milliseconds: 16),
    bool logErrors = false,
  }) async {
    if (assetPaths.isEmpty) return;
    if (batchSize <= 0) batchSize = 1;

    int start = 0;
    while (start < assetPaths.length) {
      final int end = (start + batchSize).clamp(0, assetPaths.length);
      for (int i = start; i < end; i++) {
        final String path = assetPaths[i];
        try {
          final svg_lib.SvgAssetLoader loader = svg_lib.SvgAssetLoader(path);
          await svg_lib.svg.cache.putIfAbsent(
            loader.cacheKey(null),
            () => loader.loadBytes(null),
          );
        } catch (e, s) {
          // 预热失败不影响主流程：可能是资源缺失或解析失败
          // 但在需要定位 SVG 语法错误时，可以打开 logErrors 打印路径与异常
          if (logErrors) {
            // 仅在 Debug 下输出预热失败信息，避免 Release 额外开销
            DebugUtils.log('【SVG预热失败】path=$path error=$e\n$s', name: 'svg');
          }
        }
      }
      start = end;
      if (start < assetPaths.length) {
        await Future.delayed(yieldDuration);
      }
    }
  }

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  Widget _buildView() {
    Widget ws = widget.placeholder ?? const SizedBox();

    // 是否是网络图片
    bool isNetwork = widget.path.startsWith('http') ||
        widget.path.startsWith('https') ||
        widget.path.startsWith('//');

    // 1 图片

    // asset 图片
    if (widget.type == ImageWidgetType.img && !isNetwork) {
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      final int? cw = widget.width != null ? (widget.width! * dpr).round() : null;
      final int? ch = widget.height != null ? (widget.height! * dpr).round() : null;
      ws = Image.asset(
        widget.path,
        fit: widget.fit,
        alignment: widget.alignment ?? Alignment.center,
        color: widget.color,
        cacheWidth: cw,
        cacheHeight: ch,
        filterQuality: FilterQuality.low,
        // frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        //   if (wasSynchronouslyLoaded) {
        //     return child;
        //   }
        //   return AnimatedOpacity(
        //     opacity: frame == null ? 0 : 1,
        //     duration: const Duration(seconds: 1),
        //     curve: Curves.easeOut,
        //     child: widget.placeholder ?? const CircularProgressIndicator(),
        //   );
        // },
      );
    }

    // 网络图片
    else if (widget.type == ImageWidgetType.img && isNetwork) {
      ws = CachedNetworkImage(
        imageUrl: widget.path,
        fit: widget.fit,
        cacheKey: widget.path.hashCode.toString(),
        color: widget.color,
        // imageBuilder: (context, imageProvider) => Container(
        //   decoration: BoxDecoration(
        //     image: DecorationImage(
        //         image: imageProvider,
        //         fit: BoxFit.cover,
        //         colorFilter:
        //             const ColorFilter.mode(Colors.red, BlendMode.colorBurn)),
        //   ),
        // ),
        placeholder: (context, url) =>
            widget.placeholder ??
            const CircularProgressIndicator()
                .tightSize(AppSize.indicator)
                .center(),
        errorWidget: (context, url, error) =>
            widget.errorWidget ?? const Icon(Icons.error),
      );
    }

    //  svg asset 图片
    else if (widget.type == ImageWidgetType.svg && !isNetwork) {
      ws = SvgPicture.asset(
        widget.path,
        fit: widget.fit ?? BoxFit.contain,
        alignment: widget.alignment ?? Alignment.center,
        colorFilter: widget.color != null
            ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
            : null,
        // 捕获 SVG 解析异常，打印具体资源路径，避免 Unhandled Exception 直接崩溃
        errorBuilder: (context, error, stackTrace) {
          // 仅在 Debug 下输出渲染失败信息，避免 Release 额外开销
          DebugUtils.log('【SVG渲染失败】path=${widget.path} error=$error\n$stackTrace', name: 'svg');
          return widget.errorWidget ?? const SizedBox.shrink();
        },
        placeholderBuilder: (BuildContext context) =>
            // 本地 SVG 默认不展示加载圈，避免首屏大量占位动画造成额外开销
            widget.placeholder ?? const SizedBox.shrink(),
      );
    }

    //  svg 网络图片
    else if (widget.type == ImageWidgetType.svg && isNetwork) {
      ws = SvgPicture.network(
        widget.path,
        fit: widget.fit ?? BoxFit.contain,
        alignment: widget.alignment ?? Alignment.center,
        colorFilter: widget.color != null
            ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
            : null,
        // 捕获 SVG 解析/下载异常，打印具体 URL，避免 Unhandled Exception 直接崩溃
        errorBuilder: (context, error, stackTrace) {
          // 仅在 Debug 下输出渲染失败信息，避免 Release 额外开销
          DebugUtils.log('【SVG渲染失败】url=${widget.path} error=$error\n$stackTrace', name: 'svg');
          return widget.errorWidget ?? const SizedBox.shrink();
        },
        placeholderBuilder: (BuildContext context) =>
            widget.placeholder ??
            Center(
              child: const CircularProgressIndicator()
                  .tightSize(AppSize.indicator)
                  .center(),
            ),
      );
    }

    // svg raw
    else if (widget.type == ImageWidgetType.svgRaw) {
      ws = SvgPicture.string(
        widget.path,
        fit: widget.fit ?? BoxFit.contain,
        alignment: widget.alignment ?? Alignment.center,
        colorFilter: widget.color != null
            ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
            : null,
        // 捕获 SVG Raw 解析异常，避免 Unhandled Exception 直接崩溃
        errorBuilder: (context, error, stackTrace) {
          // 仅在 Debug 下输出渲染失败信息，避免 Release 额外开销
          DebugUtils.log('【SVG渲染失败】rawLen=${widget.path.length} error=$error\n$stackTrace', name: 'svg');
          return widget.errorWidget ?? const SizedBox.shrink();
        },
        placeholderBuilder: (BuildContext context) =>
            widget.placeholder ??
            Center(
              child: const CircularProgressIndicator()
                  .tightSize(AppSize.indicator)
                  .center(),
            ),
      );
    }

    // 2 约束
    if (widget.width != null || widget.height != null) {
      ws = ws.tight(
        width: widget.width,
        height: widget.height,
      );
    }

    // 3 圆角
    if (widget.radius != null && (widget.radius ?? 0) > 0) {
      ws = ws.clipRRect(all: widget.radius!);
    }

    // 4 阴影
    // ws = ws.elevation(
    //   widget.elevation ?? AppElevation.image,
    //   borderRadius: BorderRadius.circular(widget.radius ?? AppRadius.img),
    //   shadowColor: context.colors.shadow,
    // );

    return ws;
  }

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }
}
