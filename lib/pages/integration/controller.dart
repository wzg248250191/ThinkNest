// 一体化页面 Controller 的库入口文件
//
// 说明：
// - 该文件仅负责聚合 import 与 part 列表，本身不直接承载业务实现代码
// - 具体实现分散在多个 part 文件中（枚举/设备配置/分页切换/开关逻辑/最终 Controller 组装）
import 'dart:async';

import 'package:ducafe_ui_core/ducafe_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../index.dart';
import '/common/index.dart';

part 'controller/controller_switch_type.dart';
part 'controller/controller_device_config_mixin.dart';
part 'controller/controller_page_mixin.dart';
part 'controller/controller_switch_cooldown_mixin.dart';
part 'controller/controller_switch_state_mixin.dart';
part 'controller/controller_switch_actions_mixin.dart';
part 'controller/controller_impl.dart';

const String kIntegrationGetBuilderId = 'integration';
const String kDeviceConfigGetBuilderId = 'device_config';
const List<String> kIntegrationUpdateIds = <String>[kIntegrationGetBuilderId];
const List<String> kDeviceConfigUpdateIds = <String>[kDeviceConfigGetBuilderId];
