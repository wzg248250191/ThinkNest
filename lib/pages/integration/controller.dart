import 'package:get/get.dart';
import 'models/switch_circle_state.dart';

class IntegrationController extends GetxController {
  IntegrationController();

  //总开关
  SwitchCircleState mainState = const SwitchCircleState(enabled: true, isOn: true);
  //墙面开关
  SwitchCircleState wallState = const SwitchCircleState(enabled: true, isOn: false);
  //桌面开关
  SwitchCircleState deskState = const SwitchCircleState(enabled: true, isOn: false);
  //灯光开关
   SwitchCircleState lightState = const SwitchCircleState(enabled: false, isOn: false);
   //窗帘开关
  SwitchCircleState curtainState = const SwitchCircleState(enabled: false, isOn: false);

  void setMainState(SwitchCircleState value) {
    mainState = value;
    update(["integration"]);
  }

  void setWallState(SwitchCircleState value) {
    wallState = value;
    update(["integration"]);
  }

void setDeskState(SwitchCircleState value) {
    deskState = value;
    update(["integration"]);
  }

  void setLightState(SwitchCircleState value) {
    lightState = value;
    update(["integration"]);
  }

  
  void setCurtainState(SwitchCircleState value) {
    curtainState = value;
    update(["integration"]);
  }

  _initData() {
    update(["integration"]);
  }

  void onTap() {}

  // @override
  // void onInit() {
  //   super.onInit();
  // }

  @override
  void onReady() {
    super.onReady();
    _initData();
  }

  // @override
  // void onClose() {
  //   super.onClose();
  // }
}
