import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';


import '../index.dart';

/// 下拉菜单
class DropdownWidget extends StatelessWidget {
  /// 点击菜单
  final Function(KeyValueModel? val)? onChanged;

  /// 数据项列表
  final List<KeyValueModel>? items;

  /// 选中数据值
  final KeyValueModel? selectedValue;

  /// 提示文字
  final String? hintText;

  /// 图标颜色
  final Color? iconColor;

  /// 按钮 padding
  final EdgeInsetsGeometry? buttonPadding;

  /// 按钮高度
  final double? buttonHeight;

  /// 每一项高度
  final double? itemHeight;

  /// 文本字号
  final double? fontSize;

  const DropdownWidget({
    super.key,
    this.items,
    this.selectedValue,
    this.hintText,
    this.onChanged,
    this.buttonPadding,
    this.iconColor,
    this.buttonHeight,
    this.itemHeight,
    this.fontSize,
  });

  Widget _buildView() {
    final double resolvedButtonHeight = buttonHeight ?? 48;
    final double resolvedItemHeight = itemHeight ?? 48;
    return DropdownButtonHideUnderline(
      child: DropdownButton2<KeyValueModel>(
        // 扩展
        isExpanded: true,
        buttonStyleData: ButtonStyleData(
          height: resolvedButtonHeight,
          padding: buttonPadding,
        ),
        menuItemStyleData: MenuItemStyleData(
          height: resolvedItemHeight,
        ),
        // 提示组件
        hint: Row(
          children: [
            Expanded(
              child: TextWidget.label(
                hintText ?? 'Select Item',
                fontSize: fontSize,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // 下拉项列表
        items: items
            ?.map((item) => DropdownMenuItem<KeyValueModel>(
                  value: item,
                  child: TextWidget.label(
                    item.value,
                    fontSize: fontSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        selectedItemBuilder: (context) {
          final list = items;
          if (list == null) {
            return const <Widget>[];
          }
          return list
              .map(
                (item) => Align(
                  alignment: Alignment.centerLeft,
                  child: TextWidget.label(
                    item.value,
                    fontSize: fontSize,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList();
        },
        // 选中项
        value: selectedValue,
        // 改变事件
        onChanged: onChanged,
        // // 图标
        // icon: IconWidget.icon(
        //   Icons.expand_more,
        //   color: iconColor ?? AppColors.primary,
        // ),
        // // 按钮 padding
        // buttonPadding: buttonPadding ??
        //     EdgeInsets.symmetric(horizontal: AppSpace.iconTextSmail),
        // // 偏移
        // offset: const Offset(0, 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildView();
  }
}
