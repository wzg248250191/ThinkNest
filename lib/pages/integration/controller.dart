// 一体化页面 Controller 的库入口文件
//
// 说明：
// - 该文件仅负责聚合 import 与 part 列表，本身不直接承载业务实现代码
// - 具体实现分散在多个 part 文件中（枚举/设备配置/分页切换/开关逻辑/最终 Controller 组装）
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:think_nest/common/index.dart';

import 'models/device_info_config.dart';
import 'models/switch_circle_state.dart';
import 'integration_command_repository.dart';
import 'udp_hardware_command.dart';

part 'controller_switch_type.dart';
part 'controller_device_config_mixin.dart';
part 'controller_page_mixin.dart';
part 'controller_switch_mixin.dart';
part 'controller_impl.dart';
