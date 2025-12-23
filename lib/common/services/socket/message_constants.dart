/// Socket通信常量定义
class MessageConstants {
  /// 消息标志符号 0x2425
  static const int header = 0x2425;
  
  /// 消息头长度（魔术头2 + 长度4 + 版本1 + 命令码2 + 序列号4 = 13字节）
  static const int headerLength = 13;
  
  /// 连接超时毫秒数
  static const int timeOut = 2000;
  
  /// 数据缓冲接收大小 2MB
  static const int bufferMaxSize = 1024 * 1024 * 2;
}

/// 消息索引（命令码）
class MessageIndex {
  /// 请求消息
  static const int commonRequest = 10000;
  
  /// 响应消息
  static const int commonResponse = 10001;
  
  /// 心跳包
  static const int heartbeatTcp = 101;
}

