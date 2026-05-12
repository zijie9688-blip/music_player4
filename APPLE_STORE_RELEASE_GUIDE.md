# myDAT - Apple App Store 发布指南

## 1. 准备工作

### 1.1 Apple开发者账号
- 确保已注册Apple Developer Program（https://developer.apple.com/programs/enroll/）
- 登录App Store Connect（https://appstoreconnect.apple.com/）

### 1.2 当前项目配置信息
- 应用名称：myDAT
- Bundle Identifier：com.sofei.myDAT
- 当前版本：1.0.2
- 构建号：3
- 开发团队ID：34MSZ934U7
- 配置文件名称：myDAT

## 2. 代码配置检查

### 2.1 版本号配置
当前版本配置：
- pubspec.yaml中：version: 1.0.2+3
- Info.plist中：使用$(FLUTTER_BUILD_NAME)和$(FLUTTER_BUILD_NUMBER)

### 2.2 权限配置
Info.plist中已配置的权限：
- NSBluetoothAlwaysUsageDescription: "This app needs Bluetooth to connect devices"
- NSBluetoothPeripheralUsageDescription: "This app uses Bluetooth for device connection"
- NSLocationWhenInUseUsageDescription: "This app needs location to scan nearby Bluetooth devices"

## 3. 构建和发布步骤

### 3.1 更新版本号（如需要）
在pubspec.yaml中更新版本号：
```yaml
version: 1.0.3+4  # 格式：版本号+构建号
```

### 3.2 构建iOS发布版本
在项目根目录执行：
```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release
```

### 3.3 使用Xcode上传
1. 打开Xcode项目：
   ```bash
   open ios/Runner.xcworkspace
   ```

2. 在Xcode中：
   - 选择Runner项目
   - 选择"Runner" target
   - 在"Signing & Capabilities"选项卡中：
     * 确保Team选择正确（34MSZ934U7）
     * 确保Bundle Identifier为com.sofei.myDAT
     * 确保Provisioning Profile为myDAT

3. 选择Product > Archive进行归档

4. 归档完成后，在Organizer窗口中：
   - 选择刚创建的archive
   - 点击"Distribute App"
   - 选择"App Store Connect"
   - 按照提示上传

### 3.4 App Store Connect配置
1. 登录App Store Connect
2. 创建新应用或选择现有应用
3. 填写应用信息：
   - 应用名称：myDAT
   - 副标题：A music player application
   - 类别：音乐
   - Bundle ID：com.sofei.myDAT

4. 上传应用截图：
   - iPhone 6.7英寸：1290 x 2796像素
   - iPhone 6.5英寸：1242 x 2688像素
   - iPhone 5.5英寸：1242 x 2208像素

5. 填写应用描述和关键词

6. 提交审核

## 4. 注意事项

### 4.1 审核要点
- 确保应用功能完整，没有明显bug
- 确保隐私政策完整
- 确保权限使用说明清晰
- 确保应用符合Apple的人机界面指南

### 4.2 常见问题
- 蓝牙权限使用说明需要详细描述使用场景
- 位置权限使用说明需要详细描述使用场景
- 确保应用在所有支持的设备上都能正常运行

## 5. 更新应用

### 5.1 更新流程
1. 修改pubspec.yaml中的版本号
2. 进行必要的代码修改
3. 重新构建和上传
4. 在App Store Connect中创建新版本
5. 提交审核

### 5.2 版本号规则
- 版本号：主版本.次版本.修订版本（如1.0.3）
- 构建号：每次发布必须递增（如4）
- 格式：version: 1.0.3+4
