
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 平台工具类，用于处理不同Android版本和厂商的兼容性问题
class PlatformUtils {
  static PlatformUtils? _instance;
  factory PlatformUtils() => _instance ??= PlatformUtils._internal();
  PlatformUtils._internal();

  // 获取Android版本号
  int get androidVersion {
    if (Platform.isAndroid) {
      try {
        // 在实际运行时获取Android版本
        return int.parse(Platform.version.split(' ')[0]);
      } catch (e) {
        debugPrint('获取Android版本失败: $e');
        return 10; // 默认返回Android 10
      }
    }
    return 0; // 非Android系统
  }

  // 检查是否是特定厂商
  bool isManufacturer(String manufacturer) {
    if (!Platform.isAndroid) return false;
    try {
      // 这里需要使用device_info_plus包来获取厂商信息
      // 暂时返回false，实际使用时需要替换为真实的检测逻辑
      return false;
    } catch (e) {
      debugPrint('检测厂商失败: $e');
      return false;
    }
  }

  // 检查是否是小米设备
  bool get isXiaomi => isManufacturer('Xiaomi');

  // 检查是否是华为设备
  bool get isHuawei => isManufacturer('Huawei');

  // 检查是否是三星设备
  bool get isSamsung => isManufacturer('Samsung');

  // 检查是否是OPPO设备
  bool get isOppo => isManufacturer('OPPO');

  // 检查是否是Vivo设备
  bool get isVivo => isManufacturer('vivo');

  // 检查是否需要特殊处理
  bool get needsSpecialHandling {
    return isXiaomi || isHuawei || isSamsung || isOppo || isVivo;
  }

  // 获取推荐的MTU大小
  int getRecommendedMtu() {
    // 根据Android版本和厂商返回不同的MTU大小
    if (androidVersion >= 12) {
      // Android 12及以上支持更大的MTU
      return needsSpecialHandling ? 512 : 517;
    } else if (androidVersion >= 10) {
      // Android 10-11
      return needsSpecialHandling ? 512 : 517;
    } else if (androidVersion >= 8) {
      // Android 8-9
      return needsSpecialHandling ? 512 : 517;
    } else {
      // Android 7及以下
      return needsSpecialHandling ? 23 : 512;
    }
  }

  // 获取推荐的连接超时时间
  Duration getRecommendedConnectionTimeout() {
    if (needsSpecialHandling) {
      // 某些厂商设备需要更长的连接超时时间
      return Duration(seconds: 35);
    }
    return Duration(seconds: 30);
  }

  // 获取推荐的写入超时时间
  Duration getRecommendedWriteTimeout() {
    if (needsSpecialHandling) {
      return Duration(seconds: 5);
    }
    return Duration(seconds: 3);
  }

  // 获取推荐的扫描超时时间
  Duration getRecommendedScanTimeout() {
    if (needsSpecialHandling) {
      return Duration(seconds: 20);
    }
    return Duration(seconds: 15);
  }

  // 获取推荐的重试次数
  int getRecommendedRetryCount() {
    if (needsSpecialHandling) {
      return 5; // 某些厂商设备需要更多重试次数
    }
    return 3;
  }

  // 获取推荐的重试间隔
  int getRecommendedRetryDelay(int attemptNumber) {
    if (needsSpecialHandling) {
      // 某些厂商设备需要更长的重试间隔
      return 300 * attemptNumber;
    }
    return 200 * attemptNumber;
  }

  // 获取推荐的延迟时间
  int getRecommendedDelay(String operation) {
    if (needsSpecialHandling) {
      switch (operation) {
        case 'connect':
          return 1000;
        case 'discover':
          return 1500;
        case 'write':
          return 100;
        case 'notify':
          return 500;
        default:
          return 300;
      }
    }
    switch (operation) {
      case 'connect':
        return 500;
      case 'discover':
        return 1000;
      case 'write':
        return 50;
      case 'notify':
        return 300;
      default:
        return 200;
    }
  }

  // 检查是否需要使用备用连接方式
  bool get needsAlternativeConnectionMethod {
    // 某些厂商设备在特定Android版本上需要使用备用连接方式
    if (isXiaomi && androidVersion >= 10 && androidVersion <= 11) {
      return true;
    }
    if (isHuawei && androidVersion >= 9 && androidVersion <= 10) {
      return true;
    }
    return false;
  }

  // 检查是否需要禁用某些特性
  bool get needsDisableSpecificFeatures {
    // 某些厂商设备需要禁用某些特性
    if (isXiaomi && androidVersion <= 8) {
      return true;
    }
    if (isOppo && androidVersion <= 9) {
      return true;
    }
    return false;
  }

  // 检查是否需要使用备用写入方式
  bool get needsAlternativeWriteMethod {
    // 某些厂商设备需要使用备用写入方式
    if (isSamsung && androidVersion >= 10) {
      return true;
    }
    if (isHuawei && androidVersion >= 9) {
      return true;
    }
    return false;
  }

  // 检查是否需要使用备用通知方式
  bool get needsAlternativeNotifyMethod {
    // 某些厂商设备需要使用备用通知方式
    if (isXiaomi && androidVersion >= 9 && androidVersion <= 11) {
      return true;
    }
    if (isOppo && androidVersion >= 9 && androidVersion <= 11) {
      return true;
    }
    return false;
  }

  // 获取厂商特定的配置
  Map<String, dynamic> getManufacturerConfig() {
    Map<String, dynamic> config = {};

    if (isXiaomi) {
      config['mtu'] = 512;
      config['connectionTimeout'] = 35;
      config['writeTimeout'] = 5;
      config['retryCount'] = 5;
      config['retryDelay'] = 300;
      config['connectDelay'] = 1000;
      config['discoverDelay'] = 1500;
      config['writeDelay'] = 100;
      config['notifyDelay'] = 500;
      config['useAlternativeConnection'] = androidVersion >= 10 && androidVersion <= 11;
      config['useAlternativeWrite'] = false;
      config['useAlternativeNotify'] = androidVersion >= 9 && androidVersion <= 11;
      config['disableSpecificFeatures'] = androidVersion <= 8;
    } else if (isHuawei) {
      config['mtu'] = 512;
      config['connectionTimeout'] = 35;
      config['writeTimeout'] = 5;
      config['retryCount'] = 5;
      config['retryDelay'] = 300;
      config['connectDelay'] = 1000;
      config['discoverDelay'] = 1500;
      config['writeDelay'] = 100;
      config['notifyDelay'] = 500;
      config['useAlternativeConnection'] = androidVersion >= 9 && androidVersion <= 10;
      config['useAlternativeWrite'] = androidVersion >= 9;
      config['useAlternativeNotify'] = false;
      config['disableSpecificFeatures'] = false;
    } else if (isSamsung) {
      config['mtu'] = 517;
      config['connectionTimeout'] = 30;
      config['writeTimeout'] = 5;
      config['retryCount'] = 4;
      config['retryDelay'] = 250;
      config['connectDelay'] = 750;
      config['discoverDelay'] = 1250;
      config['writeDelay'] = 75;
      config['notifyDelay'] = 400;
      config['useAlternativeConnection'] = false;
      config['useAlternativeWrite'] = androidVersion >= 10;
      config['useAlternativeNotify'] = false;
      config['disableSpecificFeatures'] = false;
    } else if (isOppo) {
      config['mtu'] = 512;
      config['connectionTimeout'] = 35;
      config['writeTimeout'] = 5;
      config['retryCount'] = 5;
      config['retryDelay'] = 300;
      config['connectDelay'] = 1000;
      config['discoverDelay'] = 1500;
      config['writeDelay'] = 100;
      config['notifyDelay'] = 500;
      config['useAlternativeConnection'] = false;
      config['useAlternativeWrite'] = false;
      config['useAlternativeNotify'] = androidVersion >= 9 && androidVersion <= 11;
      config['disableSpecificFeatures'] = androidVersion <= 9;
    } else if (isVivo) {
      config['mtu'] = 512;
      config['connectionTimeout'] = 35;
      config['writeTimeout'] = 5;
      config['retryCount'] = 5;
      config['retryDelay'] = 300;
      config['connectDelay'] = 1000;
      config['discoverDelay'] = 1500;
      config['writeDelay'] = 100;
      config['notifyDelay'] = 500;
      config['useAlternativeConnection'] = false;
      config['useAlternativeWrite'] = false;
      config['useAlternativeNotify'] = false;
      config['disableSpecificFeatures'] = false;
    } else {
      // 默认配置
      config['mtu'] = 517;
      config['connectionTimeout'] = 30;
      config['writeTimeout'] = 3;
      config['retryCount'] = 3;
      config['retryDelay'] = 200;
      config['connectDelay'] = 500;
      config['discoverDelay'] = 1000;
      config['writeDelay'] = 50;
      config['notifyDelay'] = 300;
      config['useAlternativeConnection'] = false;
      config['useAlternativeWrite'] = false;
      config['useAlternativeNotify'] = false;
      config['disableSpecificFeatures'] = false;
    }

    return config;
  }
}
