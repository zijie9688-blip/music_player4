import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_utils.dart';

class AmpBluetoothService {
  static final AmpBluetoothService _instance = AmpBluetoothService._internal();
  factory AmpBluetoothService() => _instance;
  AmpBluetoothService._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  BluetoothCharacteristic? readCharacteristic;

  // 连接状态流控制器
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  // 设备状态流控制器
  final StreamController<Map<String, dynamic>> _deviceStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceStateStream => _deviceStateController.stream;

  // 添加设备连接状态监听器
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;

  // 添加蓝牙适配器状态监听器
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  // 定义BK8000服务UUID
  final String serviceUuid = "0000ae30-0000-1000-8000-00805f9b34fb";
  final String writeCharUuid = "0000ae01-0000-1000-8000-00805f9b34fb";
  final String readCharUuid = "0000ae02-0000-1000-8000-00805f9b34fb";

  // 上次音量值
  int _lastVolume = 16;

  // 添加一个计时器用于定期检查连接状态
  Timer? _connectionCheckTimer;

  // 扫描设备 - 改进版本，使用平台兼容参数
  Stream<List<ScanResult>> scanDevices({Duration? timeout}) {
    final platform = PlatformUtils();
    final scanTimeout = timeout ?? platform.getRecommendedScanTimeout();

    FlutterBluePlus.stopScan();
    FlutterBluePlus.startScan(timeout: scanTimeout, androidUsesFineLocation: true);
    return FlutterBluePlus.scanResults;
  }

  // 停止扫描
  void stopScan() {
    FlutterBluePlus.stopScan();
  }

  // 连接设备 - 改进版本
  Future<void> connectToDevice(BluetoothDevice device) async {
    print('=== Connecting to device ===');
    print('Device name: ${device.name}');
    print('Device ID: ${device.id}');

    try {
      // 取消之前的监听
      _deviceStateSubscription?.cancel();

      // 检查是否已经连接到该设备
      bool alreadyConnected = false;
      try {
        alreadyConnected = await device.isConnected;
      } catch (e) {
        print('检查连接状态时出错: $e');
      }

      if (!alreadyConnected) {
        print('设备未连接，开始连接...');
        final platform = PlatformUtils();
        final config = platform.getManufacturerConfig();

        await device.connect(
          timeout: Duration(seconds: config['connectionTimeout'] ?? 30),
          mtu: config['mtu'] ?? 512,
        );
      } else {
        print('设备已连接');
      }

      connectedDevice = device;
      print('✅ Connected to device: ${device.name}');

      // 保存设备信息
      await saveConnectedDevice(device);

      // 开始监听设备连接状态变化
      _startDeviceStateListener(device);

      // 发现服务
      print('开始发现服务...');
      List<BluetoothService> services = await device.discoverServices(timeout: 10000);
      print('发现 ${services.length} 个服务');

      bool foundService = false;
      bool foundWriteChar = false;
      bool foundReadChar = false;

      for (BluetoothService service in services) {
        String serviceUuidLower = service.uuid.toString().toLowerCase();
        print('检查服务: $serviceUuidLower');

        // 严格匹配服务UUID
        bool isTargetService = serviceUuidLower == serviceUuid.toLowerCase();

        if (isTargetService) {
          foundService = true;
          print('✅ 找到目标服务: ${service.uuid}');

          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();
            print('检查特征: $charUuid, 属性: ${characteristic.properties}');

            // 严格检查写入特征
            if (charUuid == writeCharUuid.toLowerCase() &&
                (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
              writeCharacteristic = characteristic;
              foundWriteChar = true;
              print('✅ 找到目标写入特征: ${characteristic.uuid}');
            }

            // 严格检查通知特征
            if (charUuid == readCharUuid.toLowerCase() &&
                characteristic.properties.notify) {
              readCharacteristic = characteristic;
              foundReadChar = true;
              print('✅ 找到目标通知特征: ${characteristic.uuid}');

              // 启用通知
              try {
                bool notificationEnabled = await _enableNotificationsWithRetry(characteristic);
                if (notificationEnabled) {
                  print('✅ 通知已启用');

                  characteristic.value.listen((value) {
                    if (value.isNotEmpty) {
                      // 🚨 关键修改：以十六进制格式完整打印收到的数据
                      print('📝 Received raw data (Hex): ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ')}');
                      print('📝 Received data length: ${value.length}');

                      try {
                        print('📱 收到设备实时数据: $value');
                        print('数据十六进制: ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');
                        _parseDeviceResponse(value);
                      } catch (e) {
                        print('❌ Error parsing device state data: $e');
                      }
                    }
                  }, onError: (error) {
                    print('通知监听错误: $error');
                    // 尝试重新启用通知
                    _enableNotificationsWithRetry(characteristic);
                  });
                }
              } catch (e) {
                print('⚠️ 启用通知失败: $e');
              }

              // 【新增代码】：在发送状态请求前，等待 500ms
              await Future.delayed(Duration(milliseconds: 500));

              // 【新增代码】: 连接成功且设置通知后，立即请求初始状态
              await _requestInitialDeviceState();
            }
          }
        }
      }

      // 更新连接状态
      if (foundService && foundWriteChar && foundReadChar) {
        print('✅ 连接完全建立，设备就绪');
        updateConnectionStatus(true);

        // 连接成功后立即读取设备状态
        if (foundReadChar) {
          print('🔄 连接成功，准备读取设备当前状态...');
          await Future.delayed(Duration(milliseconds: 1500));
          await readDeviceCurrentState();
        }

        // 启动连接状态检查定时器
        _startConnectionCheckTimer();
      } else {
        print('❌ 服务或特征发现不完整');
        print('找到服务: $foundService, 找到写入特征: $foundWriteChar, 找到读取特征: $foundReadChar');

        // 尝试更严格的特征查找
        await _findCorrectCharacteristics(device);

        // 检查是否找到了必要的特征
        if (foundService && (writeCharacteristic != null)) {
          print('✅ 使用备用方法找到必要特征');
          updateConnectionStatus(true);
        } else {
          print('❌ 未能找到必要特征，连接失败');
          updateConnectionStatus(false);
        }
      }

    } catch (e) {
      print('❌ 连接失败: $e');
      print('❌ 连接失败: $e');
      updateConnectionStatus(false);
      cleanup(); // 连接失败时清理资源
      rethrow;
    }
  }

  // 新增：严格查找正确的特征
  Future<void> _findCorrectCharacteristics(BluetoothDevice device) async {
    print('🔍 尝试使用更严格的方法查找特征...');

    try {
      List<BluetoothService> services = await device.discoverServices(timeout: 10000);

      for (BluetoothService service in services) {
        String serviceUuidLower = service.uuid.toString().toLowerCase();

        // 只查找目标服务
        if (serviceUuidLower == serviceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();

            // 只接受目标写入特征
            if (charUuid == writeCharUuid.toLowerCase() &&
                (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
              writeCharacteristic = characteristic;
              print('✅ 找到目标写入特征: ${characteristic.uuid}');
            }

            // 只接受目标通知特征
            if (charUuid == readCharUuid.toLowerCase() &&
                characteristic.properties.notify) {
              readCharacteristic = characteristic;
              print('✅ 找到目标通知特征: ${characteristic.uuid}');
            }

            // 如果两个特征都找到了，就停止搜索
            if (writeCharacteristic != null && readCharacteristic != null) {
              print('✅ 找到所有目标特征');
              return;
            }
          }
        }
      }

      // 如果仍然找不到目标特征，尝试备用方法
      if (writeCharacteristic == null || readCharacteristic == null) {
        print('⚠️ 未找到目标特征，尝试备用方法...');

        // 查找接近的特征
        for (BluetoothService service in services) {
          String serviceUuidLower = service.uuid.toString().toLowerCase();

          if (serviceUuidLower.contains('ae30')) {
            for (BluetoothCharacteristic characteristic in service.characteristics) {
              String charUuid = characteristic.uuid.toString().toLowerCase();

              if (charUuid.contains('ae01') &&
                  (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
                writeCharacteristic = characteristic;
                print('✅ 找到备用写入特征: ${characteristic.uuid}');
              }

              if (charUuid.contains('ae02') && characteristic.properties.notify) {
                readCharacteristic = characteristic;
                print('✅ 找到备用通知特征: ${characteristic.uuid}');
              }

              if (writeCharacteristic != null && readCharacteristic != null) {
                print('✅ 找到备用特征');
                return;
              }
            }
          }
        }
      }

      if (writeCharacteristic == null) {
        print('⚠️ 未找到可写的特征');
      }
      if (readCharacteristic == null) {
        print('⚠️ 未找到可通知的特征');
      }
    } catch (e) {
      print('❌ 特征查找失败: $e');
    }
  }

  // 开始监听设备连接状态
  void _startDeviceStateListener(BluetoothDevice device) {
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = device.connectionState.listen((state) {
      print('设备连接状态变化: $state');

      switch (state) {
        case BluetoothConnectionState.connected:
          print('✅ 设已连接');
          updateConnectionStatus(true);
          break;
        case BluetoothConnectionState.disconnected:
          print('❌ 设备已断开');
          updateConnectionStatus(false);
          cleanup(); // 清理资源
          break;
        case BluetoothConnectionState.connecting:
          print('🔄 设备连接中...');
          updateConnectionStatus(false);
          break;
        case BluetoothConnectionState.disconnecting:
          print('⏳ 设备断开中...');
          updateConnectionStatus(false);
          break;
      }
    }, onError: (error) {
      print('设备状态监听错误: $error');
      updateConnectionStatus(false);
      cleanup();
    });
  }

  // 启动连接状态检查定时器
  void _startConnectionCheckTimer() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      if (connectedDevice != null) {
        try {
          bool isConnected = await connectedDevice!.isConnected;
          if (!isConnected) {
            print('❌ 检测到设备已断开连接');
            updateConnectionStatus(false);
            cleanup();
          }
        } catch (e) {
          print('❌ 检查连接状态时出错: $e');
        }
      }
    });
  }

  // 断开连接
  Future<void> disconnect() async {
    print('=== 断开设备连接 ===');
    if (connectedDevice != null) {
      print('断开设备: ${connectedDevice!.name}');
      try {
        await connectedDevice!.disconnect();
        print('✅ 设备断开成功');
      } catch (e) {
        print('⚠️ 断开设备时出错: $e');
      }
    }

    // 清理资源
    cleanup();
  }

  // 清理资源 - 改为公共方法
  void cleanup() {
    print('清理蓝牙服务资源');
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    connectedDevice = null;
    writeCharacteristic = null;
    readCharacteristic = null;
    updateConnectionStatus(false);
  }

  // 发送指令到设备
  Future<void> sendCommand(List<int> command, {int? maxRetries}) async {
    final platform = PlatformUtils();
    final config = platform.getManufacturerConfig();
    final retryCount = maxRetries ?? (config['retryCount'] ?? 3);
    print('发送指令: $command, 最大重试次数: $retryCount');

    // 检查连接状态
    if (!await isReallyConnected) {
      print('❌ 设备未连接，无法发送指令');
      throw Exception('设备未连接');
    }

    if (writeCharacteristic == null) {
      print('❌ 写入特征不可用');
      throw Exception('写入特征不可用');
    }

    int attempts = 0;
    while (attempts < retryCount) {
      attempts++;
      try {
        print('发送指令尝试: $attempts/$retryCount');
        print('指令十六进制: ${command.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

        // 检查设备连接状态
        bool deviceConnected = await connectedDevice!.isConnected;
        if (!deviceConnected) {
          throw Exception('设备在发送前断开连接');
        }

        // 根据特征属性和平台配置选择写入方式
        bool useAlternativeWrite = config['useAlternativeWrite'] ?? false;

        if (writeCharacteristic!.properties.write && !useAlternativeWrite) {
          await writeCharacteristic!.write(command, withoutResponse: false);
        } else if (writeCharacteristic!.properties.writeWithoutResponse || useAlternativeWrite) {
          await writeCharacteristic!.write(command, withoutResponse: true);
        } else {
          throw Exception('特征不支持写入操作');
        }

        print('✅ 指令发送成功');
        return;
      } catch (e, stackTrace) {
        print('❌ 发送指令失败 (尝试 $attempts/$retryCount): $e');
        print('堆栈跟踪: $stackTrace');

        if (attempts >= retryCount) {
          print('❌ 达到最大重试次数，放弃发送');
          rethrow;
        } else {
          // 使用平台推荐的重试间隔
          int delayMs = platform.getRecommendedRetryDelay(attempts);
          print('等待 ${delayMs}ms 后重试...');
          await Future.delayed(Duration(milliseconds: delayMs));

          // 重试前检查连接状态
          _checkAndUpdateConnectionStatus();
        }
      }
    }
  }

  // 发送音量控制指令 - 修改为适配BK8000协议
  Future<void> sendVolumeCommand(int volume) async {
    print('=== 发送音量指令 ===');
    print('目标音量: $volume');

    // 确保音量在有效范围内 (0-32)
    volume = volume.clamp(0, 32);
    print('音量已限制: $volume');

    // 保存上次音量（用于取消静音）
    if (volume > 0) {
      _lastVolume = volume;
    }

    // 构造指令包: [包头, 指令, 音量值]
    final List<int> packet = [
      0xBE,       // 包头
      0x01,       // 音量指令
      volume      // 音量值
    ];

    print('音量指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ 音量指令发送完成');
  }

  // 发送音效强度指令
  Future<void> sendEffectCommand(int effectMode) async {
    print('发送音效强度指令: $effectMode');

    // 构造指令包
    final List<int> packet = [
      0xBE,       // 包头
      0x02,       // 音效指令
      effectMode, // 音效值
    ];

    print('音效指令包: $packet');
    await sendCommand(packet, maxRetries: 3);
  }

  // 发送音效模式指令
  Future<void> sendEffectModeCommand(int effectMode) async {
    print('发送音效模式指令: $effectMode');

    // 构造指令包
    final List<int> packet = [
      0xBE,       // 包头
      0x08,       // 音效模式指令
      effectMode, // 模式值,
    ];

    print('音效模式指令包: $packet');
    await sendCommand(packet, maxRetries: 3);
  }

  // 新增：发送模式切换指令（FM/AUX/USB/BT）
  Future<void> sendModeSwitchCommand(int mode) async {
    print('发送模式切换指令: $mode');
    print('模式值说明 - 0: BT, 1: AUX, 2: USB/SD, 3: FM');

    // 确保模式值在有效范围内
    if (mode < 0 || mode > 3) {
      print('❌ 无效的模式值: $mode，模式值应为 0-3');
      throw ArgumentError('模式值必须在 0-3 范围内');
    }

    // 构造指令包: [包头, 指令, 模式值]
    final List<int> packet = [
      0xBE,       // 包头
      0x30,       // 模式切换指令
      mode        // 模式值 (0:BT, 1:AUX, 2:USB/SD, 3:FM)
    ];

    print('模式切换指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ 模式切换指令发送完成');
  }

  // 新增：便捷方法 - 切换到BT模式
  Future<void> switchToBT() async {
    print('切换到BT模式');
    await sendModeSwitchCommand(0);
  }

  // 新增：便捷方法 - 切换到AUX模式
  Future<void> switchToAUX() async {
    print('切换到AUX模式');
    await sendModeSwitchCommand(1);
  }

  // 新增：便捷方法 - 切换到USB/SD模式
  Future<void> switchToUSB() async {
    print('切换到USB/SD模式');
    await sendModeSwitchCommand(2);
  }

  // 新增：便捷方法 - 切换到FM模式
  Future<void> switchToFM() async {
    print('切换到FM模式');
    await sendModeSwitchCommand(3);
  }

  // 发送FM频率指令
  Future<void> sendFMFrequencyCommand(double frequency) async {
    print('发送FM频率指令: $frequency');

    // 确保频率在有效范围内 (87.5-108.0 MHz)
    if (frequency < 87.5 || frequency > 108.0) {
      print('❌ 无效的FM频率: $frequency，频率应在87.5-108.0 MHz范围内');
      throw ArgumentError('FM频率必须在87.5-108.0 MHz范围内');
    }

    // 将频率转换为整数（乘以10，保留一位小数）
    int frequencyInt = (frequency * 10).round();
    print('频率整数值: $frequencyInt');

    // 根据设备返回的数据格式分析，FM频率编码规则：
    // 87.5 MHz -> 0x00, 0x08, 0x07, 0x05
    // 92.4 MHz -> 0x00, 0x09, 0x02, 0x04
    // 108.0 MHz -> 0x00, 0x08, 0x00, 0x00

    // 编码规则分析：
    // byte2: 百位数字（8或9）
    // byte3: 十位数字（0-9）
    // byte4: 个位数字（0-9，表示小数位）

    // 对于100MHz以上的频率，需要特殊处理
    // 101.9 MHz -> 0x00, 0x0A, 0x01, 0x09 (使用0x0A表示100MHz以上)
    // 108.0 MHz -> 0x00, 0x0A, 0x08, 0x00

    int byte2, byte3, byte4;

    if (frequencyInt >= 1000) {
      // 100.0 MHz以上 (1000-1080)
      byte2 = 0x0A;  // 使用0x0A表示100MHz以上
      byte3 = (frequencyInt ~/ 10) % 10;  // 十位
      byte4 = frequencyInt % 10;           // 个位（小数位）
    } else {
      // 100.0 MHz以下 (875-999)
      byte2 = (frequencyInt ~/ 100) % 10;  // 百位（8或9）
      byte3 = (frequencyInt ~/ 10) % 10;  // 十位
      byte4 = frequencyInt % 10;           // 个位（小数位）
    }

    // 构造指令包的字节
    int byte1 = 0x00;  // 固定为0x00

    // 构造指令包: [包头, 指令, 4个字节的频率数据]
    final List<int> packet = [
      0xBE,       // 包头
      0xF0,       // FM频率指令
      byte1,      // 第1个字节（固定为0x00）
      byte2,      // 第2个字节（百位）
      byte3,      // 第3个字节（十位）
      byte4       // 第4个字节（个位/小数位）
    ];

    print('频率: ${frequency.toStringAsFixed(1)} MHz, 整数值: $frequencyInt');
    if (frequencyInt >= 1000) {
      print('频率范围: 100MHz以上');
      print('编码: byte2=0x${byte2.toRadixString(16).padLeft(2, '0')} (表示100MHz以上), byte3=0x${byte3.toRadixString(16).padLeft(2, '0')} (十位), byte4=0x${byte4.toRadixString(16).padLeft(2, '0')} (小数位)');
    } else {
      print('频率范围: 100MHz以下');
      print('编码: byte2=0x${byte2.toRadixString(16).padLeft(2, '0')} (百位), byte3=0x${byte3.toRadixString(16).padLeft(2, '0')} (十位), byte4=0x${byte4.toRadixString(16).padLeft(2, '0')} (小数位)');
    }
    print('FM频率指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ FM频率指令发送完成');
  }

  // 新增：发送播放控制指令（上一首、暂停/开始、下一首）
  Future<void> sendPlaybackControlCommand(int control) async {
    print('发送播放控制指令: $control');
    print('控制值说明 - 0: Prev, 1: PlayPause, 2: Next');

    // 确保控制值在有效范围内
    if (control < 0 || control > 2) {
      print('❌ 无效的控制值: $control，控制值应为 0-2');
      throw ArgumentError('控制值必须在 0-2 范围内');
    }

    // 构造指令包: [包头, 指令, 控制值]
    final List<int> packet = [
      0xBE,       // 包头
      0x31,       // 播放控制指令
      control     // 控制值 (0:Prev, 1:PlayPause, 2:Next)
    ];

    print('播放控制指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ 播放控制指令发送完成');
  }

  // 新增：便捷方法 - 上一首
  Future<void> previousTrack() async {
    print('上一首');
    await sendPlaybackControlCommand(0);
  }

  // 新增：便捷方法 - 暂停/开始
  Future<void> playPause() async {
    print('暂停/开始');
    await sendPlaybackControlCommand(1);
  }

  // 新增：便捷方法 - 下一首
  Future<void> nextTrack() async {
    print('下一首');
    await sendPlaybackControlCommand(2);
  }

  // 新增：发送KARAOKE控制指令
  Future<void> sendKaraokeCommand(int value) async {
    print('发送KARAOKE指令: $value');
    print('KARAOKE值范围: 0-32');

    // 确保KARAOKE值在有效范围内
    if (value < 0 || value > 32) {
      print('❌ 无效的KARAOKE值: $value，值应为 0-32');
      throw ArgumentError('KARAOKE值必须在 0-32 范围内');
    }

    // 构造指令包: [包头, 指令, KARAOKE值]
    final List<int> packet = [
      0xBE,       // 包头
      0x09,       // KARAOKE指令
      value       // KARAOKE值 (0-32)
    ];

    print('KARAOKE指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ KARAOKE指令发送完成');
  }

  // 新增：发送X.BASS控制指令
  Future<void> sendXBassCommand(int value) async {
    print('发送X.BASS指令: $value');
    print('X.BASS值说明 - 0: 0, 1: 1, 2: 2, 3: 3');

    // 确保X.BASS值在有效范围内
    if (value < 0 || value > 3) {
      print('❌ 无效的X.BASS值: $value，值应为 0-3');
      throw ArgumentError('X.BASS值必须在 0-3 范围内');
    }

    // 构造指令包: [包头, 指令, X.BASS值]
    final List<int> packet = [
      0xBE,       // 包头
      0x06,       // X.BASS指令
      value       // X.BASS值 (0:0, 1:1, 2:2, 3:3)
    ];

    print('X.BASS指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ X.BASS指令发送完成');
  }

  // 新增：发送Mic mode控制指令
  Future<void> sendMicModeCommand(int value) async {
    print('发送Mic mode指令: $value');
    print('Mic mode值说明 - 0: MAN, 1: GIRL');

    // 确保Mic mode值在有效范围内
    if (value < 0 || value > 1) {
      print('❌ 无效的Mic mode值: $value，值应为 0-1');
      throw ArgumentError('Mic mode值必须在 0-1 范围内');
    }

    // 构造指令包: [包头, 指令, Mic mode值]
    final List<int> packet = [
      0xBE,       // 包头
      0x14,       // Mic mode指令
      value       // Mic mode值 (0:MAN, 1:GIRL)
    ];

    print('Mic mode指令包: $packet');
    print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    await sendCommand(packet, maxRetries: 3);
    print('✅ Mic mode指令发送完成');
  }

  // 新增：读取设备当前状态
  Future<void> readDeviceCurrentState() async {
    print('=== 读取设备当前状态 ===');

    if (!await isReallyConnected) {
      print('❌ 设备未连接，无法读取状态');
      return;
    }

    if (writeCharacteristic == null) {
      print('❌ 写入特征不可用');
      return;
    }

    try {
      // 构造读取状态指令包
      final List<int> packet = [
        0xBE,       // 包头
        0x04,       // 读取状态指令
        0x00        // 数据长度
      ];

      print('读取状态指令包: $packet');
      print('十六进制: ${packet.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

      await sendCommand(packet, maxRetries: 2);
      print('✅ 状态读取指令发送完成');

    } catch (e) {
      print('❌ 发送状态读取指令失败: $e');
      rethrow;
    }
  }

  // 发送静音指令
  Future<void> sendMuteCommand(bool mute) async {
    print('发送静音指令: $mute');

    if (mute) {
      // 静音：设置音量为0
      await sendVolumeCommand(0);
    } else {
      // 取消静音：恢复上次音量
      await sendVolumeCommand(_lastVolume);
    }
  }

  // 假设这是一个用于请求设备所有当前状态的命令
  // **根据您的设备通信协议替换为实际的字节数组**
  static const List<int> _READ_ALL_STATE_COMMAND = [0xBE, 0x00];

  /// 向设备发送请求初始状态的命令
  Future<void> _requestInitialDeviceState() async {
    print('Requesting initial device state...');

    // 确保写入特征值可用
    if (writeCharacteristic != null) {
      try {
        await writeCharacteristic!.write(_READ_ALL_STATE_COMMAND, withoutResponse: false);
        print('✅ Sent read initial state command');
        // 设备收到命令后，应通过 readCharacteristic (通知) 返回当前状态。
      } catch (e) {
        print('❌ Failed to request initial device state: $e');
      }
    } else {
      print('❌ writeCharacteristic is null, cannot request initial state.');
    }
  }

  // 解析设备响应数据
  void _parseDeviceResponse(List<int> data) {
    print('=== 收到设备数据包 ===');
    print('原始数据: $data');
    print('十六进制: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}');

    if (data.length < 3) {
      print('❌ 数据长度不足，无法解析');
      return;
    }

    // 检查数据包头
    if (data[0] != 0xBE && data[0] != 0xEB) {
      print('❌ 无效的数据包头: 0x${data[0].toRadixString(16)}');
      return;
    }

    int command = data[1];

    print('指令: 0x${command.toRadixString(16)}');

    // 处理设备通知数据 (0xEB开头的12字节数据)
    if (data[0] == 0xEB && data.length >= 12) {
      _handleDeviceNotification(data);
      return;
    }

    // 【新增/修改的解析逻辑】
    // 重要：根据蓝牙协议来修改这里的解析逻辑

    // 当命令类型为 0x00 (Sync) 且数据长度足够时，是一个完整的状态包
    if (command == 0x00 && data.length >= 7) {
      // 假设：
      // data[2] 是 volume 值 (例如 0-32)
      // data[3] 是 music vb 值
      // data[4] 是 3D 值
      // data[5] 是 music eq 值
      // data[6] 是 mic vol 值
      // data[7] 是 mic eq 值 (如果存在)
      final int volume = data[2];
      final int musicVB = data[3];
      final int sound3D = data[4];
      final int musicEQ = data[5];
      final int micVol = data[6];
      final int micEQ = data.length > 7 ? data[7] : 0;

      final Map<String, dynamic> newState = {
        'volume': volume,
        'musicVB': musicVB,
        'sound3D': sound3D,
        'musicEQ': musicEQ,
        'micVol': micVol,
        'micEQ': micEQ,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'initialState',
        'source': 'device',
        'rawData': data,
        'rawBytes': data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')
      };

      // 将解析后的状态推送到流中，供控制页更新 UI
      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(newState);
      }

      print('✅ Full state parsed and updated. Volume: $volume, MusicVB: $musicVB, 3D: $sound3D, MusicEQ: $musicEQ, MicVol: $micVol, MicEQ: $micEQ');

    } else {
      // 处理其他类型的指令
      print('ℹ️ Received other data type or incomplete package (Type: ${command.toRadixString(16)}).');
      switch (command) {
        case 0x00: // Sync指令
          _handleSyncCommand(data);
          break;
        case 0x01: // 音量响应
          _handleVolumeResponse(data);
          break;
        case 0x02: // 音效强度响应（新增）
          _handleEffectResponse(data);
          break;
        case 0x05: // 状态响应
          _handleStateResponse(data);
          break;
        case 0x06: // 音量变化通知
          _handleVolumeChange(data);
          break;
        case 0x07: // 效果变化通知
          _handleEffectChange(data);
          break;
        case 0x08: // 音效模式变化通知
          _handleEffectModeChange(data);
          break;
        case 0x06: // X.BASS变化通知
          _handleXBassChange(data);
          break;
        case 0x30: // 输入源变化通知
          _handleInputSourceChange(data);
          break;
        case 0xF0: // FM频率变化通知
          _handleFMFrequencyChange(data);
          break;
        default:
          print('ℹ️ 收到未知指令类型: 0x${command.toRadixString(16)}');
      }
    }
  }

  // 处理设备通知数据 (0xEB开头的12字节数据)
  void _handleDeviceNotification(List<int> data) {
    print('=== 处理设备通知数据 ===');
    print('原始数据: $data');
    print('数据长度: ${data.length}');

    if (data.length < 12) {
      print('❌ 设备通知数据长度不足，需要至少12个字节');
      return;
    }

    try {
      // 解析12字节数据
      // 按顺序分别是：Volume、X.BASS、3D、soundeffects、KARAOKE、MIC MODE、输入源、music control播放暂停、FM频点(4个字节)
      int volume = data[1];           // Volume (0-32)
      int xBass = data[2];            // X.BASS (0-3)
      int sound3D = data[3];          // 3D (0-8)
      int soundEffects = data[4];      // soundeffects (0-8)
      int karaoke = data[5];          // KARAOKE (0-32)
      int micMode = data[6];          // MIC MODE (0-2)
      int inputSource = data[7];      // 输入源 (0:BT, 1:AUX, 2:USB/SD, 3:FM)
      int musicControl = data[8];     // music control播放暂停 (0:暂停, 1:播放)

      // FM频点(4个字节)
      int fmByte1 = data[9];          // 第1个字节
      int fmByte2 = data[10];         // 第2个字节
      int fmByte3 = data[11];         // 第3个字节

      // 将FM频点转换为频率
      double fmFrequency = _parseFMFrequency(fmByte1, fmByte2, fmByte3);

      print('📊 设备通知数据解析:');
      print('  Volume: $volume');
      print('  X.BASS: $xBass');
      print('  3D: $sound3D');
      print('  Sound Effects: $soundEffects');
      print('  KARAOKE: $karaoke');
      print('  MIC MODE: $micMode');
      print('  Input Source: $inputSource');
      print('  Music Control: $musicControl');
      print('  FM Frequency: $fmFrequency MHz');

      // 构建状态映射
      Map<String, dynamic> state = {
        'volume': volume.clamp(0, 32),
        'xBass': xBass.toString(),
        'sound3D': sound3D.clamp(0, 8),
        'soundEffects': soundEffects.clamp(0, 8),
        'karaoke': karaoke.clamp(0, 32),
        'micMode': micMode.clamp(0, 2),
        'inputSource': _mapInputSourceToString(inputSource),
        'isPlaying': musicControl == 1,
        'fmFrequency': fmFrequency,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'deviceNotification',
        'source': 'device',
        'rawData': data,
      };

      // 将解析后的状态推送到流中，供控制页更新 UI
      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(state);
        print('✅ 设备通知数据已发送到UI');
      }

    } catch (e) {
      print('❌ 解析设备通知数据失败: $e');
      print('错误数据: $data');
    }
  }

  // 解析FM频率
  double _parseFMFrequency(int byte1, int byte2, int byte3) {
    // FM频率编码规则：
    // 87.5 MHz -> 0x00, 0x08, 0x07, 0x05
    // 92.4 MHz -> 0x00, 0x09, 0x02, 0x04
    // 108.0 MHz -> 0x00, 0x08, 0x00, 0x00

    // 根据接收到的3字节数据确定频率
    double frequency;

    if (byte2 == 0x08 && byte3 == 0x07) {
      frequency = 87.5;
    } else if (byte2 == 0x09 && byte3 == 0x02) {
      frequency = 92.4;
    } else if (byte2 == 0x08 && byte3 == 0x00) {
      frequency = 108.0;
    } else {
      // 对于其他数据，尝试使用反向插值计算频率
      if (byte2 == 0x08 && byte3 <= 0x07) {
        // 在87.5和92.4之间
        double ratio = (0x07 - byte3) / (0x07 - 0x02);
        frequency = 87.5 + ratio * (92.4 - 87.5);
      } else if (byte2 == 0x09 || (byte2 == 0x08 && byte3 > 0x02)) {
        // 在92.4和108.0之间
        double ratio;
        if (byte2 == 0x09) {
          ratio = (0x02 - byte3) / (0x02 - 0x00);
        } else {
          ratio = 1.0 - byte3 / 0x02;
        }
        frequency = 92.4 + ratio * (108.0 - 92.4);
      } else {
        // 默认值
        frequency = 87.5;
      }
    }

    // 保留一位小数
    frequency = (frequency * 10).round() / 10.0;

    // 确保频率在有效范围内
    return frequency.clamp(87.5, 108.0);
  }

  // 将输入源值转换为字符串
  String _mapInputSourceToString(int value) {
    switch (value) {
      case 0:
        return 'BT';
      case 1:
        return 'AUX';
      case 2:
        return 'USB/SD';
      case 3:
        return 'FM';
      default:
        return 'BT'; // 默认值
    }
  }

  // 新增：处理Sync指令 (0x00)
  void _handleSyncCommand(List<int> data) {
    print('=== 处理Sync指令数据 ===');
    print('原始数据: $data');
    print('数据长度: ${data.length}');

    // 更宽松的长度检查
    if (data.length < 7) {
      print('⚠️ Sync指令数据长度不足，尝试解析: ${data.length}');
      // 不返回，尝试解析可用数据
    }

    try {
      // 更健壮的数据提取
      int volume = data.length > 2 ? data[2] : 0;
      int musicVB = data.length > 3 ? data[3] : 0;
      int sound3D = data.length > 4 ? data[4] : 0;
      int musicEQ = data.length > 5 ? data[5] : 0;
      int micVol = data.length > 6 ? data[6] : 0;
      int micEQ = data.length > 7 ? data[7] : 0;

      // 数据验证
      volume = volume.clamp(0, 32);
      musicVB = musicVB.clamp(0, 32);
      sound3D = sound3D.clamp(0, 8);
      musicEQ = musicEQ.clamp(0, 8);
      micVol = micVol.clamp(0, 32);
      micEQ = micEQ.clamp(0, 8);

      print('🔄 设备主动同步 - 音量: $volume, 音乐VB: $musicVB, 3D: $sound3D, 音乐EQ: $musicEQ, 麦克风音量: $micVol, 麦克风EQ: $micEQ');

      Map<String, dynamic> state = {
        'volume': volume,
        'musicVB': musicVB,
        'sound3D': sound3D,
        'musicEQ': musicEQ,
        'micVol': micVol,
        'micEQ': micEQ,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'sync',
        'source': 'device', // 标记来自设备
        'rawData': data, // 添加原始数据
      };

      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(state);
        print('✅ Sync状态已发送到UI');
      }

    } catch (e) {
      print('❌ 解析Sync指令失败: $e');
      print('错误数据: $data');
    }
  }

  // 处理状态响应
  void _handleStateResponse(List<int> data) {
    print('处理状态响应数据');

    if (data.length < 3) {
      print('❌ 状态响应数据长度不足: ${data.length}');
      return;
    }

    try {
      // 数据内容从索引2开始
      int volume = data[2];      // Volume

      print('📊 Current status - Volume: $volume');

      // 发布状态到流
      Map<String, dynamic> state = {
        'volume': volume,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'stateResponse',
        'rawData': data, // 添加原始数据
      };

      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(state);
      }

    } catch (e) {
      print('❌ Failed to parse status response: $e');
    }
  }

  // 处理音量变化通知
  void _handleVolumeChange(List<int> data) {
    if (data.length < 3) {
      return;
    }

    // 数据内容从索引2开始
    int volume = data[2];
    print('🔊 Device volume change: $volume');

    Map<String, dynamic> state = {
      'volume': volume,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'volumeChange',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 处理效果强度变化通知
  void _handleEffectChange(List<int> data) {
    if (data.length < 3) {
      return;
    }

    // 数据内容从索引2开始
    int effect = data[2];
    print('🎛️ Device effect intensity variation: $effect');

    Map<String, dynamic> state = {
      'effect': effect,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'effectChange',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 处理音效模式变化通知
  void _handleEffectModeChange(List<int> data) {
    if (data.length < 3) {
      return;
    }

    // 数据内容从索引2开始
    int effectMode = data[2];
    print('🎵 Device sound effect mode change: $effectMode');

    Map<String, dynamic> state = {
      'effectMode': effectMode,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'effectModeChange',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 处理X.BASS变化通知
  void _handleXBassChange(List<int> data) {
    if (data.length < 3) {
      return;
    }

    // 数据内容从索引2开始
    int xBassValue = data[2];
    print('🔊 Device X.BASS change: $xBassValue');

    Map<String, dynamic> state = {
      'xBass': xBassValue.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'xBassChange',
      'source': 'device',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 处理输入源变化通知
  void _handleInputSourceChange(List<int> data) {
    if (data.length < 3) {
      return;
    }

    // 数据内容从索引2开始
    int inputSourceValue = data[2];
    print('🎯 Device input source change: $inputSourceValue');

    // 将输入源值转换为字符串表示
    String inputSource;
    switch (inputSourceValue) {
      case 0:
        inputSource = 'BT';
        break;
      case 1:
        inputSource = 'AUX';
        break;
      case 2:
        inputSource = 'USB/SD';
        break;
      case 3:
        inputSource = 'FM';
        break;
      default:
        inputSource = 'BT'; // 默认值
        break;
    }

    Map<String, dynamic> state = {
      'inputSource': inputSource,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'inputSourceChange',
      'source': 'device',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 处理FM频率变化通知
  void _handleFMFrequencyChange(List<int> data) {
    if (data.length < 6) {
      return;
    }

    // 数据内容从索引2开始，共4个字节
    int byte1 = data[2];  // 第1个字节（固定为0x00）
    int byte2 = data[3];  // 第2个字节
    int byte3 = data[4];  // 第3个字节
    int byte4 = data[5];  // 第4个字节

    print('📻 Device FM frequency change: 0x${byte1.toRadixString(16)}, 0x${byte2.toRadixString(16)}, 0x${byte3.toRadixString(16)}, 0x${byte4.toRadixString(16)}');

    // 将4个字节转换为频率
    // 87.5 MHz 对应 0x00、0x08、0x07、0x05
    // 92.4 MHz 对应 0x00、0x09、0x02、0x04
    // 108.0 MHz 对应 0x00、0x08、0x00、0x00

    // 根据接收到的4字节数据确定频率
    double frequency;

    if (byte2 == 0x08 && byte3 == 0x07 && byte4 == 0x05) {
      frequency = 87.5;
    } else if (byte2 == 0x09 && byte3 == 0x02 && byte4 == 0x04) {
      frequency = 92.4;
    } else if (byte2 == 0x08 && byte3 == 0x00 && byte4 == 0x00) {
      frequency = 108.0;
    } else {
      // 对于其他数据，尝试使用反向插值计算频率
      // 首先确定数据在哪个区间
      if (byte2 == 0x08 && byte3 <= 0x07) {
        // 在87.5和92.4之间
        double ratio = (0x07 - byte3) / (0x07 - 0x02);
        frequency = 87.5 + ratio * (92.4 - 87.5);
      } else if (byte2 == 0x09 || (byte2 == 0x08 && byte3 > 0x02)) {
        // 在92.4和108.0之间
        double ratio;
        if (byte2 == 0x09) {
          ratio = (0x02 - byte3) / (0x02 - 0x00);
        } else {
          ratio = 1.0 - byte3 / 0x02;
        }
        frequency = 92.4 + ratio * (108.0 - 92.4);
      } else {
        // 默认值
        frequency = 87.5;
      }
    }

    // 保留一位小数
    frequency = (frequency * 10).round() / 10.0;

    // 确保频率在有效范围内
    frequency = frequency.clamp(87.5, 108.0);

    print('📻 FM频率: ${frequency.toStringAsFixed(1)} MHz');

    Map<String, dynamic> state = {
      'fmFrequency': frequency,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'fmFrequencyChange',
      'source': 'device',
      'rawData': data, // 添加原始数据
    };

    if (!_deviceStateController.isClosed) {
      _deviceStateController.add(state);
    }
  }

  // 新增：处理音效强度响应
  void _handleEffectResponse(List<int> data) {
    print('处理音效强度响应');

    if (data.length >= 3) {
      int effectValue = data[2]; // 音效强度值
      print('设备确认音效强度设置为: $effectValue');

      // 更新UI状态
      Map<String, dynamic> state = {
        'effect': effectValue,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'effectResponse',
        'source': 'device',
        'rawData': data,
      };

      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(state);
      }
    }
  }

  // 新增：处理音量响应
  void _handleVolumeResponse(List<int> data) {
    print('处理音量响应');

    if (data.length >= 3) {
      int volume = data[2]; // 音量值
      print('设备确认音量设置为: $volume');

      // 更新UI状态
      Map<String, dynamic> state = {
        'volume': volume,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'volumeResponse',
        'source': 'device',
        'rawData': data,
      };

      if (!_deviceStateController.isClosed) {
        _deviceStateController.add(state);
      }
    }
  }

  // 检查连接状态
  Stream<BluetoothConnectionState> getConnectionState() {
    if (connectedDevice != null) {
      return connectedDevice!.connectionState;
    }
    return Stream.value(BluetoothConnectionState.disconnected);
  }

  // 检查蓝牙是否可用
  Stream<bool> get isBluetoothAvailable {
    return FlutterBluePlus.adapterState.map((state) {
      return state == BluetoothAdapterState.on;
    });
  }

  // 更新连接状态 - 改为公共方法
  void updateConnectionStatus(bool connected) {
    print('Update connection status: $connected');
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(connected);
    }
  }

  // 检查并更新连接状态
  void _checkAndUpdateConnectionStatus() {
    try {
      isReallyConnected.then((reallyConnected) {
        print('Check connection status result: $reallyConnected');
        updateConnectionStatus(reallyConnected);
      });
    } catch (e) {
      print('Error occurred when checking connection status: $e');
      updateConnectionStatus(false);
    }
  }

  // 检查是否已连接（简单检查）
  bool get isConnected {
    return connectedDevice != null && writeCharacteristic != null;
  }

  // 获取真实的连接状态（详细检查）
  Future<bool> get isReallyConnected async {
    if (connectedDevice == null) {
      print('❌ No connected devices');
      return false;
    }

    try {
      // 检查设备物理连接状态
      bool deviceConnected = await connectedDevice!.isConnected;
      if (!deviceConnected) {
        print('❌ The physical connection of the device has been disconnected');
        return false;
      }

      // 检查写入特征是否可用
      bool writeCharAvailable = writeCharacteristic != null;
      if (!writeCharAvailable) {
        print('❌ Write-in features not available');
      }

      // 只有设备连接且写入特征可用才认为是真正连接
      bool reallyConnected = deviceConnected && writeCharAvailable;
      print('True connection status: $reallyConnected (Device connection: $deviceConnected, Write features: $writeCharAvailable)');

      return reallyConnected;
    } catch (e) {
      print('❌ Error checking the real connection status: $e');
      return false;
    }
  }

  // 手动刷新连接状态
  Future<void> refreshConnectionStatus() async {
    print('Manually refresh connection status');
    _checkAndUpdateConnectionStatus();
  }

  // 重新发现服务（用于修复连接）
  Future<bool> rediscoverServices() async {
    print('Rediscover the service');

    if (connectedDevice == null) {
      print('❌ No connected devices, unable to rediscover services');
      return false;
    }

    try {
      // 清理现有特征
      writeCharacteristic = null;
      readCharacteristic = null;

      // 重新发现服务
      List<BluetoothService> services = await connectedDevice!.discoverServices(timeout: 10000);

      bool foundWriteChar = false;
      bool foundReadChar = false;

      for (BluetoothService service in services) {
        String serviceUuidLower = service.uuid.toString().toLowerCase();

        if (serviceUuidLower.contains('ae30')) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toLowerCase();

            // 查找写入特征
            if ((charUuid.contains('ae01')) &&
                (characteristic.properties.write || characteristic.properties.writeWithoutResponse)) {
              writeCharacteristic = characteristic;
              foundWriteChar = true;
              print('✅ 重新找到写入特征');
            }

            // 查找读取特征
            if ((charUuid.contains('ae02')) &&
                characteristic.properties.notify) {
              readCharacteristic = characteristic;
              foundReadChar = true;
              print('✅ 重新找到读取特征');

              // 启用通知
              try {
                await characteristic.setNotifyValue(true);
                print('✅ 重新启用通知');
              } catch (e) {
                print('⚠️ 重新启用通知失败: $e');
              }
            }
          }
        }
      }

      // 更新连接状态
      bool success = foundWriteChar && foundReadChar;
      updateConnectionStatus(success);

      if (success) {
        print('✅ 服务重新发现成功');
      } else {
        print('❌ 服务重新发现失败，未找到写入特征或读取特征');
        print('找到写入特征: $foundWriteChar, 找到读取特征: $foundReadChar');
      }

      return success;
    } catch (e) {
      print('❌ 重新发现服务时出错: $e');
      updateConnectionStatus(false);
      return false;
    }
  }

  // 读取设备状态（占位方法）
  Future<Map<String, dynamic>?> readDeviceState() async {
    print('读取设备状态 - 当前未实现');
    return null;
  }

  // 释放资源
  void dispose() {
    print('释放蓝牙服务资源');
    _connectionStatusController.close();
    _deviceStateController.close();
    _deviceStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _connectionCheckTimer?.cancel();
    _deviceStateSubscription = null;
    _adapterStateSubscription = null;
    _connectionCheckTimer = null;
  }

  // 保存连接的设备信息
  Future<void> saveConnectedDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_connected_device_id', device.id.id);
      await prefs.setString('last_connected_device_name', device.name);
      print('✅ Saved device info: ${device.name} (${device.id.id})');
    } catch (e) {
      print('❌ Failed to save device info: $e');
    }
  }

  // 获取最后连接的设备信息
  Future<Map<String, String>?> getLastConnectedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('last_connected_device_id');
      final deviceName = prefs.getString('last_connected_device_name');

      if (deviceId != null && deviceName != null) {
        print('📱 Found last connected device: $deviceName ($deviceId)');
        return {
          'id': deviceId,
          'name': deviceName,
        };
      }
      print('📱 No last connected device found');
      return null;
    } catch (e) {
      print('❌ Failed to get last connected device: $e');
      return null;
    }
  }

  // 清除保存的设备信息
  Future<void> clearSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_connected_device_id');
      await prefs.remove('last_connected_device_name');
      print('✅ Cleared saved device info');
    } catch (e) {
      print('❌ Failed to clear saved device: $e');
    }
  }

  // 自动连接到最后一次连接的设备
  Future<bool> autoConnectToLastDevice() async {
    try {
      print('=== Starting auto-connect to last device ===');

      // 获取保存的设备信息
      Map<String, String>? lastDevice = await getLastConnectedDevice();
      if (lastDevice == null) {
        print('❌ No last device found for auto-connect');
        return false;
      }

      String deviceId = lastDevice['id']!;
      String deviceName = lastDevice['name']!;

      print('🔍 Looking for device: $deviceName ($deviceId)');

      // 检查蓝牙状态
      bool isBluetoothOn = await FlutterBluePlus.isOn;
      if (!isBluetoothOn) {
        print('❌ Bluetooth is not available');
        return false;
      }

      // 首先检查已连接的设备
      List<BluetoothDevice> connectedDevices = await FlutterBluePlus.connectedDevices;
      for (BluetoothDevice device in connectedDevices) {
        if (device.id.id == deviceId) {
          print('✅ Device already connected, initializing...');
          connectedDevice = device;

          // 重新发现服务
          bool success = await rediscoverServices();
          if (success) {
            updateConnectionStatus(true);
            print('✅ Auto-connect successful');
            return true;
          }
          break;
        }
      }

      // 如果未连接，开始扫描
      print('🔍 Scanning for device...');
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 8));

      Completer<bool> completer = Completer<bool>();
      StreamSubscription? scanSubscription;
      Timer? timeoutTimer;

      timeoutTimer = Timer(Duration(seconds: 8), () {
        scanSubscription?.cancel();
        FlutterBluePlus.stopScan();
        if (!completer.isCompleted) {
          print('❌ Auto-connect timeout');
          completer.complete(false);
        }
      });

      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          if (result.device.id.id == deviceId) {
            print('🎯 Found device, connecting...');

            scanSubscription?.cancel();
            timeoutTimer?.cancel();
            await FlutterBluePlus.stopScan();

            try {
              await connectToDevice(result.device);
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            } catch (e) {
              print('❌ Auto-connect failed: $e');
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            }
            break;
          }
        }
      });

      return await completer.future;

    } catch (e) {
      print('❌ Auto-connect error: $e');
      return false;
    }
  }

  // 添加重试方法
  Future<bool> _enableNotificationsWithRetry(BluetoothCharacteristic characteristic) async {
    for (int i = 0; i < 3; i++) {
      try {
        await characteristic.setNotifyValue(true);
        await Future.delayed(Duration(milliseconds: 300));
        if (characteristic.isNotifying) {
          return true;
        }
      } catch (e) {
        print('启用通知重试 ${i + 1}/3 失败: $e');
      }
    }
    return false;
  }

  // 启动蓝牙适配器状态监听
  void startAdapterStateListener() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) async {
      print('蓝牙适配器状态变化: $state');

      switch (state) {
        case BluetoothAdapterState.on:
          print('✅ 蓝牙已开启');
          // 蓝牙开启后尝试重新连接
          await _attemptReconnectAfterBluetoothEnabled();
          break;
        case BluetoothAdapterState.off:
          print('❌ 蓝牙已关闭');
          // 蓝牙关闭时清理连接
          cleanup();
          break;
        default:
          print('ℹ️ 蓝牙状态变化: $state');
      }
    });
  }

  // 蓝牙开启后尝试重新连接
  Future<void> _attemptReconnectAfterBluetoothEnabled() async {
    try {
      // 延迟一段时间等待蓝牙完全初始化
      await Future.delayed(Duration(seconds: 2));

      // 尝试自动连接到最后一个设备
      bool success = await autoConnectToLastDevice();
      if (success) {
        print('✅ 蓝牙重新开启后自动连接成功');
      } else {
        print('⚠️ 蓝牙重新开启后自动连接失败');
      }
    } catch (e) {
      print('❌ 蓝牙重新开启后尝试连接时发生错误: $e');
    }
  }
}
