import 'dart:typed_data';
import 'package:think_nest/common/proto/Common.pb.dart';
import 'message_constants.dart';
import '../../utils/index.dart';

/// 消息头
class MessageHead {
  /// 魔术头(0x2425)
  int header;
  
  /// 消息字节长度
  int length;
  
  /// 版本号
  int version;
  
  /// 命令码
  int cmd;
  
  /// 唯一序列号
  int serial;

  MessageHead({
    required this.header,
    required this.length,
    required this.version,
    required this.cmd,
    required this.serial,
  });
}

/// 消息体
class MessageBody {
  Uint8List buffBytes;

  MessageBody(this.buffBytes);
}

/// 消息数据
class MessageData {
  MessageHead head;
  MessageBody body;

  MessageData({
    required this.head,
    required this.body,
  });
}

/// 消息解析器
class MessageParser {
  static Endian wireEndian = Endian.big;

  /// 解析消息头
  /// 
  /// 说明：
  /// - 本项目与 PC 端 `MessageParse.cs` 保持一致：头部字段使用网络字节序（大端）写入/读取
  /// - 头部格式固定 13 字节：Header(2) + Length(4) + Version(1) + Cmd(2) + Serial(4)
  /// - Length 字段语义遵循服务端实现：`Length = (整包字节数) - 6`
  static MessageHead? unParseHead(Uint8List buffer) {
    if (buffer.length < MessageConstants.headerLength) {
      return null;
    }

    try {
      final byteData = ByteData.sublistView(buffer, 0, MessageConstants.headerLength);

      Endian? endian;
      final headerLittle = byteData.getUint16(0, Endian.little);
      if (headerLittle == MessageConstants.header) {
        endian = Endian.little;
      } else {
        final headerBig = byteData.getUint16(0, Endian.big);
        if (headerBig == MessageConstants.header) {
          endian = Endian.big;
        }
      }

      if (endian == null) {
        return null;
      }

      final header = MessageConstants.header;
      final length = byteData.getInt32(2, endian);
      final version = buffer[6];
      final cmd = byteData.getUint16(7, endian);
      final serial = byteData.getInt32(9, endian);

      return MessageHead(
        header: header,
        length: length,
        version: version,
        cmd: cmd,
        serial: serial,
      );
    } catch (e) {
      DebugUtils.log('解析消息头错误: $e', name: 'socket');
      return null;
    }
  }

  /// 解析完整消息
  /// 
  /// 说明：
  /// - 按服务端规则校验 `head.length == buffer.length - 6`
  /// - 消息体为 `buffer[13..]` 的 protobuf `MESSAGE` 字节
  static MessageData? unParse(Uint8List buffer) {
    if (buffer.length < MessageConstants.headerLength) {
      return null;
    }

    final head = unParseHead(buffer);
    if (head == null || head.length != buffer.length - 6) {
      return null;
    }

    try {
      final bodyLength = buffer.length - MessageConstants.headerLength;
      final bodyBytes = Uint8List(bodyLength);
      bodyBytes.setRange(0, bodyLength, buffer, MessageConstants.headerLength);

      return MessageData(
        head: head,
        body: MessageBody(bodyBytes),
      );
    } catch (e) {
      DebugUtils.log('解析消息体错误: $e', name: 'socket');
      return null;
    }
  }

  /// 构建消息头
  /// 
  /// 说明：
  /// - `cmd` 对齐服务端 `MessageIndex.COMMON_REQUEST`/`COMMON_REPONSE`
  /// - Length/Serial 会在 `parse` 阶段统一填充
  static Uint8List parseHead(int cmd, {int version = 0}) {
    final buffer = Uint8List(MessageConstants.headerLength);
    final byteData = ByteData.sublistView(buffer, 0, MessageConstants.headerLength);
    final endian = wireEndian;

    byteData.setUint16(0, MessageConstants.header, endian);
    byteData.setInt32(2, 0, endian);
    buffer[6] = version;
    byteData.setUint16(7, cmd, endian);
    byteData.setInt32(9, 0, endian);

    return buffer;
  }

  /// 构建完整消息（包含头和体）
  /// 
  /// 说明：
  /// - 头部使用 `wireEndian` 写入
  /// - Length 字段按服务端规则写入：`allBytes.length - 6`
  static Uint8List parse(int cmd, Uint8List bodyBytes) {
    final headBytes = parseHead(cmd);
    final totalLength = headBytes.length + bodyBytes.length;
    final allBytes = Uint8List(totalLength);

    // 复制头部
    allBytes.setRange(0, headBytes.length, headBytes);
    
    // 复制消息体
    allBytes.setRange(headBytes.length, totalLength, bodyBytes);

    // 更新长度字段（消息体长度）
    final byteData = ByteData.sublistView(allBytes, 0, MessageConstants.headerLength);
    byteData.setInt32(2, allBytes.length - 6, wireEndian);

    return allBytes;
  }

  /// 将MESSAGE对象编码为完整消息字节
  /// 
  /// 说明：
  /// - 默认以 `MessageIndex.commonRequest` 作为命令码（与 Unity 端 `MessageIndex.COMMON_REQUEST` 一致）
  /// - 返回值为：`13字节头 + protobuf(MESSAGE)字节`
  static Uint8List encodeMessage(MESSAGE message) {
    return encodeMessageWithCmd(message, MessageIndex.commonRequest);
  }

  /// 将MESSAGE对象按指定命令码编码为完整消息字节
  static Uint8List encodeMessageWithCmd(
    MESSAGE message,
    int cmd, {
    Endian? endian,
  }) {
    final bodyBytes = Uint8List.fromList(message.writeToBuffer());
    return parseWithEndian(cmd, bodyBytes, endian: endian);
  }

  static Uint8List parseWithEndian(
    int cmd,
    Uint8List bodyBytes, {
    Endian? endian,
  }) {
    final headBytes = parseHeadWithEndian(cmd, endian: endian);
    final totalLength = headBytes.length + bodyBytes.length;
    final allBytes = Uint8List(totalLength);

    allBytes.setRange(0, headBytes.length, headBytes);
    allBytes.setRange(headBytes.length, totalLength, bodyBytes);

    final byteData = ByteData.sublistView(allBytes, 0, MessageConstants.headerLength);
    byteData.setInt32(2, allBytes.length - 6, endian ?? wireEndian);

    return allBytes;
  }

  static Uint8List parseHeadWithEndian(
    int cmd, {
    int version = 0,
    Endian? endian,
  }) {
    final buffer = Uint8List(MessageConstants.headerLength);
    final byteData = ByteData.sublistView(buffer, 0, MessageConstants.headerLength);
    final wire = endian ?? wireEndian;

    byteData.setUint16(0, MessageConstants.header, wire);
    byteData.setInt32(2, 0, wire);
    buffer[6] = version;
    byteData.setUint16(7, cmd, wire);
    byteData.setInt32(9, 0, wire);

    return buffer;
  }

}

