//
//  Generated code. Do not modify.
//  source: Common.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use mSGTYPEDescriptor instead')
const MSGTYPE$json = {
  '1': 'MSGTYPE',
  '2': [
    {'1': 'ServerRequest', '2': 0},
    {'1': 'UnityRequest', '2': 1},
    {'1': 'ServerResponse', '2': 2},
    {'1': 'UnityResponse', '2': 3},
    {'1': 'HeartEcho', '2': 4},
    {'1': 'Status', '2': 5},
  ],
};

/// Descriptor for `MSGTYPE`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List mSGTYPEDescriptor = $convert.base64Decode(
    'CgdNU0dUWVBFEhEKDVNlcnZlclJlcXVlc3QQABIQCgxVbml0eVJlcXVlc3QQARISCg5TZXJ2ZX'
    'JSZXNwb25zZRACEhEKDVVuaXR5UmVzcG9uc2UQAxINCglIZWFydEVjaG8QBBIKCgZTdGF0dXMQ'
    'BQ==');

@$core.Deprecated('Use uNITYMSGTYPEDescriptor instead')
const UNITYMSGTYPE$json = {
  '1': 'UNITYMSGTYPE',
  '2': [
    {'1': 'Operation', '2': 0},
    {'1': 'Data', '2': 1},
  ],
};

/// Descriptor for `UNITYMSGTYPE`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List uNITYMSGTYPEDescriptor = $convert.base64Decode(
    'CgxVTklUWU1TR1RZUEUSDQoJT3BlcmF0aW9uEAASCAoERGF0YRAB');

@$core.Deprecated('Use sERVERBEHAVIOURDescriptor instead')
const SERVERBEHAVIOUR$json = {
  '1': 'SERVERBEHAVIOUR',
  '2': [
    {'1': 'Application', '2': 0},
    {'1': 'Volume', '2': 1},
    {'1': 'CourseList', '2': 2},
  ],
};

/// Descriptor for `SERVERBEHAVIOUR`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List sERVERBEHAVIOURDescriptor = $convert.base64Decode(
    'Cg9TRVJWRVJCRUhBVklPVVISDwoLQXBwbGljYXRpb24QABIKCgZWb2x1bWUQAQ==');

@$core.Deprecated('Use operationStatusDescriptor instead')
const OperationStatus$json = {
  '1': 'OperationStatus',
  '2': [
    {'1': 'NullUnityClient', '2': 0},
    {'1': 'NulliPadClient', '2': 1},
    {'1': 'NullCourse', '2': 2},
    {'1': 'CoursePlayisRunning', '2': 3},
    {'1': 'DataformatterError', '2': 4},
    {'1': 'DataTransferError', '2': 5},
  ],
};

/// Descriptor for `OperationStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List operationStatusDescriptor = $convert.base64Decode(
    'Cg9PcGVyYXRpb25TdGF0dXMSEwoPTnVsbFVuaXR5Q2xpZW50EAASEgoOTnVsbGlQYWRDbGllbn'
    'QQARIOCgpOdWxsQ291cnNlEAISFwoTQ291cnNlUGxheWlzUnVubmluZxADEhYKEkRhdGFmb3Jt'
    'YXR0ZXJFcnJvchAEEhUKEURhdGFUcmFuc2ZlckVycm9yEAU=');

@$core.Deprecated('Use cLIENTENDDescriptor instead')
const CLIENTEND$json = {
  '1': 'CLIENTEND',
  '2': [
    {'1': 'WALL', '2': 0},
    {'1': 'Desktop', '2': 1},
  ],
};

/// Descriptor for `CLIENTEND`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List cLIENTENDDescriptor = $convert.base64Decode(
    'CglDTElFTlRFTkQSCAoEV0FMTBAAEgsKB0Rlc2t0b3AQAQ==');

@$core.Deprecated('Use serverMessageDescriptor instead')
const ServerMessage$json = {
  '1': 'ServerMessage',
  '2': [
    {'1': 'ServerBehaviour', '3': 1, '4': 1, '5': 14, '6': '.GameMsg.SERVERBEHAVIOUR', '10': 'ServerBehaviour'},
    {'1': 'VolumeValue', '3': 2, '4': 1, '5': 5, '10': 'VolumeValue'},
    {'1': 'GameName', '3': 3, '4': 1, '5': 9, '10': 'GameName'},
    {'1': 'On', '3': 4, '4': 1, '5': 8, '10': 'On'},
    {'1': 'CourseList', '3': 5, '4': 3, '5': 9, '10': 'CourseList'},
  ],
};

/// Descriptor for `ServerMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List serverMessageDescriptor = $convert.base64Decode(
    'Cg1TZXJ2ZXJNZXNzYWdlEkIKD1NlcnZlckJlaGF2aW91chgBIAEoDjIYLkdhbWVNc2cuU0VSVk'
    'VSQkVIQVZJT1VSUg9TZXJ2ZXJCZWhhdmlvdXISIAoLVm9sdW1lVmFsdWUYAiABKAVSC1ZvbHVt'
    'ZVZhbHVlEhoKCEdhbWVOYW1lGAMgASgJUghHYW1lTmFtZRIOCgJPbhgEIAEoCFICT24=');

@$core.Deprecated('Use unityMessageDescriptor instead')
const UnityMessage$json = {
  '1': 'UnityMessage',
  '2': [
    {'1': 'UnityMSGtype', '3': 1, '4': 1, '5': 14, '6': '.GameMsg.UNITYMSGTYPE', '10': 'UnityMSGtype'},
    {'1': 'UnityData', '3': 2, '4': 1, '5': 11, '6': '.GameMsg.UnityData', '10': 'UnityData'},
    {'1': 'Operation', '3': 3, '4': 1, '5': 9, '10': 'Operation'},
  ],
};

/// Descriptor for `UnityMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unityMessageDescriptor = $convert.base64Decode(
    'CgxVbml0eU1lc3NhZ2USOQoMVW5pdHlNU0d0eXBlGAEgASgOMhUuR2FtZU1zZy5VTklUWU1TR1'
    'RZUEVSDFVuaXR5TVNHdHlwZRIwCglVbml0eURhdGEYAiABKAsyEi5HYW1lTXNnLlVuaXR5RGF0'
    'YVIJVW5pdHlEYXRhEhwKCU9wZXJhdGlvbhgDIAEoCVIJT3BlcmF0aW9u');

@$core.Deprecated('Use unityDataDescriptor instead')
const UnityData$json = {
  '1': 'UnityData',
  '2': [
    {'1': 'Specifying', '3': 1, '4': 1, '5': 9, '10': 'Specifying'},
    {'1': 'Persons', '3': 2, '4': 3, '5': 11, '6': '.GameMsg.Person', '10': 'Persons'},
    {'1': 'Blocks', '3': 3, '4': 3, '5': 11, '6': '.GameMsg.Block', '10': 'Blocks'},
    {'1': 'Default', '3': 4, '4': 1, '5': 9, '10': 'Default'},
  ],
};

/// Descriptor for `UnityData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unityDataDescriptor = $convert.base64Decode(
    'CglVbml0eURhdGESHgoKU3BlY2lmeWluZxgBIAEoCVIKU3BlY2lmeWluZxIpCgdQZXJzb25zGA'
    'IgAygLMg8uR2FtZU1zZy5QZXJzb25SB1BlcnNvbnMSJgoGQmxvY2tzGAMgAygLMg4uR2FtZU1z'
    'Zy5CbG9ja1IGQmxvY2tzEhgKB0RlZmF1bHQYBCABKAlSB0RlZmF1bHQ=');

@$core.Deprecated('Use personDescriptor instead')
const Person$json = {
  '1': 'Person',
  '2': [
    {'1': 'Name', '3': 1, '4': 1, '5': 9, '10': 'Name'},
    {'1': 'Num', '3': 2, '4': 1, '5': 5, '10': 'Num'},
    {'1': 'URL', '3': 3, '4': 1, '5': 9, '10': 'URL'},
    {'1': 'Abilities', '3': 4, '4': 3, '5': 11, '6': '.GameMsg.Ability', '10': 'Abilities'},
  ],
};

/// Descriptor for `Person`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List personDescriptor = $convert.base64Decode(
    'CgZQZXJzb24SEgoETmFtZRgBIAEoCVIETmFtZRIQCgNOdW0YAiABKAVSA051bRIQCgNVUkwYAy'
    'ABKAlSA1VSTBIuCglBYmlsaXRpZXMYBCADKAsyEC5HYW1lTXNnLkFiaWxpdHlSCUFiaWxpdGll'
    'cw==');

@$core.Deprecated('Use abilityDescriptor instead')
const Ability$json = {
  '1': 'Ability',
  '2': [
    {'1': 'Abilityname', '3': 1, '4': 1, '5': 9, '10': 'Abilityname'},
    {'1': 'Value', '3': 2, '4': 1, '5': 2, '10': 'Value'},
  ],
};

/// Descriptor for `Ability`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List abilityDescriptor = $convert.base64Decode(
    'CgdBYmlsaXR5EiAKC0FiaWxpdHluYW1lGAEgASgJUgtBYmlsaXR5bmFtZRIUCgVWYWx1ZRgCIA'
    'EoAlIFVmFsdWU=');

@$core.Deprecated('Use blockDescriptor instead')
const Block$json = {
  '1': 'Block',
  '2': [
    {'1': 'Name', '3': 1, '4': 1, '5': 9, '10': 'Name'},
    {'1': 'Index', '3': 2, '4': 1, '5': 5, '10': 'Index'},
    {'1': 'BlockColumns', '3': 3, '4': 3, '5': 11, '6': '.GameMsg.BlockColumn', '10': 'BlockColumns'},
    {'1': 'BlockColumnDatas', '3': 4, '4': 3, '5': 11, '6': '.GameMsg.BlockColumnData', '10': 'BlockColumnDatas'},
  ],
};

/// Descriptor for `Block`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockDescriptor = $convert.base64Decode(
    'CgVCbG9jaxISCgROYW1lGAEgASgJUgROYW1lEhQKBUluZGV4GAIgASgFUgVJbmRleBI4CgxCbG'
    '9ja0NvbHVtbnMYAyADKAsyFC5HYW1lTXNnLkJsb2NrQ29sdW1uUgxCbG9ja0NvbHVtbnMSRAoQ'
    'QmxvY2tDb2x1bW5EYXRhcxgEIAMoCzIYLkdhbWVNc2cuQmxvY2tDb2x1bW5EYXRhUhBCbG9ja0'
    'NvbHVtbkRhdGFz');

@$core.Deprecated('Use blockColumnDescriptor instead')
const BlockColumn$json = {
  '1': 'BlockColumn',
  '2': [
    {'1': 'Name', '3': 1, '4': 1, '5': 9, '10': 'Name'},
    {'1': 'Type', '3': 2, '4': 1, '5': 9, '10': 'Type'},
    {'1': 'Sort', '3': 3, '4': 1, '5': 9, '10': 'Sort'},
    {'1': 'Show', '3': 4, '4': 1, '5': 8, '10': 'Show'},
    {'1': 'Suffix', '3': 5, '4': 1, '5': 9, '10': 'Suffix'},
    {'1': 'CountMode', '3': 6, '4': 1, '5': 9, '10': 'CountMode'},
    {'1': 'CountColumDataByIndex', '3': 7, '4': 1, '5': 5, '10': 'CountColumDataByIndex'},
  ],
};

/// Descriptor for `BlockColumn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockColumnDescriptor = $convert.base64Decode(
    'CgtCbG9ja0NvbHVtbhISCgROYW1lGAEgASgJUgROYW1lEhIKBFR5cGUYAiABKAlSBFR5cGUSEg'
    'oEU29ydBgDIAEoCVIEU29ydBISCgRTaG93GAQgASgIUgRTaG93EhYKBlN1ZmZpeBgFIAEoCVIG'
    'U3VmZml4EhwKCUNvdW50TW9kZRgGIAEoCVIJQ291bnRNb2RlEjQKFUNvdW50Q29sdW1EYXRhQn'
    'lJbmRleBgHIAEoBVIVQ291bnRDb2x1bURhdGFCeUluZGV4');

@$core.Deprecated('Use blockColumnDataDescriptor instead')
const BlockColumnData$json = {
  '1': 'BlockColumnData',
  '2': [
    {'1': 'ColumnData', '3': 1, '4': 1, '5': 9, '10': 'ColumnData'},
    {'1': 'Separator', '3': 2, '4': 1, '5': 9, '10': 'Separator'},
  ],
};

/// Descriptor for `BlockColumnData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List blockColumnDataDescriptor = $convert.base64Decode(
    'Cg9CbG9ja0NvbHVtbkRhdGESHgoKQ29sdW1uRGF0YRgBIAEoCVIKQ29sdW1uRGF0YRIcCglTZX'
    'BhcmF0b3IYAiABKAlSCVNlcGFyYXRvcg==');

@$core.Deprecated('Use mESSAGEDescriptor instead')
const MESSAGE$json = {
  '1': 'MESSAGE',
  '2': [
    {'1': 'MSGtype', '3': 1, '4': 1, '5': 14, '6': '.GameMsg.MSGTYPE', '10': 'MSGtype'},
    {'1': 'UnityMessage', '3': 2, '4': 1, '5': 11, '6': '.GameMsg.UnityMessage', '10': 'UnityMessage'},
    {'1': 'ServerMessage', '3': 3, '4': 1, '5': 11, '6': '.GameMsg.ServerMessage', '10': 'ServerMessage'},
    {'1': 'MSGstatus', '3': 4, '4': 1, '5': 11, '6': '.GameMsg.MSGStatus', '10': 'MSGstatus'},
    {'1': 'EchoData', '3': 5, '4': 1, '5': 11, '6': '.GameMsg.EchoData', '10': 'EchoData'},
  ],
};

/// Descriptor for `MESSAGE`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mESSAGEDescriptor = $convert.base64Decode(
    'CgdNRVNTQUdFEioKB01TR3R5cGUYASABKA4yEC5HYW1lTXNnLk1TR1RZUEVSB01TR3R5cGUSOQ'
    'oMVW5pdHlNZXNzYWdlGAIgASgLMhUuR2FtZU1zZy5Vbml0eU1lc3NhZ2VSDFVuaXR5TWVzc2Fn'
    'ZRI8Cg1TZXJ2ZXJNZXNzYWdlGAMgASgLMhYuR2FtZU1zZy5TZXJ2ZXJNZXNzYWdlUg1TZXJ2ZX'
    'JNZXNzYWdlEjAKCU1TR3N0YXR1cxgEIAEoCzISLkdhbWVNc2cuTVNHU3RhdHVzUglNU0dzdGF0'
    'dXMSLQoIRWNob0RhdGEYBSABKAsyES5HYW1lTXNnLkVjaG9EYXRhUghFY2hvRGF0YQ==');

@$core.Deprecated('Use mSGStatusDescriptor instead')
const MSGStatus$json = {
  '1': 'MSGStatus',
  '2': [
    {'1': 'operationstatus', '3': 1, '4': 1, '5': 14, '6': '.GameMsg.OperationStatus', '10': 'operationstatus'},
    {'1': 'SQID', '3': 2, '4': 1, '5': 5, '10': 'SQID'},
    {'1': 'Info', '3': 3, '4': 1, '5': 9, '10': 'Info'},
  ],
};

/// Descriptor for `MSGStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mSGStatusDescriptor = $convert.base64Decode(
    'CglNU0dTdGF0dXMSQgoPb3BlcmF0aW9uc3RhdHVzGAEgASgOMhguR2FtZU1zZy5PcGVyYXRpb2'
    '5TdGF0dXNSD29wZXJhdGlvbnN0YXR1cxISCgRTUUlEGAIgASgFUgRTUUlEEhIKBEluZm8YAyAB'
    'KAlSBEluZm8=');

@$core.Deprecated('Use echoDataDescriptor instead')
const EchoData$json = {
  '1': 'EchoData',
  '2': [
    {'1': 'ClientEnd', '3': 1, '4': 1, '5': 14, '6': '.GameMsg.CLIENTEND', '10': 'ClientEnd'},
    {'1': 'Echomsg', '3': 2, '4': 1, '5': 9, '10': 'Echomsg'},
  ],
};

/// Descriptor for `EchoData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List echoDataDescriptor = $convert.base64Decode(
    'CghFY2hvRGF0YRIwCglDbGllbnRFbmQYASABKA4yEi5HYW1lTXNnLkNMSUVOVEVORFIJQ2xpZW'
    '50RW5kEhgKB0VjaG9tc2cYAiABKAlSB0VjaG9tc2c=');
