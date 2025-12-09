import 'package:get/get.dart';

class IntegrationController extends GetxController {
  IntegrationController();

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
