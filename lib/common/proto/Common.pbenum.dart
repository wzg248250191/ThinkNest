//
//  Generated code. Do not modify.
//  source: Common.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// ---------------���ݰ����ݿͻ��˵����� --------------------
class MSGTYPE extends $pb.ProtobufEnum {
  static const MSGTYPE ServerRequest = MSGTYPE._(0, _omitEnumNames ? '' : 'ServerRequest');
  static const MSGTYPE UnityRequest = MSGTYPE._(1, _omitEnumNames ? '' : 'UnityRequest');
  static const MSGTYPE ServerResponse = MSGTYPE._(2, _omitEnumNames ? '' : 'ServerResponse');
  static const MSGTYPE UnityResponse = MSGTYPE._(3, _omitEnumNames ? '' : 'UnityResponse');
  static const MSGTYPE HeartEcho = MSGTYPE._(4, _omitEnumNames ? '' : 'HeartEcho');
  static const MSGTYPE Status = MSGTYPE._(5, _omitEnumNames ? '' : 'Status');

  static const $core.List<MSGTYPE> values = <MSGTYPE> [
    ServerRequest,
    UnityRequest,
    ServerResponse,
    UnityResponse,
    HeartEcho,
    Status,
  ];

  static final $core.Map<$core.int, MSGTYPE> _byValue = $pb.ProtobufEnum.initByValue(values);
  static MSGTYPE? valueOf($core.int value) => _byValue[value];

  const MSGTYPE._($core.int v, $core.String n) : super(v, n);
}

class UNITYMSGTYPE extends $pb.ProtobufEnum {
  static const UNITYMSGTYPE Operation = UNITYMSGTYPE._(0, _omitEnumNames ? '' : 'Operation');
  static const UNITYMSGTYPE Data = UNITYMSGTYPE._(1, _omitEnumNames ? '' : 'Data');

  static const $core.List<UNITYMSGTYPE> values = <UNITYMSGTYPE> [
    Operation,
    Data,
  ];

  static final $core.Map<$core.int, UNITYMSGTYPE> _byValue = $pb.ProtobufEnum.initByValue(values);
  static UNITYMSGTYPE? valueOf($core.int value) => _byValue[value];

  const UNITYMSGTYPE._($core.int v, $core.String n) : super(v, n);
}

class SERVERBEHAVIOUR extends $pb.ProtobufEnum {
  static const SERVERBEHAVIOUR Application = SERVERBEHAVIOUR._(0, _omitEnumNames ? '' : 'Application');
  static const SERVERBEHAVIOUR Volume = SERVERBEHAVIOUR._(1, _omitEnumNames ? '' : 'Volume');

  static const $core.List<SERVERBEHAVIOUR> values = <SERVERBEHAVIOUR> [
    Application,
    Volume,
  ];

  static final $core.Map<$core.int, SERVERBEHAVIOUR> _byValue = $pb.ProtobufEnum.initByValue(values);
  static SERVERBEHAVIOUR? valueOf($core.int value) => _byValue[value];

  const SERVERBEHAVIOUR._($core.int v, $core.String n) : super(v, n);
}

class OperationStatus extends $pb.ProtobufEnum {
  static const OperationStatus NullUnityClient = OperationStatus._(0, _omitEnumNames ? '' : 'NullUnityClient');
  static const OperationStatus NulliPadClient = OperationStatus._(1, _omitEnumNames ? '' : 'NulliPadClient');
  static const OperationStatus NullCourse = OperationStatus._(2, _omitEnumNames ? '' : 'NullCourse');
  static const OperationStatus CoursePlayisRunning = OperationStatus._(3, _omitEnumNames ? '' : 'CoursePlayisRunning');
  static const OperationStatus DataformatterError = OperationStatus._(4, _omitEnumNames ? '' : 'DataformatterError');
  static const OperationStatus DataTransferError = OperationStatus._(5, _omitEnumNames ? '' : 'DataTransferError');

  static const $core.List<OperationStatus> values = <OperationStatus> [
    NullUnityClient,
    NulliPadClient,
    NullCourse,
    CoursePlayisRunning,
    DataformatterError,
    DataTransferError,
  ];

  static final $core.Map<$core.int, OperationStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static OperationStatus? valueOf($core.int value) => _byValue[value];

  const OperationStatus._($core.int v, $core.String n) : super(v, n);
}

class CLIENTEND extends $pb.ProtobufEnum {
  static const CLIENTEND WALL = CLIENTEND._(0, _omitEnumNames ? '' : 'WALL');
  static const CLIENTEND Desktop = CLIENTEND._(1, _omitEnumNames ? '' : 'Desktop');

  static const $core.List<CLIENTEND> values = <CLIENTEND> [
    WALL,
    Desktop,
  ];

  static final $core.Map<$core.int, CLIENTEND> _byValue = $pb.ProtobufEnum.initByValue(values);
  static CLIENTEND? valueOf($core.int value) => _byValue[value];

  const CLIENTEND._($core.int v, $core.String n) : super(v, n);
}


const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
