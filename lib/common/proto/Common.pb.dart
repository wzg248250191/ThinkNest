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

import 'Common.pbenum.dart';

export 'Common.pbenum.dart';

/// --------------- �뷽������̨�����İ� --------------------
class ServerMessage extends $pb.GeneratedMessage {
  factory ServerMessage({
    SERVERBEHAVIOUR? serverBehaviour,
    $core.int? volumeValue,
    $core.String? gameName,
    $core.bool? on,
  }) {
    final $result = create();
    if (serverBehaviour != null) {
      $result.serverBehaviour = serverBehaviour;
    }
    if (volumeValue != null) {
      $result.volumeValue = volumeValue;
    }
    if (gameName != null) {
      $result.gameName = gameName;
    }
    if (on != null) {
      $result.on = on;
    }
    return $result;
  }
  ServerMessage._() : super();
  factory ServerMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ServerMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ServerMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..e<SERVERBEHAVIOUR>(1, _omitFieldNames ? '' : 'ServerBehaviour', $pb.PbFieldType.OE, protoName: 'ServerBehaviour', defaultOrMaker: SERVERBEHAVIOUR.Application, valueOf: SERVERBEHAVIOUR.valueOf, enumValues: SERVERBEHAVIOUR.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'VolumeValue', $pb.PbFieldType.O3, protoName: 'VolumeValue')
    ..aOS(3, _omitFieldNames ? '' : 'GameName', protoName: 'GameName')
    ..aOB(4, _omitFieldNames ? '' : 'On', protoName: 'On')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ServerMessage clone() => ServerMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ServerMessage copyWith(void Function(ServerMessage) updates) => super.copyWith((message) => updates(message as ServerMessage)) as ServerMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ServerMessage create() => ServerMessage._();
  ServerMessage createEmptyInstance() => create();
  static $pb.PbList<ServerMessage> createRepeated() => $pb.PbList<ServerMessage>();
  @$core.pragma('dart2js:noInline')
  static ServerMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServerMessage>(create);
  static ServerMessage? _defaultInstance;

  @$pb.TagNumber(1)
  SERVERBEHAVIOUR get serverBehaviour => $_getN(0);
  @$pb.TagNumber(1)
  set serverBehaviour(SERVERBEHAVIOUR v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasServerBehaviour() => $_has(0);
  @$pb.TagNumber(1)
  void clearServerBehaviour() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get volumeValue => $_getIZ(1);
  @$pb.TagNumber(2)
  set volumeValue($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasVolumeValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearVolumeValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get gameName => $_getSZ(2);
  @$pb.TagNumber(3)
  set gameName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasGameName() => $_has(2);
  @$pb.TagNumber(3)
  void clearGameName() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get on => $_getBF(3);
  @$pb.TagNumber(4)
  set on($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasOn() => $_has(3);
  @$pb.TagNumber(4)
  void clearOn() => clearField(4);
}

class UnityMessage extends $pb.GeneratedMessage {
  factory UnityMessage({
    UNITYMSGTYPE? unityMSGtype,
    UnityData? unityData,
    $core.String? operation,
  }) {
    final $result = create();
    if (unityMSGtype != null) {
      $result.unityMSGtype = unityMSGtype;
    }
    if (unityData != null) {
      $result.unityData = unityData;
    }
    if (operation != null) {
      $result.operation = operation;
    }
    return $result;
  }
  UnityMessage._() : super();
  factory UnityMessage.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnityMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnityMessage', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..e<UNITYMSGTYPE>(1, _omitFieldNames ? '' : 'UnityMSGtype', $pb.PbFieldType.OE, protoName: 'UnityMSGtype', defaultOrMaker: UNITYMSGTYPE.Operation, valueOf: UNITYMSGTYPE.valueOf, enumValues: UNITYMSGTYPE.values)
    ..aOM<UnityData>(2, _omitFieldNames ? '' : 'UnityData', protoName: 'UnityData', subBuilder: UnityData.create)
    ..aOS(3, _omitFieldNames ? '' : 'Operation', protoName: 'Operation')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnityMessage clone() => UnityMessage()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnityMessage copyWith(void Function(UnityMessage) updates) => super.copyWith((message) => updates(message as UnityMessage)) as UnityMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnityMessage create() => UnityMessage._();
  UnityMessage createEmptyInstance() => create();
  static $pb.PbList<UnityMessage> createRepeated() => $pb.PbList<UnityMessage>();
  @$core.pragma('dart2js:noInline')
  static UnityMessage getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnityMessage>(create);
  static UnityMessage? _defaultInstance;

  @$pb.TagNumber(1)
  UNITYMSGTYPE get unityMSGtype => $_getN(0);
  @$pb.TagNumber(1)
  set unityMSGtype(UNITYMSGTYPE v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasUnityMSGtype() => $_has(0);
  @$pb.TagNumber(1)
  void clearUnityMSGtype() => clearField(1);

  @$pb.TagNumber(2)
  UnityData get unityData => $_getN(1);
  @$pb.TagNumber(2)
  set unityData(UnityData v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUnityData() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnityData() => clearField(2);
  @$pb.TagNumber(2)
  UnityData ensureUnityData() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get operation => $_getSZ(2);
  @$pb.TagNumber(3)
  set operation($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasOperation() => $_has(2);
  @$pb.TagNumber(3)
  void clearOperation() => clearField(3);
}

/// -------δ֪�����ݣ���ҪiPad�˽���-------
class UnityData extends $pb.GeneratedMessage {
  factory UnityData({
    $core.String? specifying,
    $core.Iterable<Person>? persons,
    $core.Iterable<Block>? blocks,
    $core.String? default_4,
  }) {
    final $result = create();
    if (specifying != null) {
      $result.specifying = specifying;
    }
    if (persons != null) {
      $result.persons.addAll(persons);
    }
    if (blocks != null) {
      $result.blocks.addAll(blocks);
    }
    if (default_4 != null) {
      $result.default_4 = default_4;
    }
    return $result;
  }
  UnityData._() : super();
  factory UnityData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory UnityData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'UnityData', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Specifying', protoName: 'Specifying')
    ..pc<Person>(2, _omitFieldNames ? '' : 'Persons', $pb.PbFieldType.PM, protoName: 'Persons', subBuilder: Person.create)
    ..pc<Block>(3, _omitFieldNames ? '' : 'Blocks', $pb.PbFieldType.PM, protoName: 'Blocks', subBuilder: Block.create)
    ..aOS(4, _omitFieldNames ? '' : 'Default', protoName: 'Default')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  UnityData clone() => UnityData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  UnityData copyWith(void Function(UnityData) updates) => super.copyWith((message) => updates(message as UnityData)) as UnityData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnityData create() => UnityData._();
  UnityData createEmptyInstance() => create();
  static $pb.PbList<UnityData> createRepeated() => $pb.PbList<UnityData>();
  @$core.pragma('dart2js:noInline')
  static UnityData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnityData>(create);
  static UnityData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get specifying => $_getSZ(0);
  @$pb.TagNumber(1)
  set specifying($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasSpecifying() => $_has(0);
  @$pb.TagNumber(1)
  void clearSpecifying() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<Person> get persons => $_getList(1);

  @$pb.TagNumber(3)
  $core.List<Block> get blocks => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get default_4 => $_getSZ(3);
  @$pb.TagNumber(4)
  set default_4($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDefault_4() => $_has(3);
  @$pb.TagNumber(4)
  void clearDefault_4() => clearField(4);
}

class Person extends $pb.GeneratedMessage {
  factory Person({
    $core.String? name,
    $core.int? num,
    $core.String? uRL,
    $core.Iterable<Ability>? abilities,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (num != null) {
      $result.num = num;
    }
    if (uRL != null) {
      $result.uRL = uRL;
    }
    if (abilities != null) {
      $result.abilities.addAll(abilities);
    }
    return $result;
  }
  Person._() : super();
  factory Person.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Person.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Person', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Name', protoName: 'Name')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'Num', $pb.PbFieldType.O3, protoName: 'Num')
    ..aOS(3, _omitFieldNames ? '' : 'URL', protoName: 'URL')
    ..pc<Ability>(4, _omitFieldNames ? '' : 'Abilities', $pb.PbFieldType.PM, protoName: 'Abilities', subBuilder: Ability.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Person clone() => Person()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Person copyWith(void Function(Person) updates) => super.copyWith((message) => updates(message as Person)) as Person;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Person create() => Person._();
  Person createEmptyInstance() => create();
  static $pb.PbList<Person> createRepeated() => $pb.PbList<Person>();
  @$core.pragma('dart2js:noInline')
  static Person getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Person>(create);
  static Person? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get num => $_getIZ(1);
  @$pb.TagNumber(2)
  set num($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasNum() => $_has(1);
  @$pb.TagNumber(2)
  void clearNum() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get uRL => $_getSZ(2);
  @$pb.TagNumber(3)
  set uRL($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasURL() => $_has(2);
  @$pb.TagNumber(3)
  void clearURL() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<Ability> get abilities => $_getList(3);
}

class Ability extends $pb.GeneratedMessage {
  factory Ability({
    $core.String? abilityname,
    $core.double? value,
  }) {
    final $result = create();
    if (abilityname != null) {
      $result.abilityname = abilityname;
    }
    if (value != null) {
      $result.value = value;
    }
    return $result;
  }
  Ability._() : super();
  factory Ability.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Ability.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Ability', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Abilityname', protoName: 'Abilityname')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'Value', $pb.PbFieldType.OF, protoName: 'Value')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Ability clone() => Ability()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Ability copyWith(void Function(Ability) updates) => super.copyWith((message) => updates(message as Ability)) as Ability;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ability create() => Ability._();
  Ability createEmptyInstance() => create();
  static $pb.PbList<Ability> createRepeated() => $pb.PbList<Ability>();
  @$core.pragma('dart2js:noInline')
  static Ability getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ability>(create);
  static Ability? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get abilityname => $_getSZ(0);
  @$pb.TagNumber(1)
  set abilityname($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasAbilityname() => $_has(0);
  @$pb.TagNumber(1)
  void clearAbilityname() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get value => $_getN(1);
  @$pb.TagNumber(2)
  set value($core.double v) { $_setFloat(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);
}

/// -------Ĭ��ÿ��blockcolumn,��һ��Ϊѧ����Num,��ֹ����������ƥ�����-------
class Block extends $pb.GeneratedMessage {
  factory Block({
    $core.String? name,
    $core.int? index,
    $core.Iterable<BlockColumn>? blockColumns,
    $core.Iterable<BlockColumnData>? blockColumnDatas,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (index != null) {
      $result.index = index;
    }
    if (blockColumns != null) {
      $result.blockColumns.addAll(blockColumns);
    }
    if (blockColumnDatas != null) {
      $result.blockColumnDatas.addAll(blockColumnDatas);
    }
    return $result;
  }
  Block._() : super();
  factory Block.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Block.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Block', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Name', protoName: 'Name')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'Index', $pb.PbFieldType.O3, protoName: 'Index')
    ..pc<BlockColumn>(3, _omitFieldNames ? '' : 'BlockColumns', $pb.PbFieldType.PM, protoName: 'BlockColumns', subBuilder: BlockColumn.create)
    ..pc<BlockColumnData>(4, _omitFieldNames ? '' : 'BlockColumnDatas', $pb.PbFieldType.PM, protoName: 'BlockColumnDatas', subBuilder: BlockColumnData.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Block clone() => Block()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Block copyWith(void Function(Block) updates) => super.copyWith((message) => updates(message as Block)) as Block;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Block create() => Block._();
  Block createEmptyInstance() => create();
  static $pb.PbList<Block> createRepeated() => $pb.PbList<Block>();
  @$core.pragma('dart2js:noInline')
  static Block getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Block>(create);
  static Block? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get index => $_getIZ(1);
  @$pb.TagNumber(2)
  set index($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIndex() => $_has(1);
  @$pb.TagNumber(2)
  void clearIndex() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<BlockColumn> get blockColumns => $_getList(2);

  @$pb.TagNumber(4)
  $core.List<BlockColumnData> get blockColumnDatas => $_getList(3);
}

class BlockColumn extends $pb.GeneratedMessage {
  factory BlockColumn({
    $core.String? name,
    $core.String? type,
    $core.String? sort,
    $core.bool? show,
    $core.String? suffix,
    $core.String? countMode,
    $core.int? countColumDataByIndex,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (type != null) {
      $result.type = type;
    }
    if (sort != null) {
      $result.sort = sort;
    }
    if (show != null) {
      $result.show = show;
    }
    if (suffix != null) {
      $result.suffix = suffix;
    }
    if (countMode != null) {
      $result.countMode = countMode;
    }
    if (countColumDataByIndex != null) {
      $result.countColumDataByIndex = countColumDataByIndex;
    }
    return $result;
  }
  BlockColumn._() : super();
  factory BlockColumn.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockColumn.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockColumn', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'Name', protoName: 'Name')
    ..aOS(2, _omitFieldNames ? '' : 'Type', protoName: 'Type')
    ..aOS(3, _omitFieldNames ? '' : 'Sort', protoName: 'Sort')
    ..aOB(4, _omitFieldNames ? '' : 'Show', protoName: 'Show')
    ..aOS(5, _omitFieldNames ? '' : 'Suffix', protoName: 'Suffix')
    ..aOS(6, _omitFieldNames ? '' : 'CountMode', protoName: 'CountMode')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'CountColumDataByIndex', $pb.PbFieldType.O3, protoName: 'CountColumDataByIndex')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockColumn clone() => BlockColumn()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockColumn copyWith(void Function(BlockColumn) updates) => super.copyWith((message) => updates(message as BlockColumn)) as BlockColumn;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockColumn create() => BlockColumn._();
  BlockColumn createEmptyInstance() => create();
  static $pb.PbList<BlockColumn> createRepeated() => $pb.PbList<BlockColumn>();
  @$core.pragma('dart2js:noInline')
  static BlockColumn getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockColumn>(create);
  static BlockColumn? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get sort => $_getSZ(2);
  @$pb.TagNumber(3)
  set sort($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasSort() => $_has(2);
  @$pb.TagNumber(3)
  void clearSort() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get show => $_getBF(3);
  @$pb.TagNumber(4)
  set show($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasShow() => $_has(3);
  @$pb.TagNumber(4)
  void clearShow() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get suffix => $_getSZ(4);
  @$pb.TagNumber(5)
  set suffix($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasSuffix() => $_has(4);
  @$pb.TagNumber(5)
  void clearSuffix() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get countMode => $_getSZ(5);
  @$pb.TagNumber(6)
  set countMode($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCountMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearCountMode() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get countColumDataByIndex => $_getIZ(6);
  @$pb.TagNumber(7)
  set countColumDataByIndex($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasCountColumDataByIndex() => $_has(6);
  @$pb.TagNumber(7)
  void clearCountColumDataByIndex() => clearField(7);
}

class BlockColumnData extends $pb.GeneratedMessage {
  factory BlockColumnData({
    $core.String? columnData,
    $core.String? separator,
  }) {
    final $result = create();
    if (columnData != null) {
      $result.columnData = columnData;
    }
    if (separator != null) {
      $result.separator = separator;
    }
    return $result;
  }
  BlockColumnData._() : super();
  factory BlockColumnData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory BlockColumnData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'BlockColumnData', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'ColumnData', protoName: 'ColumnData')
    ..aOS(2, _omitFieldNames ? '' : 'Separator', protoName: 'Separator')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  BlockColumnData clone() => BlockColumnData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  BlockColumnData copyWith(void Function(BlockColumnData) updates) => super.copyWith((message) => updates(message as BlockColumnData)) as BlockColumnData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BlockColumnData create() => BlockColumnData._();
  BlockColumnData createEmptyInstance() => create();
  static $pb.PbList<BlockColumnData> createRepeated() => $pb.PbList<BlockColumnData>();
  @$core.pragma('dart2js:noInline')
  static BlockColumnData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BlockColumnData>(create);
  static BlockColumnData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get columnData => $_getSZ(0);
  @$pb.TagNumber(1)
  set columnData($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasColumnData() => $_has(0);
  @$pb.TagNumber(1)
  void clearColumnData() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get separator => $_getSZ(1);
  @$pb.TagNumber(2)
  set separator($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSeparator() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeparator() => clearField(2);
}

/// --------------- Heart����ʱû����Ϣ�� ------------------
class MESSAGE extends $pb.GeneratedMessage {
  factory MESSAGE({
    MSGTYPE? mSGtype,
    UnityMessage? unityMessage,
    ServerMessage? serverMessage,
    MSGStatus? mSGstatus,
    EchoData? echoData,
  }) {
    final $result = create();
    if (mSGtype != null) {
      $result.mSGtype = mSGtype;
    }
    if (unityMessage != null) {
      $result.unityMessage = unityMessage;
    }
    if (serverMessage != null) {
      $result.serverMessage = serverMessage;
    }
    if (mSGstatus != null) {
      $result.mSGstatus = mSGstatus;
    }
    if (echoData != null) {
      $result.echoData = echoData;
    }
    return $result;
  }
  MESSAGE._() : super();
  factory MESSAGE.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MESSAGE.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MESSAGE', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..e<MSGTYPE>(1, _omitFieldNames ? '' : 'MSGtype', $pb.PbFieldType.OE, protoName: 'MSGtype', defaultOrMaker: MSGTYPE.ServerRequest, valueOf: MSGTYPE.valueOf, enumValues: MSGTYPE.values)
    ..aOM<UnityMessage>(2, _omitFieldNames ? '' : 'UnityMessage', protoName: 'UnityMessage', subBuilder: UnityMessage.create)
    ..aOM<ServerMessage>(3, _omitFieldNames ? '' : 'ServerMessage', protoName: 'ServerMessage', subBuilder: ServerMessage.create)
    ..aOM<MSGStatus>(4, _omitFieldNames ? '' : 'MSGstatus', protoName: 'MSGstatus', subBuilder: MSGStatus.create)
    ..aOM<EchoData>(5, _omitFieldNames ? '' : 'EchoData', protoName: 'EchoData', subBuilder: EchoData.create)
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MESSAGE clone() => MESSAGE()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MESSAGE copyWith(void Function(MESSAGE) updates) => super.copyWith((message) => updates(message as MESSAGE)) as MESSAGE;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MESSAGE create() => MESSAGE._();
  MESSAGE createEmptyInstance() => create();
  static $pb.PbList<MESSAGE> createRepeated() => $pb.PbList<MESSAGE>();
  @$core.pragma('dart2js:noInline')
  static MESSAGE getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MESSAGE>(create);
  static MESSAGE? _defaultInstance;

  @$pb.TagNumber(1)
  MSGTYPE get mSGtype => $_getN(0);
  @$pb.TagNumber(1)
  set mSGtype(MSGTYPE v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasMSGtype() => $_has(0);
  @$pb.TagNumber(1)
  void clearMSGtype() => clearField(1);

  @$pb.TagNumber(2)
  UnityMessage get unityMessage => $_getN(1);
  @$pb.TagNumber(2)
  set unityMessage(UnityMessage v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasUnityMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnityMessage() => clearField(2);
  @$pb.TagNumber(2)
  UnityMessage ensureUnityMessage() => $_ensure(1);

  @$pb.TagNumber(3)
  ServerMessage get serverMessage => $_getN(2);
  @$pb.TagNumber(3)
  set serverMessage(ServerMessage v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasServerMessage() => $_has(2);
  @$pb.TagNumber(3)
  void clearServerMessage() => clearField(3);
  @$pb.TagNumber(3)
  ServerMessage ensureServerMessage() => $_ensure(2);

  @$pb.TagNumber(4)
  MSGStatus get mSGstatus => $_getN(3);
  @$pb.TagNumber(4)
  set mSGstatus(MSGStatus v) { setField(4, v); }
  @$pb.TagNumber(4)
  $core.bool hasMSGstatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearMSGstatus() => clearField(4);
  @$pb.TagNumber(4)
  MSGStatus ensureMSGstatus() => $_ensure(3);

  @$pb.TagNumber(5)
  EchoData get echoData => $_getN(4);
  @$pb.TagNumber(5)
  set echoData(EchoData v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasEchoData() => $_has(4);
  @$pb.TagNumber(5)
  void clearEchoData() => clearField(5);
  @$pb.TagNumber(5)
  EchoData ensureEchoData() => $_ensure(4);
}

class MSGStatus extends $pb.GeneratedMessage {
  factory MSGStatus({
    OperationStatus? operationstatus,
    $core.int? sQID,
    $core.String? info,
  }) {
    final $result = create();
    if (operationstatus != null) {
      $result.operationstatus = operationstatus;
    }
    if (sQID != null) {
      $result.sQID = sQID;
    }
    if (info != null) {
      $result.info = info;
    }
    return $result;
  }
  MSGStatus._() : super();
  factory MSGStatus.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory MSGStatus.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MSGStatus', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..e<OperationStatus>(1, _omitFieldNames ? '' : 'operationstatus', $pb.PbFieldType.OE, defaultOrMaker: OperationStatus.NullUnityClient, valueOf: OperationStatus.valueOf, enumValues: OperationStatus.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'SQID', $pb.PbFieldType.O3, protoName: 'SQID')
    ..aOS(3, _omitFieldNames ? '' : 'Info', protoName: 'Info')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  MSGStatus clone() => MSGStatus()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  MSGStatus copyWith(void Function(MSGStatus) updates) => super.copyWith((message) => updates(message as MSGStatus)) as MSGStatus;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MSGStatus create() => MSGStatus._();
  MSGStatus createEmptyInstance() => create();
  static $pb.PbList<MSGStatus> createRepeated() => $pb.PbList<MSGStatus>();
  @$core.pragma('dart2js:noInline')
  static MSGStatus getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MSGStatus>(create);
  static MSGStatus? _defaultInstance;

  @$pb.TagNumber(1)
  OperationStatus get operationstatus => $_getN(0);
  @$pb.TagNumber(1)
  set operationstatus(OperationStatus v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasOperationstatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearOperationstatus() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get sQID => $_getIZ(1);
  @$pb.TagNumber(2)
  set sQID($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasSQID() => $_has(1);
  @$pb.TagNumber(2)
  void clearSQID() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get info => $_getSZ(2);
  @$pb.TagNumber(3)
  set info($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasInfo() => $_has(2);
  @$pb.TagNumber(3)
  void clearInfo() => clearField(3);
}

class EchoData extends $pb.GeneratedMessage {
  factory EchoData({
    CLIENTEND? clientEnd,
    $core.String? echomsg,
  }) {
    final $result = create();
    if (clientEnd != null) {
      $result.clientEnd = clientEnd;
    }
    if (echomsg != null) {
      $result.echomsg = echomsg;
    }
    return $result;
  }
  EchoData._() : super();
  factory EchoData.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EchoData.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'EchoData', package: const $pb.PackageName(_omitMessageNames ? '' : 'GameMsg'), createEmptyInstance: create)
    ..e<CLIENTEND>(1, _omitFieldNames ? '' : 'ClientEnd', $pb.PbFieldType.OE, protoName: 'ClientEnd', defaultOrMaker: CLIENTEND.WALL, valueOf: CLIENTEND.valueOf, enumValues: CLIENTEND.values)
    ..aOS(2, _omitFieldNames ? '' : 'Echomsg', protoName: 'Echomsg')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  EchoData clone() => EchoData()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  EchoData copyWith(void Function(EchoData) updates) => super.copyWith((message) => updates(message as EchoData)) as EchoData;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EchoData create() => EchoData._();
  EchoData createEmptyInstance() => create();
  static $pb.PbList<EchoData> createRepeated() => $pb.PbList<EchoData>();
  @$core.pragma('dart2js:noInline')
  static EchoData getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EchoData>(create);
  static EchoData? _defaultInstance;

  @$pb.TagNumber(1)
  CLIENTEND get clientEnd => $_getN(0);
  @$pb.TagNumber(1)
  set clientEnd(CLIENTEND v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasClientEnd() => $_has(0);
  @$pb.TagNumber(1)
  void clearClientEnd() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get echomsg => $_getSZ(1);
  @$pb.TagNumber(2)
  set echomsg($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasEchomsg() => $_has(1);
  @$pb.TagNumber(2)
  void clearEchomsg() => clearField(2);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
