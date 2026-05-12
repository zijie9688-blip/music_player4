import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show radians;
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'bluetooth_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothConnectionState;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io'; // 添加 dart:io 以使用 Platform
import 'package:audio_service/audio_service.dart'; // 添加audio_service
import 'audio_handler.dart'; // 需要创建这个文件

void main() async {
  // 确保WidgetsFlutterBinding初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化音频服务
  late AudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => MusicPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.example.digital_signal_processor.channel.audio',
        androidNotificationChannelName: 'Music playback',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );
  } catch (e) {
    // 如果音频服务初始化失败，则创建一个基本的处理器
    print("AudioService initialization failed: $e");
    audioHandler = MusicPlayerHandler();
  }

  runApp(MyApp(audioHandler: audioHandler));
}

class MyApp extends StatelessWidget {
  final AudioHandler audioHandler;

  const MyApp({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Signal Processor',
      theme: ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF0000), // 选中/高亮面板色
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000), // 选中/高亮面板色
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF011C85), // 极深背景色
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF7F7F7)), // 主要标题文字
          displayMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF7F7F7)), // 主要标题文字
          bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Color(0xFFF7F7F7)), // 主要标题文字
          bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Color(0xFFF7F7F7)), // 金属高光边缘
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFFF0000), // 选中/高亮面板色边框
              width: 1,
            ),
          ),
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // 固定字体缩放为1.0，确保App内容不受系统字体设置影响
        return MediaQuery(
          data: mediaQuery.copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      home: AudioControllerScreen(audioHandler: audioHandler), // 传递audioHandler
    );
  }

  // 构建自适应布局以适应大字体
  Widget _buildAdaptiveLayout(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // 判断是否为大屏设备（平板或双屏）
        final isLargeScreen = screenWidth > 425;

        // 计算内容最大宽度，确保在双屏时居中显示
        final maxContentWidth = isLargeScreen ? 600.0 : screenWidth;

        // 计算字体缩放比例，根据屏幕大小自适应
        final textScaleFactor = isLargeScreen ? 1.3 : 1.0;

        // 计算整体缩放比例
        final scale = math.min(
          1.0,
          screenWidth / (isLargeScreen ? 800.0 : 400.0),
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxContentWidth,
            ),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: textScaleFactor,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AudioControllerScreen extends StatefulWidget {
  final AudioHandler audioHandler;

  const AudioControllerScreen({super.key, required this.audioHandler});

  @override
  State<AudioControllerScreen> createState() => _AudioControllerScreenState();
}

// 科技感网格线绘制器
class GridLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF0000).withOpacity(0.15)
      ..strokeWidth = 1;

    final gridSize = 40.0;

    // 绘制垂直线
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 绘制水平线
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 流星组件
class MeteorShower extends StatefulWidget {
  final int count;
  final Duration duration;

  const MeteorShower({
    super.key,
    required this.count,
    required this.duration,
  });

  @override
  State<MeteorShower> createState() => _MeteorShowerState();
}

class _MeteorShowerState extends State<MeteorShower>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final List<MeteorData> _meteors = [];

  @override
  void initState() {
    super.initState();
    _initializeMeteors();
  }

  void _initializeMeteors() {
    _controllers = List.generate(
      widget.count,
      (index) => AnimationController(
        duration: widget.duration,
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    _meteors.clear();
    for (int i = 0; i < widget.count; i++) {
      _meteors.add(MeteorData.random());
      _controllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _meteors[i] = MeteorData.random();
          });
          _controllers[i].reset();
          _controllers[i].forward();
        }
      });
      _controllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.count, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final meteor = _meteors[index];
            final progress = _animations[index].value;

            return Positioned(
              left: meteor.startX +
                  progress * meteor.distance * math.cos(meteor.angle),
              top: meteor.startY +
                  progress * meteor.distance * math.sin(meteor.angle),
              child: Transform.rotate(
                angle: meteor.angle,
                child: Opacity(
                  opacity: 1 - progress,
                  child: CustomPaint(
                    size: const Size(100, 2),
                    painter: MeteorPainter(),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class MeteorData {
  final double startX;
  final double startY;
  final double angle;
  final double distance;

  MeteorData({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.distance,
  });

  factory MeteorData.random() {
    final random = math.Random();
    return MeteorData(
      startX: random.nextDouble() * 400 - 100,
      startY: random.nextDouble() * 300 - 100,
      angle: math.pi / 4 + random.nextDouble() * 0.2,
      distance: 500 + random.nextDouble() * 300,
    );
  }
}

class MeteorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFFFF0000).withOpacity(0.9),
        const Color(0xFFFF0000),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2 - 1)
      ..lineTo(size.width, size.height / 2 + 1)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 科技感粒子组件
class TechParticles extends StatefulWidget {
  final int count;

  const TechParticles({
    super.key,
    required this.count,
  });

  @override
  State<TechParticles> createState() => _TechParticlesState();
}

class _TechParticlesState extends State<TechParticles>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _initializeParticles();
  }

  void _initializeParticles() {
    _controllers = List.generate(
      widget.count,
      (index) => AnimationController(
        duration: Duration(milliseconds: 2000 + math.Random().nextInt(3000)),
        vsync: this,
      ),
    );

    _particles = List.generate(
      widget.count,
      (index) => ParticleData.random(),
    );

    for (int i = 0; i < widget.count; i++) {
      _controllers[i].addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _particles[i] = ParticleData.random();
          });
          _controllers[i].reset();
          _controllers[i].forward();
        }
      });
      _controllers[i].forward();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.count, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            final particle = _particles[index];
            final progress = _controllers[index].value;
            final opacity = (1 - progress) * particle.maxOpacity;

            return Positioned(
              left: particle.x,
              top: particle.y - progress * 100,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: particle.color.withOpacity(opacity),
                    boxShadow: [
                      BoxShadow(
                        color: particle.color.withOpacity(opacity * 0.5),
                        blurRadius: particle.size,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class ParticleData {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double maxOpacity;

  ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.maxOpacity,
  });

  factory ParticleData.random() {
    final random = math.Random();
    return ParticleData(
      x: random.nextDouble() * 400,
      y: random.nextDouble() * 800,
      size: 2.0 + random.nextDouble() * 4.0,
      color: [
        const Color(0xFFFF0000),
        const Color(0xFFF7F7F7),
        const Color(0xFF011C85),
      ][random.nextInt(3)],
      maxOpacity: 0.5 + random.nextDouble() * 0.5,
    );
  }
}

class _AudioControllerScreenState extends State<AudioControllerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  double volumeValue = 16.0;
  double effectValue = 16.0;
  int reverbValue = 0; // Reverb值，范围0-16
  int echoValue = 0; // Echo值，范围0-16
  String selectedEffect = 'Normal';
  bool isConnected = false;
  bool isScanning = false;
  bool isConnecting = false;
  List<dynamic> devices = [];
  Map<String, BluetoothConnectionState> deviceConnectionStates = {};

  // 新增状态变量
  String selectedInputSource = 'BT'; // FM, AUX, USB/SD, BT
  bool isPlaying = false;
  String selectedXBass = '0'; // 0, 1, 2, 3
  String selectedEffectMode = 'MAN'; // MAN, GIRL

  final AmpBluetoothService _bluetoothService = AmpBluetoothService();
  static double _sharedVolumeValue = 16.0;
  bool _isMuted = false; // 新增静音状态
  bool _isPriorityEnabled = false; // PRIORITY开关状态
  bool _isFbxEnabled = false; // FBX开关状态

  // FM频率相关状态
  double _fmFrequency = 88.0; // FM频率，单位MHz
  final double _minFMFrequency = 87.5; // 最小FM频率
  final double _maxFMFrequency = 108.0; // 最大FM频率
  final double _fmStep = 0.1; // FM频率步进
  Timer? _fmFrequencyDebounceTimer; // FM频率防抖定时器

  static double get sharedVolumeValue => _sharedVolumeValue;
  static void setSharedVolumeValue(double value) {
    _sharedVolumeValue = value;
  }

  Offset? _volumeStartPos;
  Offset? _effectStartPos;
  double _volumeStartValue = 16.0;
  double _effectStartValue = 16.0;
  bool _isPageActive = true;
  final FocusNode _focusNode = FocusNode();

  late AnimationController _muteAnimationController;
  late Animation<double> _muteAnimation;

  bool _hasShownConnectionError = false;
  bool _shouldNavigateToBluetooth = false;

  Timer? _volumeThrottleTimer;
  Timer? _effectThrottleTimer;
  double _lastSentVolume = 16.0;
  double _lastSentEffect = 16.0;
  bool _isVolumeDragging = false;
  bool _isEffectDragging = false;

  bool _isReconnecting = false;

  bool _hasShownSyncSuccess = false;
  bool _hasShownSyncError = false;

  // 添加设备状态监听
  StreamSubscription<Map<String, dynamic>>? _deviceStateSubscription;
  bool _isReceivingDeviceState = false;
  bool _hasRequestedInitialState = false;
  bool _isBluetoothEnabled = true;
  StreamSubscription<BluetoothAdapterState>? _bluetoothAdapterSubscription;

  // UI更新频率控制
  int _lastUIUpdateTime = 0;

  // 全局用户交互状态控制
  bool _isUserInteracting = false;
  Timer? _userInteractionTimer;

  // 设置用户正在交互的标志
  void _setUserInteracting() {
    _isUserInteracting = true;
    _userInteractionTimer?.cancel();
    _userInteractionTimer = Timer(Duration(seconds: 1), () {
      _isUserInteracting = false;
    });
  }

  final List<String> soundEffects = [
    'Normal',
    'Classic',
    'POP',
    'Rock',
    'Jazz',
    'Vocal Booster'
  ];

  // 新增选项列表
  final List<String> inputSources = ['FM', 'AUX', 'USB/SD', 'BT'];
  final List<String> xbassOptions = ['OFF', '1', '2', '3'];
  final List<String> effectModes = ['Normal', 'GIRL', 'MAN'];

  StreamSubscription<bool>? _connectionStatusSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSubscription;

  // 添加audio_service播放状态监听
  StreamSubscription<PlaybackState>? _playbackStateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _muteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _muteAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
          parent: _muteAnimationController, curve: Curves.easeInOut),
    );

    _initializeBluetoothListeners();
    _startBluetoothAdapterMonitoring();
    _initializeDeviceStateListener();

    // 添加连接健康监控
    _startConnectionHealthCheck();

    // 监听audio_service播放状态
    _initializeAudioServiceListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshBluetoothState();

      Future.delayed(Duration(seconds: 3), () async {
        if (mounted) {
          print('🚀 Starting delayed auto-connect...');
          await _tryAutoConnectWithRetry();
        }
      });
    });
  }

  // 新增：初始化audio_service监听
  void _initializeAudioServiceListeners() {
    // 监听播放状态
    _playbackStateSubscription =
        widget.audioHandler.playbackState.listen((playbackState) {
      if (mounted && selectedInputSource == 'BT') {
        setState(() {
          isPlaying = playbackState.playing;
        });
        print('AudioService playback state updated: $isPlaying');
      }
    });

    // 监听媒体信息变化
    widget.audioHandler.mediaItem.listen((mediaItem) {
      if (mounted && selectedInputSource == 'BT') {
        print('AudioService media item updated: ${mediaItem?.title}');
      }
    });
  }

  // 新增：FM频率相关方法
  void _onFMFrequencyChanged(double value) {
    _setUserInteracting(); // 设置用户交互标志

    // 限制频率到指定范围，并保留一位小数
    double newFrequency = (value * 10).round() / 10.0;
    newFrequency = newFrequency.clamp(_minFMFrequency, _maxFMFrequency);

    setState(() {
      _fmFrequency = newFrequency;
    });

    // 取消之前的定时器
    _fmFrequencyDebounceTimer?.cancel();

    // 设置新的定时器，延迟500ms后发送指令
    _fmFrequencyDebounceTimer = Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _sendFMFrequencyCommand(newFrequency);
      }
    });
  }

  void _increaseFMFrequency() {
    _setUserInteracting(); // 设置用户交互标志

    double newFrequency = _fmFrequency + _fmStep;
    if (newFrequency <= _maxFMFrequency) {
      setState(() {
        _fmFrequency = newFrequency;
      });
      _sendFMFrequencyCommand(newFrequency);
    }
  }

  void _decreaseFMFrequency() {
    _setUserInteracting(); // 设置用户交互标志

    double newFrequency = _fmFrequency - _fmStep;
    if (newFrequency >= _minFMFrequency) {
      setState(() {
        _fmFrequency = newFrequency;
      });
      _sendFMFrequencyCommand(newFrequency);
    }
  }

  Future<void> _sendFMFrequencyCommand(double frequency) async {
    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      // 这里需要根据实际蓝牙协议发送FM频率指令
      print('Setting FM frequency to: ${frequency.toStringAsFixed(1)} MHz');
      await _bluetoothService.sendFMFrequencyCommand(frequency);

      // 暂时使用提示
      _showSuccess('FM frequency set to ${frequency.toStringAsFixed(1)} MHz');
    } catch (e) {
      print('Failed to send FM frequency command: $e');
      _showError('Failed to set FM frequency');
    }
  }

  // 添加连接健康检查方法
  void _startConnectionHealthCheck() {
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (await _bluetoothService.isReallyConnected &&
          _bluetoothService.readCharacteristic != null) {
        // 检查通知是否仍然有效
        if (!_bluetoothService.readCharacteristic!.isNotifying) {
          print('⚠️ 通知特征已断开，尝试重新启用...');
          try {
            await _bluetoothService.readCharacteristic!.setNotifyValue(true);
            print('✅ 通知特征重新启用成功');
          } catch (e) {
            print('❌ 重新启用通知失败: $e');
          }
        }
      }
    });
  }

  // 新增：初始化设备状态监听
  void _initializeDeviceStateListener() {
    print('初始化设备状态监听器...');

    _deviceStateSubscription?.cancel();
    _deviceStateSubscription =
        _bluetoothService.deviceStateStream.listen((state) {
      print('收到设备状态更新: $state');
      _updateUIFromDeviceState(state);
    }, onError: (error) {
      print('设备状态监听错误: $error');
    });
  }

  // 新增：根据设备状态更新UI
  void _updateUIFromDeviceState(Map<String, dynamic> state) {
    if (!mounted) return;

    // 如果用户正在交互，忽略设备通知（避免设备响应覆盖用户操作）
    if (_isUserInteracting) {
      print('⏱️ 用户正在交互，忽略设备通知');
      return;
    }

    // 检查更新频率，限制为每200毫秒最多更新一次
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    const int minUpdateInterval = 1000; // 最小更新间隔1000毫秒

    if (currentTime - _lastUIUpdateTime < minUpdateInterval) {
      print(
          '⏱️ UI更新频率过高，跳过本次更新 (距离上次更新: ${currentTime - _lastUIUpdateTime}ms)');
      return;
    }

    _lastUIUpdateTime = currentTime;

    print('根据设备状态更新UI: $state');

    setState(() {
      _isReceivingDeviceState = true;

      // 更新音量
      if (state.containsKey('volume') && !_isVolumeDragging) {
        int volume = state['volume'];
        if (volume >= 0 && volume <= 32) {
          volumeValue = volume.toDouble();

          // 如果音量不为0，更新共享音量值（用于静音恢复）
          if (volume > 0) {
            setSharedVolumeValue(volume.toDouble());
          }

          print('📊 更新UI音量: $volume');
        }
      }

      // 更新效果强度
      if (state.containsKey('effect') && !_isEffectDragging) {
        int effect = state['effect'];
        if (effect >= 0 && effect <= 32) {
          effectValue = effect.toDouble();
          print('📊 更新UI效果强度: $effect');
        }
      }

      // 更新音效模式
      if (state.containsKey('effectMode')) {
        int effectMode = state['effectMode'];
        if (effectMode >= 0 && effectMode < soundEffects.length) {
          selectedEffect = soundEffects[effectMode];
          print('📊 更新UI音效模式: $selectedEffect (索引: $effectMode)');
        }
      }

      // 更新输入源

      if (state.containsKey('inputSource')) {
        String inputSource = state['inputSource'];
        if (inputSources.contains(inputSource)) {
          selectedInputSource = inputSource;
          print('📊 更新UI输入源: $inputSource');

          // 如果是FM模式，更新FM频率（如果有的话）
          if (inputSource == 'FM' && state.containsKey('fmFrequency')) {
            double fmFreq = state['fmFrequency'];
            if (fmFreq >= _minFMFrequency && fmFreq <= _maxFMFrequency) {
              _fmFrequency = fmFreq;
              print('📊 更新UI FM频率: $fmFreq MHz');
            }
          }
        }
      }

      // 更新播放状态（非FM模式时使用设备状态）
      if (state.containsKey('isPlaying') && selectedInputSource != 'FM') {
        bool playing = state['isPlaying'];
        setState(() {
          isPlaying = playing;
        });
        print('📊 更新UI播放状态: $playing (当前输入源: $selectedInputSource)');
      }

      // 更新X.BASS
      if (state.containsKey('xBass')) {
        String xBass = state['xBass'];
        if (xbassOptions.contains(xBass)) {
          selectedXBass = xBass;
          print('📊 更新UI X.BASS: $xBass');
        }
      }

      // 更新效果模式
      if (state.containsKey('effectModeType')) {
        String effectModeType = state['effectModeType'];
        if (effectModes.contains(effectModeType)) {
          selectedEffectMode = effectModeType;
          print('📊 更新UI效果模式: $effectModeType');
        }
      }

      // 更新音效效果（优先使用musicEQ字段）
      if (state.containsKey('musicEQ')) {
        int musicEQ = state['musicEQ'];
        if (musicEQ >= 0 && musicEQ < soundEffects.length) {
          selectedEffect = soundEffects[musicEQ];
          print('📊 更新UI音效效果: $selectedEffect (musicEQ索引: $musicEQ)');
        }
      }
      // 兼容旧的soundEffects字段
      else if (state.containsKey('soundEffects')) {
        int soundEffectsIndex = state['soundEffects'];
        if (soundEffectsIndex >= 0 &&
            soundEffectsIndex < this.soundEffects.length) {
          selectedEffect = this.soundEffects[soundEffectsIndex];
          print(
              '📊 更新UI音效效果: $selectedEffect (soundEffects索引: $soundEffectsIndex)');
        }
      }

      // 更新KARAOKE
      if (state.containsKey('karaoke')) {
        int karaoke = state['karaoke'];
        print('📊 更新UI KARAOKE: $karaoke');
        // 更新KARAOKE UI状态
        setState(() {
          effectValue = karaoke.toDouble();
        });
      }

      // 更新MIC MODE
      if (state.containsKey('micMode')) {
        String micMode = state['micMode'];
        if (effectModes.contains(micMode)) {
          selectedEffectMode = micMode;
          print('📊 更新UI MIC MODE: $micMode');
        }
      }

      // 更新FM频率（独立处理，不依赖于输入源）
      if (state.containsKey('fmFrequency')) {
        double fmFreq = state['fmFrequency'];
        if (fmFreq >= _minFMFrequency && fmFreq <= _maxFMFrequency) {
          _fmFrequency = fmFreq;
          print('📊 更新UI FM频率: $fmFreq MHz');
        }
      }

      // 更新Reverb
      if (state.containsKey('reverb')) {
        int reverb = state['reverb'];
        if (reverb >= 0 && reverb <= 16) {
          reverbValue = reverb;
          print('📊 更新UI Reverb: $reverb');
        }
      }

      // 更新Echo
      if (state.containsKey('echo')) {
        int echo = state['echo'];
        if (echo >= 0 && echo <= 16) {
          echoValue = echo;
          print('📊 更新UI Echo: $echo');
        }
      }

      // 更新FBX
      if (state.containsKey('fbx')) {
        int fbx = state['fbx'];
        if (fbx >= 0 && fbx <= 1) {
          _isFbxEnabled = fbx == 1;
          print('📊 更新UI FBX: $fbx ($_isFbxEnabled)');
        }
      }

      // 更新PRIORITY
      if (state.containsKey('priority')) {
        int priority = state['priority'];
        if (priority >= 0 && priority <= 1) {
          _isPriorityEnabled = priority == 1;
          print('📊 更新UI PRIORITY: $priority ($_isPriorityEnabled)');
        }
      }
    });

    // 显示状态同步成功提示（仅对完整状态响应）
    if (state['type'] == 'stateResponse' && !_hasShownSyncSuccess) {
      _showSuccess('Device status has been synchronized');
      _hasShownSyncSuccess = true;
    }

    // 重置状态接收标志
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isReceivingDeviceState = false;
        });
      }
    });
  }

  // 新增：开始监控蓝牙适配器状态
  void _startBluetoothAdapterMonitoring() {
    _bluetoothAdapterSubscription?.cancel();
    _bluetoothAdapterSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      print('Bluetooth adapter state change: $state');

      if (mounted) {
        setState(() {
          _isBluetoothEnabled = state == BluetoothAdapterState.on;
        });

        if (state == BluetoothAdapterState.off) {
          // 蓝牙被关闭，立即更新连接状态
          print(
              '❌ Bluetooth adapter is turned off, disconnect all connections');
          _handleBluetoothDisabled();
        } else if (state == BluetoothAdapterState.on) {
          // 蓝牙重新开启，尝试重新连接
          print('✅ Bluetooth adapter is turned on, trying to reconnect');
          _handleBluetoothEnabled();
        }
      }
    });
  }

  // 处理蓝牙禁用
  void _handleBluetoothDisabled() {
    if (mounted) {
      setState(() {
        isConnected = false;
        _isReconnecting = false;
      });
    }

    // 清理蓝牙服务状态
    _bluetoothService.cleanup();

    _showError('Bluetooth is turned off, device connection is disconnected');
  }

  // 处理蓝牙启用
  void _handleBluetoothEnabled() {
    // 检查之前是否已连接设备
    _refreshBluetoothState();

    // 延迟尝试重新连接
    Future.delayed(Duration(seconds: 2), () {
      if (mounted && !isConnected) {
        _tryAutoConnectWithRetry();
      }
    });
  }

  Future<void> _tryAutoConnectWithRetry() async {
    print('🔄 Starting auto-connect with retry mechanism...');

    if (mounted) {
      setState(() {
        _isReconnecting = true;
        _hasRequestedInitialState = false; // 重置状态请求标志
      });
    }

    Timer reconnectTimeout;
    reconnectTimeout = Timer(Duration(seconds: 30), () {
      print('⏰ 自动重连超时，停止重连尝试');
      if (mounted) {
        setState(() {
          _isReconnecting = false;
        });
      }
    });

    try {
      bool isBluetoothOn = await FlutterBluePlus.isOn;
      if (!isBluetoothOn) {
        print('📱 Bluetooth is off, waiting for it to turn on...');
        await Future.delayed(Duration(seconds: 2));
        isBluetoothOn = await FlutterBluePlus.isOn;
        if (!isBluetoothOn) {
          print('❌ Bluetooth still off, cannot auto-connect');
          if (mounted) {
            setState(() {
              _isReconnecting = false;
            });
          }
          reconnectTimeout.cancel();
          return;
        }
      }

      Map<String, String>? lastDevice =
          await _bluetoothService.getLastConnectedDevice();
      if (lastDevice == null) {
        print('📱 No previous device found for auto-connect');
        if (mounted) {
          setState(() {
            _isReconnecting = false;
          });
        }
        reconnectTimeout.cancel();
        return;
      }

      print('🎯 Attempting to auto-connect to: ${lastDevice['name']}');

      bool autoConnected = await _bluetoothService.autoConnectToLastDevice();

      if (autoConnected && mounted) {
        print('✅ Auto-connect successful!');
        setState(() {
          isConnected = true;
          _isReconnecting = false;
        });

        // 自动连接成功后读取设备状态
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && isConnected) {
            print('🔄 自动连接成功，读取设备状态...');
            _readDeviceCurrentState();
          }
        });
      } else {
        print('❌ Auto-connect failed, will retry in 5 seconds...');
        Future.delayed(Duration(seconds: 5), () {
          if (mounted && !isConnected && _isReconnecting) {
            _tryAutoConnectWithRetry();
          } else if (mounted) {
            setState(() {
              _isReconnecting = false;
            });
          }
        });
      }
    } catch (e) {
      print('❌ Auto-connect error: $e');
      if (mounted) {
        setState(() {
          _isReconnecting = false;
        });
      }
    } finally {
      reconnectTimeout.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionStatusSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    _deviceStateSubscription?.cancel(); // 新增：取消设备状态监听
    _bluetoothAdapterSubscription?.cancel();
    _muteAnimationController.dispose();

    _volumeThrottleTimer?.cancel();
    _effectThrottleTimer?.cancel();

    // 取消audio_service监听
    _playbackStateSubscription?.cancel();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('App lifecycle state changed: $state');

    if (state == AppLifecycleState.resumed) {
      print('App resumed, refreshing Bluetooth state...');
      _refreshBluetoothState();

      if (!isConnected) {
        Future.delayed(Duration(seconds: 2), () async {
          bool connected = await _bluetoothService.isReallyConnected;
          if (!connected && mounted) {
            print('Not connected on resume, retrying auto-connect...');
            await _bluetoothService.autoConnectToLastDevice();
          }
        });
      }
    }
  }

  void _initializeBluetoothListeners() {
    print('初始化蓝牙监听器...');

    // 启动蓝牙适配器状态监听
    _bluetoothService.startAdapterStateListener();

    _connectionStatusSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();

    _connectionStatusSubscription =
        _bluetoothService.connectionStatusStream.listen((connected) {
      print('蓝牙服务连接状态变化: $connected');
      if (mounted) {
        setState(() {
          isConnected = connected;
          if (!connected) {
            _isReconnecting = false;
            _hasRequestedInitialState = false; // 重置状态请求标志
          }
        });

        if (connected) {
          _hasShownSyncSuccess = false;
          _hasShownSyncError = false;
          print('Connection state change, reset prompt state');

          // 连接成功后读取设备状态
          if (!_hasRequestedInitialState) {
            print(
                'The device is connected, reading the current status of the device...');
            Future.delayed(Duration(milliseconds: 2000), () {
              if (mounted && isConnected) {
                _readDeviceCurrentState();
              }
            });
          }
        } else {
          print('The device has been disconnected');
          _isReconnecting = false;
          // 断开连接时显示提示
          if (!_hasShownConnectionError) {
            _showError('The device connection has been disconnected');
            _hasShownConnectionError = true;
          }
        }
      }
    }, onError: (error) {
      print('Connection state listening error: $error');
      if (mounted) {
        setState(() {
          isConnected = false;
          _isReconnecting = false;
        });
      }
    });

    _deviceConnectionSubscription =
        _bluetoothService.getConnectionState().listen((state) {
      if (mounted) {
        print('Physical connection status change of the device: $state');
        bool connected = state == BluetoothConnectionState.connected;

        if (isConnected != connected) {
          setState(() {
            isConnected = connected;
            if (!connected) {
              _isReconnecting = false;
              _hasRequestedInitialState = false; // 重置状态请求标志
            }
          });
          print('Physical device state triggers UI update: $connected');
        }

        if (connected) {
          print('Physical device connection has been established');
          _hasShownConnectionError = false;

          // 物理连接建立后读取设备状态
          if (!_hasRequestedInitialState) {
            Future.delayed(Duration(milliseconds: 1500), () {
              if (mounted && isConnected) {
                print('Physical device connection is stable, read status...');
                _readDeviceCurrentState();
              }
            });
          }
        } else {
          print('The physical connection of the device has been disconnected');
          _isReconnecting = false;
          // 物理断开时显示提示
          if (!_hasShownConnectionError) {
            _showError(
                'The physical connection of the device has been disconnected');
            _hasShownConnectionError = true;
          }
        }
      }
    }, onError: (error) {
      print('Device status listening error: $error');
      if (mounted) {
        setState(() {
          isConnected = false;
          _isReconnecting = false;
        });
        _showError('Anomalies in device connection: $error');
      }
    });

    print('Bluetooth listener initialized');
  }

  // 新增：读取设备当前状态
  Future<void> _readDeviceCurrentState() async {
    if (!await _bluetoothService.isReallyConnected) {
      print('❌ The device is not connected, unable to read status');
      return;
    }

    if (_hasRequestedInitialState) {
      print(
          '⏸️ Initial state has already been requested, skipping duplicate request');
      return;
    }

    print('🔄 Read the current status of the device...');

    setState(() {
      _isReceivingDeviceState = true;
      _hasRequestedInitialState = true;
    });

    try {
      await _bluetoothService.readDeviceCurrentState();
      print('✅ Status read request has been sent');

      // 设置超时，防止状态读取失败
      Future.delayed(Duration(seconds: 5), () {
        if (mounted && _isReceivingDeviceState) {
          print('⏰ Status read timeout, reset status');
          setState(() {
            _isReceivingDeviceState = false;
          });
        }
      });
    } catch (e) {
      print('❌ Failed to send status read request: $e');
      if (mounted) {
        setState(() {
          _isReceivingDeviceState = false;
          _hasRequestedInitialState = false; // 允许重试
        });
      }
    }
  }

  void _refreshBluetoothState() async {
    try {
      print('=== 开始刷新蓝牙状态 ===');

      // 首先检查蓝牙适配器状态
      bool isBluetoothOn = await FlutterBluePlus.isOn;
      if (!isBluetoothOn) {
        print('❌ 蓝牙适配器未开启');
        if (mounted) {
          setState(() {
            isConnected = false;
            _isReconnecting = false;
          });
        }
        return;
      }

      bool reallyConnected = await _bluetoothService.isReallyConnected;
      print('真实连接状态: $reallyConnected');

      // 如果服务显示已连接但实际未连接，强制更新状态
      if (isConnected && !reallyConnected) {
        print('⚠️ 状态不一致，强制更新为未连接');
        if (mounted) {
          setState(() {
            isConnected = false;
            _isReconnecting = false;
          });
        }
        _bluetoothService.updateConnectionStatus(false);
      }

      bool deviceConnected = _bluetoothService.connectedDevice != null &&
          await _bluetoothService.connectedDevice!.isConnected;
      print('设备连接状态: $deviceConnected');

      bool hasWriteChar = _bluetoothService.writeCharacteristic != null;
      print('写入特征可用: $hasWriteChar');

      bool finalConnected = reallyConnected && deviceConnected && hasWriteChar;

      print('最终连接状态: $finalConnected');

      if (mounted) {
        if (isConnected != finalConnected) {
          setState(() {
            isConnected = finalConnected;
          });
        }
      }

      // 如果已经连接，读取设备状态
      if (finalConnected && !_hasRequestedInitialState) {
        print('设备已连接，读取设备当前状态...');
        Future.delayed(Duration(milliseconds: 1500), () {
          if (mounted && isConnected) {
            _readDeviceCurrentState();
          }
        });
      }
    } catch (e) {
      print('刷新蓝牙状态时出错: $e');
      if (mounted) {
        setState(() {
          isConnected = false;
          _isReconnecting = false;
        });
      }
    }
  }

  // 新增：输入源选择方法
  void _selectInputSource(String source) async {
    _setUserInteracting(); // 设置用户交互标志

    setState(() {
      selectedInputSource = source;
    });

    // 如果是BT模式，自动连接到audio_service并获取当前播放状态
    if (source == 'BT') {
      try {
        // 获取当前播放状态
        final playbackState = widget.audioHandler.playbackState.value;
        setState(() {
          isPlaying = playbackState.playing;
        });
        print('BT模式: AudioService播放状态 - $isPlaying');

        // 触发开始按钮指令
        _playPause();
      } catch (e) {
        print('获取AudioService播放状态失败: $e');
      }
    }

    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      // 发送输入源选择指令到设备
      print('Selecting input source: $source');

      // 根据选择的输入源发送相应的指令
      switch (source) {
        case 'BT':
          await _bluetoothService.switchToBT();
          break;
        case 'AUX':
          await _bluetoothService.switchToAUX();
          break;
        case 'USB/SD':
          await _bluetoothService.switchToUSB();
          break;
        case 'FM':
          await _bluetoothService.switchToFM();
          break;
      }

      // 根据输入源切换UI逻辑
      if (source == 'FM') {
        // 切换到FM模式，自动设置播放状态为true
        isPlaying = true;
      } else if (source != 'BT') {
        // 其他模式（非BT，非FM），重置播放状态
        isPlaying = false;
      }

      _showSuccess('Input source changed to $source');
    } catch (e) {
      print('Failed to send input source command: $e');
      _showError('Failed to change input source');
    }
  }

  // 新增：发送播放/暂停指令（用于FM模式刷新按钮）
  void _sendPlayPauseCommand() async {
    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      print('Sending play/pause command (refresh)');
      await _bluetoothService.playPause();
      _showSuccess('Play/Pause command sent');
    } catch (e) {
      print('Failed to send play/pause command: $e');
      _showError('Failed to send play/pause command');
    }
  }

  // 新增：播放控制方法
  void _playPause() async {
    _setUserInteracting(); // 设置用户交互标志

    // 根据输入源选择不同的控制方式
    if (selectedInputSource == 'BT') {
      // BT模式：使用蓝牙指令控制
      _playPauseWithBluetooth();
    } else {
      // 其他模式：使用原来的蓝牙指令控制
      _playPauseWithBluetooth();
    }
  }

  // BT模式：使用audio_service控制播放
  void _playPauseWithAudioService() {
    try {
      if (isPlaying) {
        widget.audioHandler.pause();
        print('AudioService: Pausing playback');
      } else {
        widget.audioHandler.play();
        print('AudioService: Starting playback');
      }
      // 状态将通过监听器自动更新
    } catch (e) {
      print('Failed to control playback with AudioService: $e');
      _showError('Failed to control playback');
    }
  }

  // 其他模式：使用蓝牙指令控制
  void _playPauseWithBluetooth() async {
    setState(() {
      isPlaying = !isPlaying;
    });

    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      // 发送播放/暂停指令
      print('Sending play/pause command via Bluetooth');
      await _bluetoothService.playPause();

      // 更新播放状态
      setState(() {
        isPlaying = !isPlaying;
      });

      // BT模式下不显示弹窗提示
      if (selectedInputSource != 'BT') {
        _showSuccess(isPlaying ? 'Playing' : 'Paused');
      }
    } catch (e) {
      print('Failed to send play/pause command: $e');
      _showError('Failed to control playback');
    }
  }

  void _previousTrack() async {
    _setUserInteracting(); // 设置用户交互标志

    // 根据输入源选择不同的控制方式
    if (selectedInputSource == 'BT') {
      // BT模式：使用蓝牙指令控制
      _previousTrackWithBluetooth();
    } else {
      // 其他模式：使用原来的蓝牙指令控制
      _previousTrackWithBluetooth();
    }
  }

  void _previousTrackWithAudioService() {
    try {
      widget.audioHandler.skipToPrevious();
      print('AudioService: Skipping to previous track');
      _showSuccess('Previous track');
    } catch (e) {
      print('Failed to skip to previous track with AudioService: $e');
      _showError('Failed to go to previous track');
    }
  }

  void _previousTrackWithBluetooth() async {
    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      print('Sending previous track command via Bluetooth');
      await _bluetoothService.previousTrack();
      // BT和USB/SD模式下不显示弹窗提示
      if (selectedInputSource != 'BT' && selectedInputSource != 'USB/SD') {
        _showSuccess('Previous track');
      }
    } catch (e) {
      print('Failed to send previous track command: $e');
      _showError('Failed to go to previous track');
    }
  }

  void _nextTrack() async {
    _setUserInteracting(); // 设置用户交互标志

    // 根据输入源选择不同的控制方式
    if (selectedInputSource == 'BT') {
      // BT模式：使用蓝牙指令控制
      _nextTrackWithBluetooth();
    } else {
      // 其他模式：使用原来的蓝牙指令控制
      _nextTrackWithBluetooth();
    }
  }

  void _nextTrackWithAudioService() {
    try {
      widget.audioHandler.skipToNext();
      print('AudioService: Skipping to next track');
      _showSuccess('Next track');
    } catch (e) {
      print('Failed to skip to next track with AudioService: $e');
      _showError('Failed to go to next track');
    }
  }

  void _nextTrackWithBluetooth() async {
    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      print('Sending next track command via Bluetooth');
      await _bluetoothService.nextTrack();
      // BT和USB/SD模式下不显示弹窗提示
      if (selectedInputSource != 'BT' && selectedInputSource != 'USB/SD') {
        _showSuccess('Next track');
      }
    } catch (e) {
      print('Failed to send next track command: $e');
      _showError('Failed to go to next track');
    }
  }

  // 新增：X.BASS选择方法
  void _selectXBass(String xbass) async {
    _setUserInteracting(); // 设置用户交互标志

    setState(() {
      selectedXBass = xbass;
    });

    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      print('Selecting X.BASS: $xbass');

      // 将字符串'OFF', '1', '2', '3'转换为整数值0, 1, 2, 3
      int xBassValue = xbass == 'OFF' ? 0 : int.parse(xbass);
      print('X.BASS value: $xBassValue');

      // 发送X.BASS指令
      await _bluetoothService.sendXBassCommand(xBassValue);
      _showSuccess('X.BASS set to $xbass');
    } catch (e) {
      print('Failed to send X.BASS command: $e');
      _showError('Failed to set X.BASS');
    }
  }

  // 新增：效果模式选择方法
  void _selectEffectMode(String mode) async {
    _setUserInteracting(); // 设置用户交互标志

    setState(() {
      selectedEffectMode = mode;
    });

    if (!await _bluetoothService.isReallyConnected) {
      _showError('Device not connected');
      return;
    }

    try {
      print('Selecting Mic mode: $mode');
      // 将字符串模式转换为数值
      int modeValue = effectModes.indexOf(mode);
      if (modeValue != -1) {
        await _bluetoothService.sendMicModeCommand(modeValue);
        _showSuccess('Mic mode set to $mode');
      } else {
        print('❌ 无效的Mic mode值: $mode');
        _showError('Invalid Mic mode');
      }
    } catch (e) {
      print('Failed to send Mic mode command: $e');
      _showError('Failed to set Mic mode');
    }
  }

  // 新增：音量旋转按钮回调
  void _onVolumeChanged(double value) {
    _setUserInteracting(); // 设置用户交互标志

    // 如果当前是静音状态，调整音量时取消静音
    if (_isMuted && value > 0) {
      setState(() {
        _isMuted = false;
      });
    }

    setState(() {
      volumeValue = value;
    });
    _updateVolume(value);
  }

  // 新增：效果强度旋转按钮回调
  void _onEffectChanged(double value) {
    _setUserInteracting(); // 设置用户交互标志

    setState(() {
      effectValue = value;
    });
    _updateEffect(value);
  }

  void _decreaseVolume() {
    double newVolume = (volumeValue - 1).clamp(0.0, 32.0);
    print('减少音量: $newVolume');

    // 如果当前是静音状态，调整音量时取消静音
    if (_isMuted && newVolume > 0) {
      setState(() {
        _isMuted = false;
      });
    }

    setState(() {
      volumeValue = newVolume;
    });

    _updateVolume(newVolume);
  }

  void _increaseVolume() {
    double newVolume = (volumeValue + 1).clamp(0.0, 32.0);
    print('增加音量: $newVolume');

    // 如果当前是静音状态，调整音量时取消静音
    if (_isMuted && newVolume > 0) {
      setState(() {
        _isMuted = false;
      });
    }

    setState(() {
      volumeValue = newVolume;
    });

    _updateVolume(newVolume);
  }

  void _decreaseEffect() {
    double newEffect = (effectValue - 1).clamp(0.0, 32.0);
    print('减少效果强度: $newEffect');

    setState(() {
      effectValue = newEffect;
    });

    _updateEffect(newEffect);
  }

  void _increaseEffect() {
    double newEffect = (effectValue + 1).clamp(0.0, 32.0);
    print('增加效果强度: $newEffect');

    setState(() {
      effectValue = newEffect;
    });

    _updateEffect(newEffect);
  }

  void _updateVolume(double newVolume) async {
    print('User requests to update volume to: $newVolume');

    setState(() {
      volumeValue = newVolume;
    });

    bool reallyConnected = await _bluetoothService.isReallyConnected;

    if (!reallyConnected) {
      print('❌ The device is not connected, unable to send volume commands');
      if (!_hasShownConnectionError) {
        _showError(
            'The device is not connected, unable to send volume commands');
        _hasShownConnectionError = true;
      }
      return;
    }

    _hasShownConnectionError = false;

    if (_bluetoothService.writeCharacteristic == null) {
      print('❌ 写入特征不可用');
      _showError('写入特征不可用，请重新连接设备');
      return;
    }

    print('准备发送音量指令: ${newVolume.toInt()}');
    try {
      await _bluetoothService.sendVolumeCommand(newVolume.toInt());
      print('✅ 音量指令发送成功: ${newVolume.toInt()}');

      if (newVolume > 0) {
        setSharedVolumeValue(newVolume);
      }
    } catch (e) {
      print('❌ 发送失败: $e');
      _showError('发送音量指令失败: $e');
    }
  }

  void _updateEffect(double newEffect) async {
    print('User requested effect strength update to: $newEffect');

    bool reallyConnected = await _bluetoothService.isReallyConnected;

    if (!reallyConnected) {
      print('❌ Device not connected, cannot send effect command');
      if (!_hasShownConnectionError) {
        _showError('设备未连接，无法发送效果强度指令');
        _hasShownConnectionError = true;
      }
      return;
    }

    _hasShownConnectionError = false;

    if (_bluetoothService.writeCharacteristic == null) {
      print('❌ Write characteristic not available');
      _showError('写入特征不可用，请重新连接设备');
      return;
    }

    print('准备发送KARAOKE指令: ${newEffect.toInt()}');
    try {
      await _bluetoothService.sendKaraokeCommand(newEffect.toInt());
      print('✅ KARAOKE指令发送成功: ${newEffect.toInt()}');
    } catch (e) {
      print('❌ 发送失败: $e');
      _showError('发送效果强度指令失败: $e');
    }
  }

  void _onEffectSelected(String effect) async {
    _setUserInteracting(); // 设置用户交互标志

    int effectIndex = soundEffects.indexOf(effect);
    if (effectIndex == -1) {
      print('❌ 无效的音效模式: $effect');
      return;
    }

    if (effect == 'Normal') {
      setState(() {
        effectValue = 0.0;
        selectedEffect = effect;
      });
      print('🎛️ 选择 Normal 模式，效果强度已重置为 0');
    } else {
      setState(() {
        selectedEffect = effect;
      });
    }

    try {
      _updateEffectMode(effectIndex);

      await Future.delayed(Duration(milliseconds: 100));

      // 效果强度指令已移除

      print('✅ 音效设置完成: 模式=$effect, 强度=$effectValue');
    } catch (e) {
      print('❌ 发送音效设置失败: $e');
      _showError('发送音效设置失败: $e');
    }
  }

  void _updateEffectMode(int effectMode) async {
    print(
        'User requested effect mode update to: $effectMode (${soundEffects[effectMode]})');

    bool reallyConnected = await _bluetoothService.isReallyConnected;

    if (!reallyConnected) {
      print('❌ Device not connected, cannot send effect mode command');
      if (!_hasShownConnectionError) {
        _showError('设备未连接，无法发送音效模式指令');
        _hasShownConnectionError = true;
      }
      return;
    }

    _hasShownConnectionError = false;

    if (_bluetoothService.writeCharacteristic == null) {
      print('❌ Write characteristic not available');
      _showError('写入特征不可用，请重新连接设备');
      return;
    }

    print('准备发送音效模式指令: $effectMode');
    try {
      await _bluetoothService.sendEffectModeCommand(effectMode);
      print('✅ 音效模式指令发送成功: $effectMode');
    } catch (e) {
      print('❌ 发送失败: $e');
      _showError('发送音效模式指令失败: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      // 清除当前正在显示的SnackBar
      // ScaffoldMessenger.of(context).clearSnackBars();
      // 立即显示新的SnackBar
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(message),
      //     backgroundColor: const Color(0xFFFF0000), // 红色
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      // 清除当前正在显示的SnackBar
      // ScaffoldMessenger.of(context).clearSnackBars();
      // 立即显示新的SnackBar
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(message),
      //     backgroundColor: const Color(0xFFFF0000), // 红色
      //     duration: Duration(seconds: 1),
      //   ),
      // );
    }
  }

  void _toggleMute() {
    print('静音按钮被点击，当前音量: $volumeValue, 静音状态: $_isMuted');

    if (_muteAnimationController.isCompleted) {
      _muteAnimationController.reverse();
    } else {
      _muteAnimationController.forward();
    }

    if (_isMuted) {
      // 取消静音
      double restoreVolume = sharedVolumeValue > 0 ? sharedVolumeValue : 16.0;
      print('取消静音，恢复音量到: $restoreVolume');

      setState(() {
        _isMuted = false;
        volumeValue = restoreVolume;
      });

      _updateVolume(restoreVolume);
    } else {
      // 静音
      print('静音，保存当前音量: $volumeValue');
      setSharedVolumeValue(volumeValue);

      setState(() {
        _isMuted = true;
        volumeValue = 0.0;
      });

      _updateVolume(0.0);
    }
  }

  void _togglePriority() async {
    setState(() {
      _isPriorityEnabled = !_isPriorityEnabled;
    });
    print('PRIORITY开关状态: $_isPriorityEnabled');

    // 发送Priority指令到蓝牙设备
    if (await _bluetoothService.isReallyConnected) {
      try {
        await _bluetoothService.sendPriorityCommand(_isPriorityEnabled ? 1 : 0);
      } catch (e) {
        print('Failed to send Priority command: $e');
      }
    }
  }

  void _toggleFbx() async {
    setState(() {
      _isFbxEnabled = !_isFbxEnabled;
    });
    print('FBX开关状态: $_isFbxEnabled');

    // 发送FBX指令到蓝牙设备
    if (await _bluetoothService.isReallyConnected) {
      try {
        await _bluetoothService.sendFbxCommand(_isFbxEnabled ? 1 : 0);
      } catch (e) {
        print('Failed to send FBX command: $e');
      }
    }
  }

  void _navigateToBluetoothPage() async {
    print('导航到蓝牙页面...');

    _isPageActive = false;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BluetoothConnectionScreen(),
      ),
    );

    _isPageActive = true;
    print('从蓝牙页面返回，立即刷新状态...');

    _focusNode.requestFocus();

    _refreshBluetoothStateImmediately();

    Future.delayed(Duration(milliseconds: 1000), () async {
      if (mounted && _isPageActive) {
        bool connected = await _bluetoothService.isReallyConnected;
        if (connected) {
          print('返回后检测到设备已连接，开始同步状态...');
          _syncStateToDevice();
        }
      }
    });

    Future.delayed(Duration(milliseconds: 2000), () {
      if (mounted && _isPageActive) {
        _refreshBluetoothStateImmediately();
        _checkAndSyncState();
      }
    });
  }

  void _checkAndSyncState() async {
    if (mounted && _isPageActive) {
      bool connected = await _bluetoothService.isReallyConnected;
      if (connected) {
        print('二次检查：设备已连接，同步状态...');
        _syncStateToDevice();
      }
    }
  }

  bool _isAutoConnecting = false;

  void _tryAutoConnect() async {
    print('🔍 Attempting auto-connect to last device...');

    if (_isAutoConnecting) {
      print('⚠️ Auto-connect already in progress, skipping');
      return;
    }

    _isAutoConnecting = true;

    try {
      await Future.delayed(Duration(seconds: 2));

      while (!(await FlutterBluePlus.isOn)) {
        print('⏳ Waiting for Bluetooth to turn on...');
        await Future.delayed(Duration(milliseconds: 500));
      }

      print('✅ Bluetooth adapter is on');

      Map<String, String>? lastDevice =
          await _bluetoothService.getLastConnectedDevice();

      if (lastDevice == null) {
        print('📱 No previous device found for auto-connect');
        _isAutoConnecting = false;
        return;
      }

      String deviceId = lastDevice['id']!;
      String deviceName = lastDevice['name']!;

      print('🔍 Found last device: $deviceName ($deviceId)');

      List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;
      BluetoothDevice? targetDevice;

      for (var device in connectedDevices) {
        if (device.id.id == deviceId) {
          targetDevice = device;
          print('✅ Device already connected: ${device.name}');
          break;
        }
      }

      if (targetDevice != null) {
        print('✅ Device already connected, initializing service...');
        bool initialized = await _initializeBluetoothService(targetDevice);
        if (initialized && mounted) {
          setState(() {
            isConnected = true;
          });
          _showSuccess('Automatically connected to $deviceName');
        }
        _isAutoConnecting = false;
        return;
      }

      print('🔌 Device not connected, starting scan...');

      const scanTimeout = Duration(seconds: 10);
      Timer? scanTimeoutTimer;

      await FlutterBluePlus.startScan(timeout: scanTimeout);

      scanTimeoutTimer = Timer(scanTimeout, () {
        FlutterBluePlus.stopScan();
        print('⏰ Auto-connect scan timeout');
        _isAutoConnecting = false;
      });

      StreamSubscription? scanSubscription;
      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (var result in results) {
          if (result.device.id.id == deviceId) {
            print('🎯 Found target device in scan: ${result.device.name}');

            scanSubscription?.cancel();
            scanTimeoutTimer?.cancel();
            await FlutterBluePlus.stopScan();

            await _connectToDevice(result.device);
            _isAutoConnecting = false;
            break;
          }
        }
      });

      Future.delayed(scanTimeout, () {
        scanSubscription?.cancel();
        scanTimeoutTimer?.cancel();
        _isAutoConnecting = false;
      });
    } catch (e) {
      print('❌ Auto-connect failed: $e');
      _isAutoConnecting = false;
    }
  }

  void _refreshBluetoothStateImmediately() async {
    print('=== 立即刷新蓝牙状态 ===');
    try {
      bool reallyConnected = await _bluetoothService.isReallyConnected;
      print('立即检查结果: $reallyConnected');

      if (mounted) {
        setState(() {
          isConnected = reallyConnected;
        });
      }

      if (reallyConnected && _bluetoothService.writeCharacteristic == null) {
        print('连接但特征缺失，立即修复...');
        await _autoFixCharacteristicsImmediately();
      }
    } catch (e) {
      print('立即刷新失败: $e');
      if (mounted) {
        setState(() {
          isConnected = false;
        });
      }
    }
  }

  // 修复方法：立即自动修复特征
  Future<void> _autoFixCharacteristicsImmediately() async {
    print('🚨 尝试立即修复蓝牙特征...');

    if (_bluetoothService.connectedDevice == null) {
      print('❌ 没有已连接的设备，无法修复特征');
      return;
    }

    try {
      setState(() {
        _isReconnecting = true;
      });

      print('正在重新发现蓝牙服务...');

      // 先断开连接
      await _bluetoothService.connectedDevice!.disconnect();
      await Future.delayed(Duration(milliseconds: 500));

      // 重新连接
      await _bluetoothService.connectedDevice!.connect();
      await Future.delayed(Duration(milliseconds: 1000));

      // 重新初始化服务
      bool initialized =
          await _initializeBluetoothService(_bluetoothService.connectedDevice!);

      if (initialized) {
        print('✅ 蓝牙特征修复成功');
        _showSuccess('蓝牙特征已修复');

        // 修复后立即刷新状态
        _refreshBluetoothStateImmediately();

        // 读取设备当前状态
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && isConnected) {
            _readDeviceCurrentState();
          }
        });
      } else {
        print('❌ 蓝牙特征修复失败');
        _showError('蓝牙特征修复失败');
      }
    } catch (e) {
      print('❌ 修复蓝牙特征时出错: $e');
      _showError('修复蓝牙特征时出错: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReconnecting = false;
        });
      }
    }
  }

  Future<void> _ensureGlobalStateUpdated() async {
    print('确保全局状态已更新...');

    for (int i = 0; i < 3; i++) {
      await _bluetoothService.refreshConnectionStatus();
      await Future.delayed(Duration(milliseconds: 300));
    }

    print('全局状态更新完成');
  }

  Future<void> _connectToDevice(BluetoothDevice device,
      {bool isAutoConnect = false}) async {
    try {
      if (!isAutoConnect) {
        setState(() {
          isConnecting = true;
          _hasRequestedInitialState = false; // 重置状态请求标志
          deviceConnectionStates[device.id.id] =
              BluetoothConnectionState.connecting;
        });
      }

      print('Connecting to device: ${device.name} (${device.id})');

      await _bluetoothService.connectToDevice(device);

      print('✅ Connected to device: ${device.name}');

      if (!isAutoConnect) {
        setState(() {
          deviceConnectionStates[device.id.id] =
              BluetoothConnectionState.connected;
        });
      }

      bool serviceInitialized = await _initializeBluetoothService(device);

      if (serviceInitialized) {
        print('✅ Bluetooth service initialized, device ready');

        await _ensureGlobalStateUpdated();

        if (!isAutoConnect && mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('Successfully connected to ${device.name}'),
          //     backgroundColor: const Color(0xFF011C85),
          //     duration: const Duration(seconds: 2),
          //   ),
          // );

          // 手动连接成功后读取设备状态
          Future.delayed(Duration(milliseconds: 1500), () {
            if (mounted && isConnected) {
              print('手动连接成功，读取设备状态...');
              _readDeviceCurrentState();
            }
          });

          Future.delayed(Duration(milliseconds: 1000), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        } else if (isAutoConnect) {
          _showSuccess('Automatically connected to ${device.name}');
        }
      } else {
        print('❌ Bluetooth service initialization failed');
        if (!isAutoConnect) {
          _showError('Connected but service initialization failed');
        }
      }
    } catch (e) {
      print('❌ Connection failed: $e');

      if (!isAutoConnect) {
        setState(() {
          deviceConnectionStates[device.id.id] =
              BluetoothConnectionState.disconnected;
          isConnecting = false;
        });

        String errorMessage = 'Failed to connect to ${device.name}';
        if (e.toString().contains('timeout')) {
          errorMessage =
              'Connection timed out. Please make sure the device is nearby and in pairing mode.';
        }

        if (mounted) {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(errorMessage),
          //     backgroundColor: const Color(0xFFFF0000),
          //     duration: const Duration(seconds: 3),
          //   ),
          // );
        }
      }
    } finally {
      if (!isAutoConnect) {
        setState(() {
          isConnecting = false;
        });
      }
    }
  }

  void _triggerStateSync() {
    print('触发状态同步到设备...');

    Future.delayed(Duration(milliseconds: 500), () {
      print('状态同步已触发');
    });
  }

  Future<bool> _initializeBluetoothService(BluetoothDevice device) async {
    try {
      print('开始初始化蓝牙服务...');

      // 连接到新设备
      await device.connect();

      // 连接后等待短暂时间，确保通信链路稳定
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取服务
      List<BluetoothService> services = await device.discoverServices();
      bool foundService = false;
      bool foundWriteChar = false;
      bool foundReadChar = false;

      for (BluetoothService service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        print('检查服务: $serviceUuid');

        if (serviceUuid == '0000ab00-0000-1000-8000-00805f9b34fb' ||
            serviceUuid.contains('ab00')) {
          foundService = true;
          print('✅ 找到目标服务: $serviceUuid');

          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            print('检查特征: $charUuid, 属性: ${characteristic.properties}');

            if ((charUuid == '0000ab01-0000-1000-8000-00805f9b34fb' ||
                    charUuid.contains('ab01')) &&
                characteristic.properties.write) {
              _bluetoothService.writeCharacteristic = characteristic;
              foundWriteChar = true;
              print('✅ 找到并设置写入特征: $charUuid');
            }

            if ((charUuid == '0000ab02-0000-1000-8000-00805f9b34fb' ||
                    charUuid.contains('ab02')) &&
                characteristic.properties.notify) {
              _bluetoothService.readCharacteristic = characteristic;
              foundReadChar = true;
              print('✅ 找到读取特征: $charUuid');

              try {
                await characteristic.setNotifyValue(true);
                print('✅ 通知已启用');

                characteristic.value.listen((value) {
                  print('收到设备通知: $value');
                }, onError: (error) {
                  print('通知监听错误: $error');
                });
              } catch (e) {
                print('⚠️ 启用通知失败: $e');
              }
            }
          }
        }
      }

      _bluetoothService.connectedDevice = device;

      await _bluetoothService.refreshConnectionStatus();

      bool success = foundService && foundWriteChar;
      print('蓝牙服务初始化结果: $success (服务: $foundService, 写入特征: $foundWriteChar)');

      return success;
    } catch (e) {
      print('❌ 蓝牙服务初始化失败: $e');
      return false;
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      if (mounted) {
        setState(() {
          deviceConnectionStates[device.id.id] =
              BluetoothConnectionState.disconnected;
        });

        if (_bluetoothService.connectedDevice?.id.id == device.id.id) {
          _bluetoothService.connectedDevice = null;
          _bluetoothService.writeCharacteristic = null;
          _bluetoothService.readCharacteristic = null;

          _bluetoothService.clearSavedDevice();
        }

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Disconnected from ${device.name}'),
        //     backgroundColor: const Color(0xFF011C85),
        //   ),
        // );
        print('Successfully disconnected from device: ${device.name}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Failed to disconnect from ${device.name}: $e'),
        //     backgroundColor: const Color(0xFFF44336),
        //   ),
        // );
      }
    }
  }

  void _syncStateToDevice({bool forceShowSuccess = false}) async {
    if (!await _bluetoothService.isReallyConnected) {
      print('The device is not connected, unable to sync status');
      return;
    }

    // 如果正在接收设备状态，避免重复发送
    if (_isReceivingDeviceState) {
      print('⏸️ 正在接收设备状态，暂停同步到设备');
      return;
    }

    print('=== Start synchronizing status to device ===');
    print(
        'Current status - 音量: $volumeValue, 效果: $effectValue, 模式: $selectedEffect');

    try {
      print('Sync volume: $volumeValue');
      await _bluetoothService.sendVolumeCommand(volumeValue.toInt());
      await Future.delayed(Duration(milliseconds: 200));

      print('Synchronization KARAOKE intensity: $effectValue');
      await _bluetoothService.sendKaraokeCommand(effectValue.toInt());
      await Future.delayed(Duration(milliseconds: 200));

      int effectIndex = soundEffects.indexOf(selectedEffect);
      if (effectIndex != -1) {
        print('Sync Sound Mode: $selectedEffect (Index: $effectIndex)');
        await _bluetoothService.sendEffectModeCommand(effectIndex);
      }

      print('✅ Status synchronization completed');

      if (forceShowSuccess || !_hasShownSyncSuccess) {
        _showSuccess('Device status has been synchronized');
        _hasShownSyncSuccess = true;
      }
    } catch (e) {
      print('❌ Failed to synchronize state: $e');

      if (!_hasShownSyncError) {
        _showError('Failed to synchronize state: $e');
        _hasShownSyncError = true;
      }

      print('Retry synchronization in 5 seconds...');
      Future.delayed(Duration(seconds: 5), () async {
        if (mounted && await _bluetoothService.isReallyConnected) {
          print('Start retrying sync status...');
          _syncStateToDevice(forceShowSuccess: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 425; // 平板或大屏手机
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isLargeFont = textScaleFactor > 1.2; // 超过1.2认为是大字体

    return Scaffold(
      backgroundColor: const Color(0xFF011C85), // 极深背景色
      body: Stack(
        children: [
          // 科技感背景层
          _buildTechBackground(screenWidth, screenHeight),
          SafeArea(
            child: Column(
              children: [
                // 顶部标题区域 - 现代化设计
                GestureDetector(
                  onTap: _navigateToBluetoothPage,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 24 : 16,
                      vertical: isLargeFont ? 2 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF011C85)
                          .withOpacity(0.3), // 深蓝色背景，30%透明度
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFFF0000).withOpacity(0.3), // 红色光斑
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Logo图标
                        Container(
                          width: isLargeFont ? 60 : 80,
                          height: isLargeFont ? 36 : 48,
                          decoration: BoxDecoration(
                            color: Colors.white, // 白色背景
                            borderRadius: BorderRadius.circular(6),
                            border: Border(
                              right: BorderSide(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/dat.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 标题和连接状态
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Digital Signal Processor',
                                  style: TextStyle(
                                    color: const Color(0xFFF7F7F7), // 主要标题文字
                                    fontSize: isLargeFont ? 14 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isConnected
                                          ? const Color(0xFFF7F7F7) // 状态文字色
                                          : (_isReconnecting
                                              ? const Color(0xFFFF0000)
                                              : const Color(0xFF8A4822)),
                                    ),
                                  ),
                                  SizedBox(width: isLargeFont ? 2 : 8),
                                  Text(
                                    isConnected
                                        ? 'Connected'
                                        : (_isReconnecting
                                            ? 'Connecting...'
                                            : 'Not Connected'),
                                    style: TextStyle(
                                      color: isConnected
                                          ? const Color(0xFFF7F7F7) // 状态文字色
                                          : (_isReconnecting
                                              ? const Color(0xFFFF0000)
                                              : const Color(0xFF8A4822)),
                                      fontSize: isLargeFont ? 10 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 蓝牙图标
                        Container(
                          width: isLargeFont ? 32 : 40,
                          height: isLargeFont ? 32 : 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF011C85), // 深巧克力色
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFF7F7F7), // 金属高光边缘
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.bluetooth,
                            color: Color(0xFFFF0000), // 旋钮指示灯色
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 主要内容区域 - 自适应布局
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 12 : 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. 输入源控制卡片（根据输入源显示不同内容）
                        // _buildInputSourceControlCard(), // 已移动到音量控制卡片中

                        SizedBox(height: isLargeScreen ? 8 : 4),

                        // 2. 音量控制卡片（现在包含所有控制选项）
                        Expanded(
                          child: _buildVolumeControlCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 科技感背景组件
  Widget _buildTechBackground(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // 背景渐变
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFF7F7F7),
                const Color(0xFFF7F7F7),
                const Color(0xFFF7F7F7),
              ],
            ),
          ),
        ),

        // 网格线效果
        CustomPaint(
          size: Size(screenWidth, screenHeight),
          painter: GridLinePainter(),
        ),

        // 流星效果
        Positioned.fill(
          child: MeteorShower(
            count: 12,
            duration: const Duration(seconds: 6),
          ),
        ),

        // 科技感光点
        Positioned.fill(
          child: TechParticles(
            count: 300,
          ),
        ),
      ],
    );
  }

  // 输入源控制卡片（根据输入源显示不同内容）
  Widget _buildInputSourceControlCard() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isLargeFont = textScaleFactor > 1.2; // 超过1.2认为是大字体

    return Card(
      elevation: 2,
      color: const Color(0xFF011C85).withOpacity(0.5), // 深蓝色，50%透明度
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 12 : (isLargeFont ? 4 : 6)),
        child: Column(
          children: [
            // 输入源选择按钮 - 水平居中
            Center(
              child: Wrap(
                spacing: isLargeScreen ? 12 : 10,
                runSpacing: isLargeScreen ? 12 : 10,
                children: inputSources.map((source) {
                  final isSelected = selectedInputSource == source;

                  return GestureDetector(
                    onTap: () => _selectInputSource(source),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeFont
                            ? (isLargeScreen ? 8 : 6)
                            : (isLargeScreen ? 12 : 10),
                        vertical: isLargeFont
                            ? (isLargeScreen ? 2 : 2)
                            : (isLargeScreen ? 8 : 6),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : const Color(0xFF011C85), // 选中/高亮面板色 : 深巧克力色
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFFF7F7F7), // 选中时白色描边 : 金属高光边缘
                          width: 2,
                        ),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: isLargeFont
                              ? (isLargeScreen ? 10 : 8)
                              : (isLargeScreen ? 14 : 12),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFF7F7F7)
                              : const Color(0xFFF7F7F7), // 主要标题文字 : 金属高光边缘
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: isLargeScreen ? 16 : 8),

            // 根据输入源显示不同的控制模块
            if (selectedInputSource == 'FM')
              _buildFMFrequencyModule() // FM模式：显示频率选择模块
            else if (selectedInputSource == 'AUX')
              _buildAUXMessageModule() // AUX模式：显示提示信息
            else
              _buildPlaybackControlModule() // 其他模式：显示播放控制模块
          ],
        ),
      ),
    );
  }

  // FM频率选择模块
  Widget _buildFMFrequencyModule() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;

    return Column(
      children: [
        // 频率显示和按钮
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 减少频率按钮已移除

              // 频率显示已移除

              // 增加频率按钮已移除

              // 刷新按钮（已移到滑动条中间位置）
            ],
          ),
        ),

        SizedBox(height: isLargeScreen ? 2 : 1),

        // 频率滑动条和按钮
        Row(
          children: [
            // 上一首按钮
            GestureDetector(
              onTap: _previousTrack,
              child: Container(
                width: isLargeScreen ? 40 : 32,
                height: isLargeScreen ? 40 : 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF011C85), // 深巧克力色
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7F7F7), // 金属高光边缘
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A4822).withOpacity(0.3), // 琥珀色光斑
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.skip_previous,
                  color: const Color(0xFFFF0000), // 旋钮指示灯色
                  size: isLargeScreen ? 20 : 16,
                ),
              ),
            ),

            // 频率滑动条
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_minFMFrequency.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF7F7F7),
                          ),
                        ),
                        /* Text(
                  //   'Frequency',
                  //   style: const TextStyle(
                  //     fontSize: 14,
                  //     fontWeight: FontWeight.w600,
                  //     color: Color(0xFF1A1A1A),
                  //   ),
                  // ),*/
                        Text(
                          '${_maxFMFrequency.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFF7F7F7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4),

                  // 自定义滑动条
                  _buildFMFrequencySlider(),
                ],
              ),
            ),

            // 下一首按钮
            GestureDetector(
              onTap: _nextTrack,
              child: Container(
                width: isLargeScreen ? 40 : 32,
                height: isLargeScreen ? 40 : 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF011C85), // 深巧克力色
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7F7F7), // 金属高光边缘
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A4822).withOpacity(0.3), // 琥珀色光斑
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.skip_next,
                  color: const Color(0xFFFF0000), // 旋钮指示灯色
                  size: isLargeScreen ? 20 : 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 自定义FM频率滑动条
  Widget _buildFMFrequencySlider() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;
    return Container(
      height: isLargeScreen ? 60 : 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sliderWidth = constraints.maxWidth;
          final position = ((_fmFrequency - _minFMFrequency) /
                  (_maxFMFrequency - _minFMFrequency)) *
              sliderWidth;

          return Stack(
            children: [
              // 背景轨道
              Container(
                height: 6,
                margin: const EdgeInsets.only(top: 26),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // 已选择轨道
              Container(
                height: 6,
                margin: const EdgeInsets.only(top: 26),
                width: position,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000), // 旋钮指示灯色
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // 刻度标记
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(11, (index) {
                    // 在中间位置（第5个刻度）添加刷新按钮
                    if (index == 5) {
                      return GestureDetector(
                        onTap: _sendPlayPauseCommand,
                        child: Container(
                          width: isLargeScreen ? 60 : 50,
                          height: isLargeScreen ? 32 : 28,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              'SCAN',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 16 : 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF7F7F7), // 金属高光边缘
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    double frequency = _minFMFrequency +
                        (index * (_maxFMFrequency - _minFMFrequency) / 10);
                    bool isMajor = index % 5 == 0; // 每5个刻度一个主要刻度

                    return Column(
                      children: [
                        Container(
                          width: isMajor ? 2 : 1,
                          height: isMajor ? 12 : 8,
                          color: const Color(0xFF9E9E9E),
                        ),
                      ],
                    );
                  }),
                ),
              ),

              // 滑块
              Positioned(
                left: position.clamp(25.0, sliderWidth - 25.0) -
                    25, // 确保滑块不会超出边界，减去滑块宽度的一半
                top: 16, // 调整垂直位置使其居中 (26 - 30/2 = 11，其中26是轨道的top值，30是滑块高度)
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final renderBox = context.findRenderObject() as RenderBox;
                    final localPosition =
                        renderBox.globalToLocal(details.globalPosition);

                    double newPosition =
                        localPosition.dx.clamp(0.0, sliderWidth);
                    double newFrequency = _minFMFrequency +
                        (newPosition / sliderWidth) *
                            (_maxFMFrequency - _minFMFrequency);
                    newFrequency = (newFrequency * 10).round() / 10.0; // 保留一位小数

                    _onFMFrequencyChanged(newFrequency);
                  },
                  child: Container(
                    width: 50,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000), // 旋钮指示灯色
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF8A4822).withOpacity(0.3), // 琥珀色光斑
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${_fmFrequency.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF7F7F7), // 主要标题文字
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // AUX模式下的提示信息模块
  Widget _buildAUXMessageModule() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF0000).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AUX Mode Ready',
            style: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF7F7F7),
            ),
          ),
          SizedBox(height: isLargeScreen ? 8 : 6),
          Text(
            'Please control music playback through your device',
            style: TextStyle(
              fontSize: isLargeScreen ? 14 : 12,
              color: const Color(0xFFF7F7F7),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 播放控制模块（用于AUX, USB/SD, BT）
  Widget _buildPlaybackControlModule() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;

    return Column(
      children: [
        // 播放控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 上一首
            _buildPlaybackButton(
              icon: Icons.skip_previous,
              onPressed: _previousTrack,
              isLarge: isLargeScreen,
            ),

            // 播放/暂停
            _buildPlaybackButton(
              icon: isPlaying ? Icons.pause : Icons.play_arrow,
              onPressed: _playPause,
              isLarge: isLargeScreen,
              isPrimary: true,
            ),

            // 下一首
            _buildPlaybackButton(
              icon: Icons.skip_next,
              onPressed: _nextTrack,
              isLarge: isLargeScreen,
            ),
          ],
        ),

        SizedBox(height: isLargeScreen ? 12 : 8),

        // 播放状态显示（仅在FM模式显示）
        if (selectedInputSource == 'FM')
          Text(
            isPlaying ? 'Paused' : 'Playing',
            style: TextStyle(
              fontSize: isLargeScreen ? 14 : 12,
              color: const Color(0xFF6B6B6B),
              fontWeight: FontWeight.w500,
            ),
          ),

        // // 显示当前输入源
        // Text(
        //   'Mode: $selectedInputSource',
        //   style: TextStyle(
        //     fontSize: isLargeScreen ? 12 : 10,
        //     color: const Color(0xFF2E7D32),
        //     fontWeight: FontWeight.w500,
        //   ),
        // ),
      ],
    );
  }

  // 播放控制按钮
  Widget _buildPlaybackButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isLarge,
    bool isPrimary = false,
  }) {
    return _PressedButton(
      icon: icon,
      onPressed: onPressed,
      isLarge: isLarge,
      isPrimary: isPrimary,
    );
  }

  // 音量控制卡片（现在包含所有控制选项）
  Widget _buildVolumeControlCard() {
    final isLargeScreen = MediaQuery.of(context).size.width > 425;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final isLargeFont = textScaleFactor > 1.2; // 超过1.2认为是大字体

    // 计算旋转按钮大小
    final double knobSize = isLargeScreen
        ? math.min(140.0, (screenWidth - 80) / 2)
        : isLargeFont
            ? math.min(50.0, (screenWidth - 60) / 2)
            : math.min(130.0, (screenWidth - 60) / 2);

    return Card(
      elevation: 2,
      color: const Color(0xFF011C85).withOpacity(0.5), // 深蓝色，50%透明度
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(const Radius.circular(16)),
      ),
      child: Container(
        padding: EdgeInsets.all(isLargeScreen ? 12 : (isLargeFont ? 4 : 6)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行 - 只有音量标题和静音按钮 - 已移动到MUSIC旋转按钮上方
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            // const Text(
            //   'Volume Control',
            // style: TextStyle(
            //   fontSize: 16,
            //   fontWeight: FontWeight.w600,
            //   color: Color(0xFFF7F7F7), // 主要标题文字
            // ),
            // ),
            // GestureDetector(
            //   onTap: _toggleMute,
            //   child: Container(
            //     width: 40,
            //     height: 40,
            // decoration: BoxDecoration(
            //   color: _isMuted
            //     ? const Color(0xFF9E9E9E).withOpacity(0.1)
            //     : const Color(0xFFFF0000).withOpacity(0.1), // 旋钮指示灯色
            //   shape: BoxShape.circle,
            //   border: Border.all(
            //     color: const Color(0xFFFFFFFF), // 白色描边
            //     width: 2,
            //   ),
            // ),
            // child: Icon(
            //   _isMuted ? Icons.volume_off : Icons.volume_up,
            //   color: _isMuted ? const Color(0xFFFF0000) : const Color(0xFF9E9E9E), // 旋钮指示灯色
            //   size: 20,
            // ),
            // ),
            // ),

            // ],
            // ),
            // SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // 输入源选择按钮 - 水平居中
            Center(
              child: Wrap(
                spacing: isLargeScreen ? 12 : 10,
                runSpacing: isLargeScreen ? 12 : 10,
                children: inputSources.map((source) {
                  final isSelected = selectedInputSource == source;

                  return GestureDetector(
                    onTap: () => _selectInputSource(source),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isLargeFont
                            ? (isLargeScreen ? 8 : 6)
                            : (isLargeScreen ? 12 : 10),
                        vertical: isLargeFont
                            ? (isLargeScreen ? 2 : 2)
                            : (isLargeScreen ? 8 : 6),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF0000)
                            : const Color(0xFF011C85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFFF7F7F7),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        source,
                        style: TextStyle(
                          fontSize: isLargeFont
                              ? (isLargeScreen ? 10 : 8)
                              : (isLargeScreen ? 14 : 12),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFFF7F7F7)
                              : const Color(0xFFF7F7F7),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: isLargeScreen ? 16 : 8),

            // 根据输入源显示不同的控制模块
            if (selectedInputSource == 'FM') _buildFMFrequencyModule(),
            if (selectedInputSource == 'AUX') _buildAUXMessageModule(),
            if (selectedInputSource != 'FM' && selectedInputSource != 'AUX')
              _buildPlaybackControlModule(),

            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // Volume Control标题和静音按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Volume Control',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF7F7F7), // 主要标题文字
                  ),
                ),
                GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isMuted
                          ? const Color(0xFF9E9E9E).withOpacity(0.1)
                          : const Color(0xFFFF0000).withOpacity(0.1), // 旋钮指示灯色
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFFFFF), // 白色描边
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: _isMuted
                          ? const Color(0xFFFF0000)
                          : const Color(0xFF9E9E9E), // 旋钮指示灯色
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // 旋转按钮行 - 并排显示
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 音量旋转按钮
                RotaryKnob(
                  initialValue: volumeValue,
                  label: 'MUSIC',
                  minValue: 0.0,
                  maxValue: 32.0,
                  onValueChanged: _onVolumeChanged,
                  activeColor: const Color(0xFF2E7D32),
                  size: knobSize,
                ),

                // 效果强度旋转按钮
                RotaryKnob(
                  initialValue: effectValue,
                  label: 'KARAOKE',
                  minValue: 0.0,
                  maxValue: 32.0,
                  onValueChanged: _onEffectChanged,
                  activeColor: const Color(0xFF2E7D32),
                  size: knobSize,
                ),
              ],
            ),

            SizedBox(height: isLargeScreen ? 8 : 6),

            // X.BASS 选择（独立一行）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                // 将主轴对齐方式改为起始对齐，使X.BASS标签和选项都靠近左侧
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'X.BASS',
                    style: TextStyle(
                      fontSize: isLargeFont ? 12 : 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF7F7F7), // 主要标题文字
                    ),
                  ),

                  // 添加一些间距
                  SizedBox(width: 16),

                  // X.BASS 选项 - 左对齐
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: xbassOptions.map((option) {
                      final isSelected = selectedXBass == option;

                      return GestureDetector(
                        onTap: () => _selectXBass(option),
                        child: Container(
                          margin: EdgeInsets.symmetric(
                              horizontal: isLargeFont ? 3 : 4),
                          width: isLargeFont
                              ? (isLargeScreen ? 32 : 30)
                              : (isLargeScreen ? 40 : 40),
                          height: isLargeFont
                              ? (isLargeScreen ? 32 : 30)
                              : (isLargeScreen ? 40 : 40),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF0000)
                                : const Color(0xFF011C85), // 选中/高亮面板色 : 深巧克力色
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFFF7F7F7), // 选中时白色描边 : 金属高光边缘
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: isLargeFont
                                    ? (isLargeScreen ? 12 : 10)
                                    : (isLargeScreen ? 14 : 14),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFFF7F7F7)
                                    : const Color(
                                        0xFFF7F7F7), // 主要标题文字 : 金属高光边缘
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // // Mode 选择（独立一行）
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       // const Text(
            //       //   'Mic mode',
            //       //   style: TextStyle(
            //       //     fontSize: 16,
            //       //     fontWeight: FontWeight.w600,
            //       //     color: Color(0xFFF7F7F7), // 主要标题文字
            //       //   ),
            //       // ),

            //       // // 效果模式选项
            //       // Row(
            //       //   children: effectModes.map((mode) {
            //       //     final isSelected = selectedEffectMode == mode;

            //       //     return GestureDetector(
            //       //       onTap: () => _selectEffectMode(mode),
            //       //       child: Container(
            //       //         margin: const EdgeInsets.symmetric(horizontal: 4),
            //       //         padding: EdgeInsets.symmetric(
            //       //           horizontal: isLargeScreen ? 16 : 12,
            //       //           vertical: isLargeScreen ? 10 : 8,
            //       //         ),
            //       //         decoration: BoxDecoration(
            //       //           color: isSelected ? const Color(0xFFFF0000) : const Color(0xFF011C85), // 选中/高亮面板色 : 深巧克力色
            //       //           borderRadius: BorderRadius.circular(12),
            //       //           border: Border.all(
            //       //             color: isSelected ? const Color(0xFFFF0000) : const Color(0xFFF7F7F7), // 选中/高亮面板色 : 金属高光边缘
            //       //             width: 2,
            //       //           ),
            //       //         ),
            //       //         child: Text(
            //       //           mode,
            //       //           style: TextStyle(
            //       //             fontSize: isLargeScreen ? 14 : 12,
            //       //             fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            //       //             color: isSelected ? const Color(0xFFF7F7F7) : const Color(0xFFF7F7F7), // 主要标题文字 : 金属高光边缘
            //       //           ),
            //       //         ),
            //       //       ),
            //       //     );
            //       //   }).toList(),
            //       // ),
            //     ],
            //   ),
            // ),

            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // Reverb 控制
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isLargeFont
                      ? (isLargeScreen ? 12 : 10)
                      : (isLargeScreen ? 16 : 12),
                  vertical: isLargeFont
                      ? (isLargeScreen ? 1 : 1)
                      : (isLargeScreen ? 12 : 8)),
              child: Row(
                children: [
                  SizedBox(
                    width: isLargeFont ? 55 : 65,
                    child: Text(
                      'reverb',
                      style: TextStyle(
                        fontSize: isLargeFont ? 12 : 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 1 : 4),
                  // 减号按钮
                  _LongPressButton(
                    onLongPressStart: () async {
                      if (reverbValue > 0) {
                        setState(() {
                          reverbValue--;
                        });

                        // 发送Reverb指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService
                                .sendReverbCommand(reverbValue);
                          } catch (e) {
                            print('Failed to send Reverb command: $e');
                          }
                        }
                      }
                    },
                    onLongPressRepeat: () async {
                      if (reverbValue > 0) {
                        setState(() {
                          reverbValue--;
                        });

                        // 发送Reverb指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService
                                .sendReverbCommand(reverbValue);
                          } catch (e) {
                            print('Failed to send Reverb command: $e');
                          }
                        }
                      }
                    },
                    child: Container(
                      width: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      height: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000), // 选中/高亮面板色
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF7F7F7), // 金属高光边缘
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                        size: isLargeFont ? 14 : 18,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : 8),
                  // 数字显示框
                  Container(
                    width: isLargeFont
                        ? (isLargeScreen ? 30 : 30)
                        : (isLargeScreen ? 44 : 44),
                    height: isLargeFont
                        ? (isLargeScreen ? 18 : 20)
                        : (isLargeScreen ? 30 : 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF140D09), // 极深背景色
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF7F7F7), // 金属高光边缘
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$reverbValue',
                      style: TextStyle(
                        fontSize: isLargeFont
                            ? (isLargeScreen ? 12 : 10)
                            : (isLargeScreen ? 14 : 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF7F7F7), // 主要标题文字
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : 8),
                  // 加号按钮
                  _LongPressButton(
                    onLongPressStart: () async {
                      if (reverbValue < 16) {
                        setState(() {
                          reverbValue++;
                        });

                        // 发送Reverb指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService
                                .sendReverbCommand(reverbValue);
                          } catch (e) {
                            print('Failed to send Reverb command: $e');
                          }
                        }
                      }
                    },
                    onLongPressRepeat: () async {
                      if (reverbValue < 16) {
                        setState(() {
                          reverbValue++;
                        });

                        // 发送Reverb指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService
                                .sendReverbCommand(reverbValue);
                          } catch (e) {
                            print('Failed to send Reverb command: $e');
                          }
                        }
                      }
                    },
                    child: Container(
                      width: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      height: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000), // 选中/高亮面板色
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF7F7F7), // 金属高光边缘
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                        size: isLargeFont ? 14 : 18,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : (isLargeScreen ? 12 : 16)),
                  // FBX开关
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleFbx,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeFont
                              ? (isLargeScreen ? 8 : 6)
                              : (isLargeScreen ? 16 : 12),
                          vertical: isLargeFont
                              ? (isLargeScreen ? 2 : 2)
                              : (isLargeScreen ? 8 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: _isFbxEnabled
                              ? const Color(0xFFFF0000)
                              : const Color(0xFF011C85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFbxEnabled
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFFF7F7F7),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'FBX',
                              style: TextStyle(
                                fontSize: isLargeFont
                                    ? (isLargeScreen ? 8 : 7)
                                    : (isLargeScreen ? 14 : 14),
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFFF7F7F7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLargeScreen ? 8 : (isLargeFont ? 0 : 4)),

            // Echo控制和PRIORITY开关
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isLargeFont
                      ? (isLargeScreen ? 12 : 10)
                      : (isLargeScreen ? 16 : 12),
                  vertical: isLargeFont
                      ? (isLargeScreen ? 1 : 1)
                      : (isLargeScreen ? 12 : 8)),
              child: Row(
                children: [
                  // Echo 控制
                  SizedBox(
                    width: isLargeFont ? 55 : 65,
                    child: Text(
                      'echo',
                      style: TextStyle(
                        fontSize: isLargeFont ? 12 : 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : 4),
                  // 减号按钮
                  _LongPressButton(
                    onLongPressStart: () async {
                      if (echoValue > 0) {
                        setState(() {
                          echoValue--;
                        });

                        // 发送Echo指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService.sendEchoCommand(echoValue);
                          } catch (e) {
                            print('Failed to send Echo command: $e');
                          }
                        }
                      }
                    },
                    onLongPressRepeat: () async {
                      if (echoValue > 0) {
                        setState(() {
                          echoValue--;
                        });

                        // 发送Echo指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService.sendEchoCommand(echoValue);
                          } catch (e) {
                            print('Failed to send Echo command: $e');
                          }
                        }
                      }
                    },
                    child: Container(
                      width: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      height: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000), // 选中/高亮面板色
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF7F7F7), // 金属高光边缘
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                        size: isLargeFont ? 18 : 22,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : 8),
                  // 数字显示框
                  Container(
                    width: isLargeFont
                        ? (isLargeScreen ? 30 : 30)
                        : (isLargeScreen ? 44 : 44),
                    height: isLargeFont
                        ? (isLargeScreen ? 18 : 20)
                        : (isLargeScreen ? 30 : 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF140D09), // 极深背景色
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF7F7F7), // 金属高光边缘
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$echoValue',
                      style: TextStyle(
                        fontSize: isLargeFont
                            ? (isLargeScreen ? 12 : 10)
                            : (isLargeScreen ? 14 : 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFF7F7F7), // 主要标题文字
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : 8),
                  // 加号按钮
                  _LongPressButton(
                    onLongPressStart: () async {
                      if (echoValue < 16) {
                        setState(() {
                          echoValue++;
                        });

                        // 发送Echo指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService.sendEchoCommand(echoValue);
                          } catch (e) {
                            print('Failed to send Echo command: $e');
                          }
                        }
                      }
                    },
                    onLongPressRepeat: () async {
                      if (echoValue < 16) {
                        setState(() {
                          echoValue++;
                        });

                        // 发送Echo指令到蓝牙设备
                        if (await _bluetoothService.isReallyConnected) {
                          try {
                            await _bluetoothService.sendEchoCommand(echoValue);
                          } catch (e) {
                            print('Failed to send Echo command: $e');
                          }
                        }
                      }
                    },
                    child: Container(
                      width: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      height: isLargeFont
                          ? (isLargeScreen ? 18 : 20)
                          : (isLargeScreen ? 30 : 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000), // 选中/高亮面板色
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF7F7F7), // 金属高光边缘
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Color(0xFFF7F7F7), // 主要标题文字
                        size: isLargeFont ? 14 : 18,
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeFont ? 2 : (isLargeScreen ? 12 : 16)),
                  // PRIORITY开关
                  Expanded(
                    child: GestureDetector(
                      onTap: _togglePriority,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeFont
                              ? (isLargeScreen ? 8 : 6)
                              : (isLargeScreen ? 16 : 12),
                          vertical: isLargeFont
                              ? (isLargeScreen ? 2 : 2)
                              : (isLargeScreen ? 8 : 6),
                        ),
                        decoration: BoxDecoration(
                          color: _isPriorityEnabled
                              ? const Color(0xFFFF0000)
                              : const Color(0xFF011C85),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isPriorityEnabled
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFFF7F7F7),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PRI',
                              style: TextStyle(
                                fontSize: isLargeFont
                                    ? (isLargeScreen ? 9 : 7)
                                    : (isLargeScreen ? 14 : 14),
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFFF7F7F7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),

            // Sound Effects 选择 - 直接显示选项，每行3个
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sound Effects标题已注释，不显示
                if (MediaQuery.of(context).textScaleFactor <= 1.1)
                  const Text(
                    'Sound Effects',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF7F7F7), // 主要标题文字
                    ),
                  ),
                SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 4 : 8)),

                // 使用GridView实现每行3个按钮，确保对齐
                Container(
                  width: double.infinity,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // 每行3个
                      crossAxisSpacing: isLargeScreen ? 12 : 8,
                      mainAxisSpacing: isLargeScreen ? 12 : 8,
                      childAspectRatio:
                          isLargeScreen ? 2.8 : 2.5, // 调整宽高比，使按钮高度与mic mode一致
                    ),
                    itemCount: soundEffects.length,
                    itemBuilder: (context, index) {
                      final effect = soundEffects[index];
                      final isSelected = selectedEffect == effect;

                      return GestureDetector(
                        onTap: () => _onEffectSelected(effect),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFFF0000)
                                : const Color(0xFF011C85), // 选中/高亮面板色 : 深巧克力色
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFFF7F7F7), // 选中时白色描边 : 金属高光边缘
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF8A4822)
                                          .withOpacity(0.3), // 琥珀色光斑
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              effect,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 12 : 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFFF7F7F7)
                                    : const Color(
                                        0xFFF7F7F7), // 主要标题文字 : 金属高光边缘
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // 添加一个Spacer或者SizedBox来推到底部
            SizedBox(height: isLargeScreen ? 12 : (isLargeFont ? 0 : 6)),
          ],
        ),
      ),
    );
  }
}

// ==============================================
// 旋转按钮组件
// ==============================================

// 旋转按钮常量
const double kRotaryMin = 0.0;
const double kRotaryMax = 32.0;
const double kRotaryRange = kRotaryMax - kRotaryMin; // 32.0

class RotaryKnob extends StatefulWidget {
  final double initialValue;
  final String label;
  final double minValue;
  final double maxValue;
  final ValueChanged<double>? onValueChanged;
  final ValueChanged<bool>? onDraggingChanged;
  final Color activeColor;
  final double size;

  const RotaryKnob({
    Key? key,
    this.initialValue = 0.0,
    required this.label,
    this.minValue = 0.0,
    this.maxValue = 32.0,
    this.onValueChanged,
    this.onDraggingChanged,
    this.activeColor = const Color(0xFF2E7D32),
    this.size = 160.0,
  }) : super(key: key);

  @override
  _RotaryKnobState createState() => _RotaryKnobState();
}

class _RotaryKnobState extends State<RotaryKnob> {
  late double _currentValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue.clamp(widget.minValue, widget.maxValue);
  }

  @override
  void didUpdateWidget(RotaryKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部值变化且不在拖动时，更新内部值
    if (!_isDragging && widget.initialValue != oldWidget.initialValue) {
      setState(() {
        _currentValue =
            widget.initialValue.clamp(widget.minValue, widget.maxValue);
      });
    }
  }

  // 处理拖动手势开始
  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
    widget.onDraggingChanged?.call(true);
  }

  // 处理拖动手势结束
  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    widget.onDraggingChanged?.call(false);
  }

  // 处理拖动手势更新
  void _handlePanUpdate(DragUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset center = renderBox.size.center(Offset.zero);

    final Offset vector = details.localPosition - center;

    // 计算当前触摸点相对于中心点和水平向右方向的角度（-pi到pi）
    double touchAngle = math.atan2(vector.dy, vector.dx);

    // 旋转范围：从左下方到右下方的3/4圆弧旋转
    // 起始角度：-1.25 * math.pi (315度/-45度)
    // 结束角度： 0.25 * math.pi (45度)
    // 总旋转弧度：1.5 * math.pi (270度)

    final double startAngleRad = -math.pi * 1.25; // -225度
    final double endAngleRad = math.pi * 0.25; // 45度

    // 确保touchAngle在有效的2*pi范围内，方便处理
    if (touchAngle < 0) touchAngle += 2 * math.pi;

    // 将startAngleRad和endAngleRad也转换为0-2*pi范围，方便比较
    double normalizedStartAngle = startAngleRad;
    if (normalizedStartAngle < 0) normalizedStartAngle += 2 * math.pi;

    double normalizedEndAngle = endAngleRad;
    if (normalizedEndAngle < 0) normalizedEndAngle += 2 * math.pi;

    // 计算触摸点相对于旋钮起始角度的偏移量
    double angleOffset;
    if (normalizedEndAngle > normalizedStartAngle) {
      // 正常顺时针弧度
      if (touchAngle >= normalizedStartAngle &&
          touchAngle <= normalizedEndAngle) {
        angleOffset = touchAngle - normalizedStartAngle;
      } else if (touchAngle < normalizedStartAngle) {
        // 触摸点在起始点之前
        angleOffset = 0.0;
      } else {
        // 触摸点在结束点之后
        angleOffset = math.pi * 1.5; // 最大弧度
      }
    } else {
      // 跨越0/2*pi边界 (例如从315度到45度)
      if (touchAngle >= normalizedStartAngle ||
          touchAngle <= normalizedEndAngle) {
        if (touchAngle >= normalizedStartAngle) {
          angleOffset = touchAngle - normalizedStartAngle;
        } else {
          // 例如 touchAngle = 30度, normalizedStartAngle = 315度
          angleOffset = (2 * math.pi - normalizedStartAngle) + touchAngle;
        }
      } else {
        // 触摸点在非有效区域
        // 靠近哪个边界就取哪个边界
        if ((touchAngle - normalizedEndAngle).abs() <
            (touchAngle - normalizedStartAngle).abs()) {
          angleOffset = math.pi * 1.5;
        } else {
          angleOffset = 0.0;
        }
      }
    }

    // 限制偏移量在0到总旋转弧度之间
    angleOffset = angleOffset.clamp(0.0, math.pi * 1.5);

    // 将角度偏移量映射到值
    double newValue =
        (angleOffset / (math.pi * 1.5)) * (widget.maxValue - widget.minValue) +
            widget.minValue;

    // 确保值在范围内
    newValue = newValue.clamp(widget.minValue, widget.maxValue);

    // 检查值是否发生了显著变化（至少变化0.1）
    if ((newValue - _currentValue).abs() >= 0.1) {
      setState(() {
        _currentValue = newValue;
      });
      widget.onValueChanged?.call(_currentValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _RotaryKnobPainter(_currentValue, widget.label,
            widget.activeColor, widget.minValue, widget.maxValue),
      ),
    );
  }
}

class _RotaryKnobPainter extends CustomPainter {
  final double currentValue;
  final String label;
  final Color activeColor;
  final double minValue;
  final double maxValue;

  _RotaryKnobPainter(this.currentValue, this.label, this.activeColor,
      this.minValue, this.maxValue);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 绘制科技感背景渐变
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xFF011C85),
        const Color(0xFF011C85),
        const Color(0xFF011C85),
      ],
      stops: const [0.0, 0.7, 1.0],
    );
    final Paint backgroundPaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);

    // 绘制科技感网格纹理
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFFF0000).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final gridRadius = radius - 15;
    final gridLines = 8;
    for (int i = 0; i < gridLines; i++) {
      final angle = (i * 2 * math.pi) / gridLines;
      canvas.drawLine(
        center,
        Offset(
          center.dx + gridRadius * math.cos(angle),
          center.dy + gridRadius * math.sin(angle),
        ),
        gridPaint,
      );
    }

    // 绘制同心圆环
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        gridRadius * i / 3,
        gridPaint,
      );
    }

    // 绘制外层发光效果
    final Paint outerGlowPaint = Paint()
      ..color = activeColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, 8.0);
    canvas.drawCircle(center, radius - 2, outerGlowPaint);

    // 绘制内层发光效果
    final Paint innerGlowPaint = Paint()
      ..color = activeColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = MaskFilter.blur(BlurStyle.inner, 6.0);
    canvas.drawCircle(center, radius - 8, innerGlowPaint);

    // 绘制主圆环
    final Paint ringPaint = Paint()
      ..color = const Color(0xFF011C85).withOpacity(0.8) // 深巧克力色
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0;
    canvas.drawCircle(center, radius - 12, ringPaint);

    // 绘制刻度线
    final Paint tickPaint = Paint()
      ..color = const Color(0xFFF7F7F7) // 金属高光边缘
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final Paint activeTickPaint = Paint()
      ..color = const Color(0xFFFF0000) // 旋钮指示灯色
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // 刻度线的起始和结束角度
    final double startAngleRad = -math.pi * 1.25; // -225度
    final double sweepAngleRad = math.pi * 1.5; // 270度

    // 计算当前值对应的弧度
    final double valueRange = maxValue - minValue;
    final double valueAngleRad =
        ((currentValue - minValue) / valueRange) * sweepAngleRad;

    final int numberOfTicks = (valueRange).toInt() + 1; // 刻度数量，33个刻度(0-32)
    final double angleIncrement = sweepAngleRad / (numberOfTicks - 1);

    for (int i = 0; i < numberOfTicks; i++) {
      final double angle = startAngleRad + i * angleIncrement;
      // 判断是否激活
      final bool isActive = (i * angleIncrement) <= valueAngleRad ||
          (currentValue == maxValue && i == numberOfTicks - 1);

      // 刻度线的内外半径
      final double innerTickRadius = radius - 20;
      final double outerTickRadius = radius - 10;

      // 计算刻度线的起点和终点
      final Offset p1 = Offset(
        center.dx + innerTickRadius * math.cos(angle),
        center.dy + innerTickRadius * math.sin(angle),
      );
      final Offset p2 = Offset(
        center.dx + outerTickRadius * math.cos(angle),
        center.dy + outerTickRadius * math.sin(angle),
      );

      canvas.drawLine(p1, p2, isActive ? activeTickPaint : tickPaint);
    }

    // 绘制中心数值（使用toInt()确保与发送的指令一致）
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: currentValue.toInt().toString(),
        style: TextStyle(
          color: const Color(0xFFF7F7F7), // 主要标题文字
          fontSize: radius / 2,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: const Color(0xFFFF0000).withOpacity(0.8), // 旋钮指示灯色
              blurRadius: 8.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2 - 3),
    );

    // 绘制底部的标签
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFF7F7F7), // 金属高光边缘
          fontSize: 14.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(center.dx - labelPainter.width / 2, center.dy + radius - 40),
    );
  }

  @override
  bool shouldRepaint(covariant _RotaryKnobPainter oldDelegate) {
    return oldDelegate.currentValue != currentValue ||
        oldDelegate.label != label ||
        oldDelegate.activeColor != activeColor;
  }
}

// BluetoothConnectionScreen 类
class BluetoothConnectionScreen extends StatefulWidget {
  const BluetoothConnectionScreen({super.key});

  @override
  State<BluetoothConnectionScreen> createState() =>
      _BluetoothConnectionScreenState();
}

class _BluetoothConnectionScreenState extends State<BluetoothConnectionScreen> {
  final AmpBluetoothService _bluetoothService = AmpBluetoothService();
  bool isScanning = false;
  bool isConnecting = false;
  List<BluetoothDevice> devices = [];
  Map<String, BluetoothConnectionState> deviceConnectionStates = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSubscription;
  bool _isPageActive = true;

  @override
  void initState() {
    super.initState();
    print('🔄 初始化蓝牙连接屏幕');
    _initializeBluetoothListeners();
    // 移除自动扫描逻辑，只有当用户主动点击扫描按钮时才请求权限
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void _initializeBluetoothListeners() {
    _connectionStatusSubscription =
        _bluetoothService.connectionStatusStream.listen((connected) {
      if (mounted) {
        setState(() {});
      }
    }, onError: (error) {
      print('Connection state listening error: $error');
    });

    _deviceConnectionSubscription =
        _bluetoothService.getConnectionState().listen((state) {
      if (mounted) {
        setState(() {});
      }
    }, onError: (error) {
      print('Device status listening error: $error');
    });
  }

  void _startBluetoothScan() async {
    try {
      print('🔄 开始蓝牙扫描流程');
      // 取消之前的订阅（修复多次扫描导致的流冲突）
      _scanSubscription?.cancel();
      print('✅ 已取消之前的扫描订阅');

      if (Platform.isIOS) {
        // 直接扫描，不走 permission_handler
        print('📱 iOS 平台，直接开始扫描');
      }

      // 检查蓝牙是否开启
      print('🔧 Checking Bluetooth adapter status');
      bool isBluetoothOn = await FlutterBluePlus.isOn;
      print('🔧 Bluetooth status: $isBluetoothOn');
      if (!isBluetoothOn) {
        if (mounted) {
          print('❌ Bluetooth is off');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please turn on Bluetooth'),
              backgroundColor: const Color(0xFFFF0000),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      print('✅ Bluetooth is on');

      setState(() {
        isScanning = true;
        devices.clear();
      });

      // 获取已连接的设备
      List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        // 移除设备名称过滤，显示所有已连接设备
        bool isAllowedDevice = true;

        // 如果设备名称为空，也允许显示（某些设备可能没有名称）
        if (device.localName.isEmpty) {
          isAllowedDevice = true;
        }

        if (!devices.any((d) => d.id.id == device.id.id) && isAllowedDevice) {
          devices.add(device);
          deviceConnectionStates[device.id.id] =
              BluetoothConnectionState.connected;
        }
      }

      print('📡 开始蓝牙扫描，持续20秒...');
      print('📱 平台: ${Platform.operatingSystem}');

      // 检查蓝牙适配器状态
      var adapterState = await FlutterBluePlus.adapterState.first;
      print('🔧 蓝牙适配器状态: $adapterState');

      if (!isBluetoothOn) {
        if (mounted) {
          print('❌ 蓝牙未开启');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please turn on Bluetooth'),
              backgroundColor: const Color(0xFFFF0000),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      try {
        // 启动扫描
        await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: 20),
            androidUsesFineLocation: true);
        print('✅ 扫描已启动');
      } catch (e) {
        print('❌ 启动扫描失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('启动扫描失败: $e'),
              backgroundColor: const Color(0xFFFF0000),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 开始扫描新设备
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (mounted) {
          print('🔍 扫描到 ${results.length} 个设备');
          for (var result in results) {
            print(
                '📱 设备名称: "${result.device.localName}", ID: ${result.device.id.id}, RSSI: ${result.rssi}');
          }

          // 添加蓝牙搜索过滤：只显示包含指定关键词的设备
          List<String> allowedKeywords = ['dat', 'bl', 'ble', 'sofei', 'dsp'];

          setState(() {
            // 创建新列表，只包含唯一设备
            Set<String> deviceIds = {};
            List<BluetoothDevice> newDevices = [];
            Map<String, BluetoothConnectionState> newDeviceConnectionStates =
                {};

            // 先添加已连接的设备（保持原有逻辑）
            for (var device in connectedDevices) {
              deviceIds.add(device.id.id);
              newDevices.add(device);
              newDeviceConnectionStates[device.id.id] =
                  BluetoothConnectionState.connected;
            }

            // 再添加扫描到的新设备（应用过滤）
            for (var result in results) {
              if (!deviceIds.contains(result.device.id.id)) {
                // 检查设备名称是否包含允许的关键词
                String deviceName = result.device.localName.toLowerCase();
                bool isAllowedDevice = allowedKeywords
                    .any((keyword) => deviceName.contains(keyword));

                // 如果设备名称为空，直接过滤掉不显示
                if (result.device.localName.isEmpty) {
                  isAllowedDevice = false;
                }

                if (isAllowedDevice) {
                  deviceIds.add(result.device.id.id);
                  newDevices.add(result.device);
                  newDeviceConnectionStates[result.device.id.id] =
                      BluetoothConnectionState.disconnected;
                }
              }
            }

            // 更新状态
            devices = newDevices;
            deviceConnectionStates = newDeviceConnectionStates;
            print('📊 设备列表更新：共 ${devices.length} 个设备（已应用关键词过滤）');
          });
        }
      }, onError: (error) {
        print('扫描结果监听错误: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描错误: $error'),
              backgroundColor: const Color(0xFFFF0000),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      });

      // 等待扫描完成
      await Future.delayed(const Duration(seconds: 20));
      await FlutterBluePlus.stopScan();
      print('⏹️ 蓝牙扫描结束');

      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    } catch (e) {
      print('扫描失败: $e');
      if (mounted) {
        setState(() {
          isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: const Color(0xFFFF0000),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      setState(() {
        isConnecting = true;
        deviceConnectionStates[device.id.id] =
            BluetoothConnectionState.connecting;
      });

      await _bluetoothService.connectToDevice(device);

      setState(() {
        deviceConnectionStates[device.id.id] =
            BluetoothConnectionState.connected;
      });

      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('已连接到 ${device.name}'),
        //     backgroundColor: const Color(0xFF8A4822), // 琥珀色光斑
        //   ),
        // );
        // 返回上一页
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('连接失败: $e');
      setState(() {
        deviceConnectionStates[device.id.id] =
            BluetoothConnectionState.disconnected;
      });
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('连接失败: $e'),
        //     backgroundColor: const Color(0xFF8A4822), // 琥珀色光斑
        //   ),
        // );
      }
    } finally {
      setState(() {
        isConnecting = false;
      });
    }
  }

  void _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      setState(() {
        deviceConnectionStates[device.id.id] =
            BluetoothConnectionState.disconnected;
      });

      if (_bluetoothService.connectedDevice?.id.id == device.id.id) {
        _bluetoothService.connectedDevice = null;
        _bluetoothService.writeCharacteristic = null;
        _bluetoothService.readCharacteristic = null;
        _bluetoothService.clearSavedDevice();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${device.name}'),
            backgroundColor: const Color(0xFFFF0000), // 旋钮指示灯色
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: const Color(0xFF8A4822), // 琥珀色光斑
          ),
        );
      }
    }
  }

  Widget _buildDeviceItem(BluetoothDevice device) {
    final connectionState = deviceConnectionStates[device.id.id] ??
        BluetoothConnectionState.disconnected;
    final isConnected = connectionState == BluetoothConnectionState.connected;
    final isConnectingThisDevice =
        connectionState == BluetoothConnectionState.connecting;
    final isLargeFont =
        MediaQuery.of(context).textScaleFactor > 1.2; // 超过1.2认为是大字体

    return Card(
      margin:
          EdgeInsets.symmetric(horizontal: 16, vertical: isLargeFont ? 4 : 8),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: isLargeFont ? 8 : 16, vertical: isLargeFont ? 4 : 8),
        leading: Container(
          width: isLargeFont ? 24 : 32,
          height: isLargeFont ? 24 : 32,
          decoration: BoxDecoration(
            color: isConnected ? const Color(0xFF011C85) : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.bluetooth,
            color: Colors.white,
            size: isLargeFont ? 16 : 20,
          ),
        ),
        title: Text(
          device.name.isNotEmpty ? device.name : 'Unknown Device',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF011C85), // 深蓝色标题
            fontSize: isLargeFont ? 14 : 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.id.id,
              style: TextStyle(
                  fontSize: isLargeFont ? 10 : 12, color: Colors.grey[600]),
            ),
            Text(
              _getConnectionStateText(connectionState),
              style: TextStyle(
                color: _getConnectionStateColor(connectionState),
                fontSize: isLargeFont ? 11 : 13,
              ),
            ),
          ],
        ),
        trailing: isConnected || isConnectingThisDevice
            ? IconButton(
                icon: isConnectingThisDevice
                    ? SizedBox(
                        width: isLargeFont ? 16 : 20,
                        height: isLargeFont ? 16 : 20,
                        child: CircularProgressIndicator(
                            strokeWidth: isLargeFont ? 1.5 : 2),
                      )
                    : Icon(Icons.link_off,
                        color: const Color(0xFF8A4822),
                        size: isLargeFont ? 20 : 24), // 琥珀色光斑
                onPressed: isConnectingThisDevice
                    ? null
                    : () => _disconnectDevice(device),
                iconSize: isLargeFont ? 20 : 24,
              )
            : ElevatedButton(
                onPressed: () => _connectToDevice(device),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                      horizontal: isLargeFont ? 8 : 12,
                      vertical: isLargeFont ? 4 : 8),
                  minimumSize:
                      Size(isLargeFont ? 60 : 80, isLargeFont ? 30 : 36),
                ),
                child: Text(
                  'connect',
                  style: TextStyle(
                    fontSize: isLargeFont ? 12 : 14,
                  ),
                ),
              ),
        onTap: () {
          if (!isConnected && !isConnectingThisDevice) {
            _connectToDevice(device);
          }
        },
      ),
    );
  }

  String _getConnectionStateText(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return 'Connected';
      case BluetoothConnectionState.connecting:
        return 'Connecting...';
      case BluetoothConnectionState.disconnected:
        return 'Not connected';
      case BluetoothConnectionState.disconnecting:
        return 'Disconnected...';
      default:
        return 'Unknown state';
    }
  }

  Color _getConnectionStateColor(BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        return const Color(0xFF011C85); // 深蓝色
      case BluetoothConnectionState.connecting:
        return const Color(0xFFFF0000); // 旋钮指示灯色
      case BluetoothConnectionState.disconnected:
        return Colors.grey[600]!;
      case BluetoothConnectionState.disconnecting:
        return const Color(0xFF8A4822); // 琥珀色光斑
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // 白色背景
      appBar: AppBar(
        title: const Text('Bluetooth devices'),
        backgroundColor:
            const Color(0xFF011C85).withOpacity(0.3), // 深蓝色背景，30%透明度
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: () {
              if (isScanning) {
                FlutterBluePlus.stopScan();
                setState(() {
                  isScanning = false;
                });
              } else {
                _startBluetoothScan();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态栏
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF011C85).withOpacity(0.3), // 深蓝色背景，30%透明度
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: const Color(0xFFFF0000), // 旋钮指示灯色
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isScanning
                        ? 'Scanning Bluetooth devices...'
                        : 'Find ${devices.length} device',
                    style: TextStyle(
                      color: const Color(0xFFF7F7F7), // 主要标题文字
                    ),
                  ),
                ),
                if (isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // 设备列表
          Expanded(
            child: devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isScanning
                              ? 'Searching for devices...'
                              : 'Bluetooth device not found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                          ),
                        ),
                        if (!isScanning)
                          TextButton(
                            onPressed: _startBluetoothScan,
                            child: const Text('Rescan'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return _buildDeviceItem(devices[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PressedButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLarge;
  final bool isPrimary;

  const _PressedButton({
    required this.icon,
    required this.onPressed,
    required this.isLarge,
    required this.isPrimary,
  });

  @override
  State<_PressedButton> createState() => _PressedButtonState();
}

class _PressedButtonState extends State<_PressedButton> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) {
        setState(() => isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => isPressed = false),
      child: Container(
        width: widget.isLarge ? 60 : 50,
        height: widget.isLarge ? 60 : 50,
        decoration: BoxDecoration(
          color: isPressed
              ? (widget.isPrimary
                  ? const Color(0xFF0A1F95)
                  : const Color(0xFFFF0000))
              : (widget.isPrimary
                  ? const Color(0xFFFF0000)
                  : const Color(0xFF011C85)),
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isPrimary
                ? const Color(0xFFFFFFFF)
                : const Color(0xFFF7F7F7),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8A4822).withOpacity(isPressed ? 0.5 : 0.3),
              blurRadius: isPressed ? 12 : 8,
              offset: Offset(0, isPressed ? 6 : 4),
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: widget.isPrimary
              ? const Color(0xFFF7F7F7)
              : const Color(0xFFFF0000),
          size: widget.isLarge ? 28 : 24,
        ),
      ),
    );
  }
}

class _LongPressButton extends StatefulWidget {
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressRepeat;
  final Widget child;

  const _LongPressButton({
    required this.onLongPressStart,
    required this.onLongPressRepeat,
    required this.child,
  });

  @override
  State<_LongPressButton> createState() => _LongPressButtonState();
}

class _LongPressButtonState extends State<_LongPressButton> {
  Timer? _timer;
  static const _repeatInterval = Duration(milliseconds: 100);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRepeat() {
    widget.onLongPressStart();
    _timer = Timer.periodic(_repeatInterval, (timer) {
      widget.onLongPressRepeat();
    });
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startRepeat(),
      onTapUp: (_) => _stopRepeat(),
      onTapCancel: () => _stopRepeat(),
      child: widget.child,
    );
  }
}
