import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/widgets.dart';

class DeviceInfoItem extends StatelessWidget {
   DeviceInfoItem({super.key,required this.title});
  
  final String title;//名字
   String? ip;//ip地址
   String? port;//端口号
   String? openCmd;//打开指令
   String? closeCmd;//关闭指令  

  @override
  Widget build(BuildContext context) {
    return <Widget>[
      
    ].toColumn();
  }
}
