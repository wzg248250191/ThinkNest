import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../common/index.dart';

class DeskPart extends StatelessWidget {
  const DeskPart({super.key});

  @override
  /// 构建 DeskPart 页面
  Widget build(BuildContext context) {
    return _buildView(context);
  }

  /// 构建桌面试玩按钮区
  Widget _buildView(BuildContext context)
  {
     return <Widget>[
      _buildDeskButton(context),
      TextWidget.label(
        '开始试玩',
        fontSize: 36.sp,
      ).paddingTop(12.h),
     ].toColumn(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
     ).expanded();
      
  }

  /// 构建带背景的桌面按钮
  Widget _buildDeskButton(BuildContext context) {
    final double size = 230.r;
    return _DeskPlayButton(
      size: size,
      onTap: () {},
    );
  }
}

class _DeskPlayButton extends StatefulWidget {
  final double size;
  final VoidCallback onTap;

  const _DeskPlayButton({
    required this.size,
    required this.onTap,
  });

  @override
  State<_DeskPlayButton> createState() => _DeskPlayButtonState();
}

class _DeskPlayButtonState extends State<_DeskPlayButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const double deskBgScale = 270 / 230;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: deskBgScale,
                  child: ImageWidget.svg(
                    AssetsSvgs.deskbgSvg,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.cover,
                  ),
                ),
                ImageWidget.svg(
                  AssetsSvgs.deskSvg,
                  width: 120.r,
                  height: 120.r,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _pressed ? 1 : 0,
                      duration: const Duration(milliseconds: 90),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
