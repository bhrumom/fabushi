# 支付宝SDK集成配置指南

## 概述
本文档记录了Flutter项目中集成支付宝SDK的完整过程和配置说明，遵循支付宝官方接入文档要求。

## 接入前准备（根据支付宝官方文档）

### 1. 商户账号准备
- 需要支付宝商户账号
- 完成实名认证
- 申请APP支付功能
- 获取商户私钥和支付宝公钥

### 2. 应用配置
- 在支付宝开放平台创建应用
- 配置应用包名/Bundle ID
- 获取APPID
- 配置密钥

## 已完成的集成步骤

### 1. 依赖添加
已在 `pubspec.yaml` 中添加支付宝SDK插件依赖：
```yaml
dependencies:
  tobias: ^3.3.0
```

### 2. 服务类创建
已创建 `lib/services/alipay_service.dart` 文件，包含：
- AlipayService 类（单例模式）
- 初始化支付宝SDK方法（包含安装检查）
- 发起APP支付功能（带参数验证）
- 支付结果解析（支持所有状态码）
- 支付宝安装状态检查
- SDK版本信息获取
- 支付参数验证
- 详细错误信息获取
- 安全订单字符串生成
- 支付结果回调处理

### 3. 前端集成
在 `lib/screens/membership_screen.dart` 中集成了支付宝APP支付：
- 添加了支付宝服务实例
- 实现了APP支付调用逻辑
- 添加了支付结果处理和会员状态刷新
- 支付参数验证
- 详细的错误处理和用户提示

### 4. 平台配置（符合支付宝官方要求）

#### iOS配置 (`ios/Runner/Info.plist`)
已添加完整的支付宝URL Scheme配置：
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>alipays</string>
    <string>alipay</string>
    <string>alipayqr</string>
    <string>alipayshare</string>
</array>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>alipay</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>globaldharma</string>
        </array>
    </dict>
</array>
```

#### Android配置 (`android/app/src/main/AndroidManifest.xml`)
已添加完整的支付宝查询配置：
```xml
<queries>
    <package android:name="com.eg.android.AlipayGphone" />
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="alipays" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="alipay" />
    </intent>
</queries>
```

## 支付结果码说明

根据支付宝官方文档，支付结果码含义如下：

| 结果码 | 含义 | 说明 |
|--------|------|------|
| 9000 | 订单支付成功 | 支付成功，可以更新订单状态 |
| 8000 | 正在处理中 | 支付结果未知，需要查询订单状态 |
| 4000 | 订单支付失败 | 支付失败，可以重新发起支付 |
| 5000 | 重复请求 | 同一订单重复提交，避免重复支付 |
| 6001 | 用户中途取消 | 用户主动取消支付操作 |
| 6002 | 网络连接出错 | 网络异常，检查网络后重试 |
| 6004 | 支付结果未知 | 支付结果未知，需要查询订单状态 |

## 还需要手动配置的部分

### 1. iOS平台额外配置

#### 添加支付宝SDK依赖
在iOS项目的 `Podfile` 中添加：
```ruby
pod 'AlipaySDK-iOS', '~> 15.8.27'
```

#### 配置App Transport Security
在 `ios/Runner/Info.plist` 中添加：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

#### 配置URL Scheme回调
在 `ios/Runner/AppDelegate.swift` 中添加支付宝回调处理：
```swift
import AlipaySDK

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.host == "safepay" {
      AlipaySDK.defaultService().processOrder(withPaymentResult: url, standbyCallback: nil)
      return true
    }
    return super.application(app, open: url, options: options)
  }
}
```

### 2. Android平台额外配置

#### 添加支付宝SDK依赖
在 `android/app/build.gradle` 中添加：
```gradle
dependencies {
    implementation 'com.alipay.sdk:alipaysdk-android:15.8.27'
}
```

#### 配置ProGuard规则
在 `android/app/proguard-rules.pro` 中添加：
```proguard
-keep class com.alipay.android.app.IAlixPay{*;}
-keep class com.alipay.android.app.IAlixPay$Stub{*;}
-keep class com.alipay.android.app.IRemoteServiceCallback{*;}
-keep class com.alipay.android.app.IRemoteServiceCallback$Stub{*;}
-keep class com.alipay.sdk.app.PayTask{*;}
-keep class com.alipay.sdk.app.AuthTask{*;}
-keep class com.alipay.sdk.app.H5PayCallback{*;}
-keep class com.alipay.android.phone.mrpc.core.** {*;}
-keep class com.alipay.apmobilesecuritysdk.** {*;}
-keep class com.alipay.mobile.framework.service.annotation.** {*;}
-keep class com.alipay.mobilesecuritysdk.face.** {*;}
-keep class com.alipay.tscenter.biz.rpc.** {*;}
-keep class org.json.alipay.** {*;}
-keep class com.alipay.tscenter.** {*;}
-keep class com.ta.utdid2.** {*;}
-keep class com.ut.device.** {*;}
```

#### 配置Activity
在 `android/app/src/main/AndroidManifest.xml` 中添加支付宝Activity：
```xml
<activity
    android:name="com.alipay.sdk.app.H5PayActivity"
    android:configChanges="orientation|keyboardHidden|navigation|screenSize"
    android:exported="false"
    android:screenOrientation="behind"
    android:windowSoftInputMode="adjustResize|stateHidden" />
```

## 使用说明

### 1. 初始化支付宝SDK
在应用启动时初始化：
```dart
final alipayService = AlipayService();
await alipayService.initAlipay();
```

### 2. 发起支付
```dart
final result = await alipayService.payWithAlipay(orderString);
if (result['success']) {
  // 支付成功
} else {
  // 支付失败
}
```

### 3. 检查支付宝安装状态
```dart
final isInstalled = await alipayService.isAlipayInstalled();
```

## 支付结果码说明
- `9000` - 订单支付成功
- `8000` - 正在处理中
- `4000` - 订单支付失败
- `5000` - 重复请求
- `6001` - 用户中途取消
- `6002` - 网络连接出错
- `6004` - 支付结果未知

## 注意事项
1. 确保后端已正确配置支付宝APP支付接口
2. 测试时使用沙箱环境，生产环境使用正式环境
3. 处理好支付回调和订单状态查询
4. 注意iOS和Android平台的差异化配置
5. 遵守支付宝的相关开发规范和安全要求

## 测试建议
1. 先在沙箱环境中测试支付流程
2. 确保能正确处理各种支付结果状态
3. 测试网络异常情况下的处理
4. 验证支付成功后的业务逻辑
5. 测试用户取消支付的场景