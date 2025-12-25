class CourseNetOperationItem {
  final String code;
  final String name;
  final String scope;

  const CourseNetOperationItem({
    required this.code,
    required this.name,
    required this.scope,
  });
}

class CourseNetOperationTable {
  static const CourseNetOperationItem deskAssign = CourseNetOperationItem(
    code: 'D@Assign',
    name: '接受数据分配指令',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskPlay = CourseNetOperationItem(
    code: 'D@Play',
    name: '开始游戏指令',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskRestart = CourseNetOperationItem(
    code: 'D@Restart',
    name: '重新开始游戏指令',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskPlayTest = CourseNetOperationItem(
    code: 'D@PlayTest',
    name: '游戏试玩指令',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskReceiveSuccess = CourseNetOperationItem(
    code: 'D@ScoreData@ReceiveSuccess',
    name: '表示接收成功',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskSendData = CourseNetOperationItem(
    code: 'D@ScoreData@Requset',
    name: '表示请求发送数据',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskSendDataSingle = CourseNetOperationItem(
    code: 'D@SinglePerson',
    name: '发送数据字符',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskClassGeneral = CourseNetOperationItem(
    code: 'D@ClassGeneral',
    name: '发送数据格式字符',
    scope: '桌面',
  );

  static const CourseNetOperationItem desktopClassGeneral = CourseNetOperationItem(
    code: 'D@Desktop@ClassGeneral',
    name: '发送已经启动字符',
    scope: '桌面',
  );

  static const CourseNetOperationItem deskTestOver = CourseNetOperationItem(
    code: 'D@TestOver',
    name: '发送试玩结束',
    scope: '桌面',
  );

  static const CourseNetOperationItem wallClassGeneral = CourseNetOperationItem(
    code: 'W@Wall@ClassGeneral',
    name: '墙面启动字符',
    scope: '墙面',
  );

  static const CourseNetOperationItem wallDoubleControl = CourseNetOperationItem(
    code: 'W@Wall@DoubleControl',
    name: '墙面双面字符',
    scope: '墙面',
  );

  static const CourseNetOperationItem wallSingleControl = CourseNetOperationItem(
    code: 'W@Wall@SingleControl',
    name: '墙面单面字符',
    scope: '墙面',
  );

  static const CourseNetOperationItem wallVerificationFail = CourseNetOperationItem(
    code: 'W@CourseVerificationFail',
    name: '墙面课程服务器验证失败字符',
    scope: '墙面',
  );

  static const CourseNetOperationItem wallServerVerify = CourseNetOperationItem(
    code: 'W@CourseVerification',
    name: '墙面课程服务器验证字符',
    scope: '墙面',
  );

  static const CourseNetOperationItem wallMPlay = CourseNetOperationItem(
    code: 'M@Play',
    name: '中间墙面指令-Play',
    scope: '墙面-中间',
  );

  static const CourseNetOperationItem wallMPause = CourseNetOperationItem(
    code: 'M@Pause',
    name: '中间墙面指令-Pause',
    scope: '墙面-中间',
  );

  static const CourseNetOperationItem wallMClose = CourseNetOperationItem(
    code: 'M@Close',
    name: '中间墙面指令-Close',
    scope: '墙面-中间',
  );

  static const CourseNetOperationItem wallMOpen = CourseNetOperationItem(
    code: 'M@Open',
    name: '中间墙面指令-Open',
    scope: '墙面-中间',
  );

  static const CourseNetOperationItem wallMRestart = CourseNetOperationItem(
    code: 'M@Restart',
    name: '中间墙面指令-Restart',
    scope: '墙面-中间',
  );

  static const CourseNetOperationItem wallLPlay = CourseNetOperationItem(
    code: 'L@Play',
    name: '左墙面指令-Play',
    scope: '墙面-左',
  );

  static const CourseNetOperationItem wallLPause = CourseNetOperationItem(
    code: 'L@Pause',
    name: '左墙面指令-Pause',
    scope: '墙面-左',
  );

  static const CourseNetOperationItem wallLClose = CourseNetOperationItem(
    code: 'L@Close',
    name: '左墙面指令-Close',
    scope: '墙面-左',
  );

  static const CourseNetOperationItem wallLOpen = CourseNetOperationItem(
    code: 'L@Open',
    name: '左墙面指令-Open',
    scope: '墙面-左',
  );

  static const CourseNetOperationItem wallLRestart = CourseNetOperationItem(
    code: 'L@Restart',
    name: '左墙面指令-Restart',
    scope: '墙面-左',
  );

  static const CourseNetOperationItem wallRPlay = CourseNetOperationItem(
    code: 'R@Play',
    name: '右墙面指令-Play',
    scope: '墙面-右',
  );

  static const CourseNetOperationItem wallRPause = CourseNetOperationItem(
    code: 'R@Pause',
    name: '右墙面指令-Pause',
    scope: '墙面-右',
  );

  static const CourseNetOperationItem wallRClose = CourseNetOperationItem(
    code: 'R@Close',
    name: '右墙面指令-Close',
    scope: '墙面-右',
  );

  static const CourseNetOperationItem wallROpen = CourseNetOperationItem(
    code: 'R@Open',
    name: '右墙面指令-Open',
    scope: '墙面-右',
  );

  static const CourseNetOperationItem wallRRestart = CourseNetOperationItem(
    code: 'R@Restart',
    name: '右墙面指令-Restart',
    scope: '墙面-右',
  );

  static const CourseNetOperationItem wallAPlay = CourseNetOperationItem(
    code: 'A@Play',
    name: '全墙面指令-Play',
    scope: '墙面-全',
  );

  static const CourseNetOperationItem wallAPause = CourseNetOperationItem(
    code: 'A@Pause',
    name: '全墙面指令-Pause',
    scope: '墙面-全',
  );

  static const CourseNetOperationItem wallAClose = CourseNetOperationItem(
    code: 'A@Close',
    name: '全墙面指令-Close',
    scope: '墙面-全',
  );

  static const CourseNetOperationItem wallAOpen = CourseNetOperationItem(
    code: 'A@Open',
    name: '全墙面指令-Open',
    scope: '墙面-全',
  );

  static const CourseNetOperationItem wallARestart = CourseNetOperationItem(
    code: 'A@Restart',
    name: '全墙面指令-Restart',
    scope: '墙面-全',
  );

  static const List<CourseNetOperationItem> all = <CourseNetOperationItem>[
    deskAssign,
    deskPlay,
    deskRestart,
    deskPlayTest,
    deskReceiveSuccess,
    deskSendData,
    deskSendDataSingle,
    deskClassGeneral,
    desktopClassGeneral,
    deskTestOver,
    wallClassGeneral,
    wallDoubleControl,
    wallSingleControl,
    wallVerificationFail,
    wallServerVerify,
    wallMPlay,
    wallMPause,
    wallMClose,
    wallMOpen,
    wallMRestart,
    wallLPlay,
    wallLPause,
    wallLClose,
    wallLOpen,
    wallLRestart,
    wallRPlay,
    wallRPause,
    wallRClose,
    wallROpen,
    wallRRestart,
    wallAPlay,
    wallAPause,
    wallAClose,
    wallAOpen,
    wallARestart,
  ];
}

