package com.ombhrum.fabushi

import android.content.ComponentCallbacks2
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

// 使用 FlutterFragmentActivity 以兼容现有插件和 Activity Result 流程
class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.fabushi.app/hotspot"
    private val DEVICE_INFO_CHANNEL = "com.ombhrum.fabushi/device_info"
    private val MEMORY_CHANNEL = "com.ombhrum.fabushi/memory"
    private val INBOUND_SHARE_CHANNEL = "com.ombhrum.fabushi/inbound_share"
    private val PLATFORM_PUBLISH_CHANNEL = "com.ombhrum.fabushi/platform_publish"
    
    private var memoryChannel: MethodChannel? = null
    private var inboundShareChannel: MethodChannel? = null
    private var pendingSharePayload: Map<String, Any?>? = null
    
    companion object {
        private const val TAG = "MainActivity"
        
        init {
            try {
                // 预加载 llama.cpp 及其依赖库，解决 Dart Isolate 中的动态链接问题
                // 顺序：基础依赖 -> 上层依赖
                System.loadLibrary("ggml-base")
                System.loadLibrary("ggml")
                System.loadLibrary("ggml-cpu")
                System.loadLibrary("llama")
                Log.i(TAG, "Native libraries loaded successfully")
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to load native libraries: ${e.message}")
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingSharePayload = extractSharePayload(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractSharePayload(intent)
        if (payload != null) {
            pendingSharePayload = payload
            try {
                inboundShareChannel?.invokeMethod("onIncomingShare", payload)
            } catch (e: Exception) {
                Log.w(TAG, "Notify Flutter incoming share failed: ${e.message}")
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        registerFlutterPlugins(flutterEngine)
        
        // 热点相关 Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHotspotEnabled" -> {
                    result.success(isHotspotEnabled())
                }
                "enableHotspot" -> {
                    val success = enableHotspot()
                    result.success(success)
                }
                "openHotspotSettings" -> {
                    openHotspotSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 设备信息 Method Channel（用于保活设置页面）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceBrand" -> {
                    result.success(Build.BRAND)
                }
                "getDeviceModel" -> {
                    result.success(Build.MODEL)
                }
                "getDeviceManufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }
                "openAutoStartSettings" -> {
                    openAutoStartSettings()
                    result.success(true)
                }
                "openBatteryOptimization" -> {
                    openBatteryOptimization()
                    result.success(true)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // 内存管理 Method Channel
        memoryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEMORY_CHANNEL)

        // 外部分享入口：接收来自豆包、浏览器等应用的链接或文本
        inboundShareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INBOUND_SHARE_CHANNEL)
        inboundShareChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> result.success(pendingSharePayload ?: emptyMap<String, Any?>())
                "clearInitialShare" -> {
                    pendingSharePayload = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 平台发布入口：把准备好的草稿交给 Android 分享/发布目标
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_PUBLISH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareToPlatform" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    val response = shareToPlatform(
                        packageName = args["packageName"]?.toString(),
                        platformName = args["platformName"]?.toString() ?: "目标平台",
                        title = args["title"]?.toString() ?: "",
                        text = args["text"]?.toString() ?: "",
                        url = args["url"]?.toString() ?: ""
                    )
                    result.success(response)
                }
                else -> result.notImplemented()
            }
        }
    }


    private fun extractSharePayload(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) {
            return null
        }

        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?: intent.getStringExtra(Intent.EXTRA_HTML_TEXT)
            ?: ""
        val dataText = intent.data?.toString() ?: ""
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
        val combinedText = listOf(sharedText, dataText)
            .filter { it.isNotBlank() }
            .joinToString("\n")
            .trim()
        val firstUrl = firstHttpUrl(combinedText)
            ?: dataText.takeIf { it.startsWith("http://") || it.startsWith("https://") }
            ?: ""

        if (combinedText.isBlank() && firstUrl.isBlank()) return null

        return mapOf(
            "text" to combinedText,
            "url" to firstUrl,
            "title" to subject,
            "mimeType" to (intent.type ?: ""),
            "sourcePackage" to (callingPackage ?: intent.getStringExtra(Intent.EXTRA_REFERRER_NAME) ?: ""),
            "receivedAt" to System.currentTimeMillis().toString()
        )
    }

    private fun firstHttpUrl(value: String): String? {
        val match = Regex("https?://[^\\s]+", RegexOption.IGNORE_CASE).find(value) ?: return null
        return match.value.trimEnd('，', '。', '、', ',', '.', ')', '）', ']', '】', '>', '》')
    }

    private fun shareToPlatform(
        packageName: String?,
        platformName: String,
        title: String,
        text: String,
        url: String
    ): Map<String, Any> {
        if (text.isBlank() && url.isBlank()) {
            return mapOf(
                "success" to false,
                "message" to "草稿内容为空，未拉起 $platformName"
            )
        }

        val shareText = if (text.isBlank()) url else text
        val targeted = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, title)
            putExtra(Intent.EXTRA_TEXT, shareText)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (!packageName.isNullOrBlank()) setPackage(packageName)
        }

        val pm = packageManager
        val canOpenTarget = targeted.resolveActivity(pm) != null
        return try {
            if (canOpenTarget) {
                startActivity(targeted)
                mapOf(
                    "success" to true,
                    "message" to "已拉起 $platformName，草稿内容已注入系统分享入口"
                )
            } else {
                val fallback = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, title)
                    putExtra(Intent.EXTRA_TEXT, shareText)
                }
                val chooser = Intent.createChooser(fallback, "选择发布到 $platformName")
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(chooser)
                mapOf(
                    "success" to true,
                    "message" to "未找到 $platformName 专用入口，已打开系统分享面板"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Share to platform failed", e)
            mapOf(
                "success" to false,
                "message" to "拉起 $platformName 失败：${e.message ?: "未知错误"}"
            )
        }
    }


    private fun registerFlutterPlugins(flutterEngine: FlutterEngine) {
        // Skip ffmpeg_kit_flutter_new_audio on Android startup. Its native library can
        // fail JNI loading on some Android 14 / arm64 devices and crash the app before
        // Flutter renders the first frame.
        registerPlugin(flutterEngine, "app_links") { com.llfbandit.app_links.AppLinksPlugin() }
        registerPlugin(flutterEngine, "audio_session") { com.ryanheise.audio_session.AudioSessionPlugin() }
        registerPlugin(flutterEngine, "cloud_firestore") { io.flutter.plugins.firebase.firestore.FlutterFirebaseFirestorePlugin() }
        registerPlugin(flutterEngine, "connectivity_plus") { dev.fluttercommunity.plus.connectivity.ConnectivityPlugin() }
        registerPlugin(flutterEngine, "device_info_plus") { dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin() }
        registerPlugin(flutterEngine, "file_picker") { com.mr.flutter.plugin.filepicker.FilePickerPlugin() }
        registerPlugin(flutterEngine, "firebase_auth") { io.flutter.plugins.firebase.auth.FlutterFirebaseAuthPlugin() }
        registerPlugin(flutterEngine, "firebase_core") { io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin() }
        registerPlugin(flutterEngine, "flutter_inappwebview_android") { com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin() }
        registerPlugin(flutterEngine, "flutter_local_notifications") { com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin() }
        registerPlugin(flutterEngine, "flutter_plugin_android_lifecycle") { io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin() }
        registerPlugin(flutterEngine, "flutter_tts") { com.eyedeadevelopment.fluttertts.FlutterTtsPlugin() }
        registerPlugin(flutterEngine, "flutter_volume_controller") { com.yosemiteyss.flutter_volume_controller.FlutterVolumeControllerPlugin() }
        registerPlugin(flutterEngine, "geolocator_android") { com.baseflow.geolocator.GeolocatorPlugin() }
        registerPlugin(flutterEngine, "google_sign_in_android") { io.flutter.plugins.googlesignin.GoogleSignInPlugin() }
        registerPlugin(flutterEngine, "in_app_purchase_android") { io.flutter.plugins.inapppurchase.InAppPurchasePlugin() }
        registerPlugin(flutterEngine, "just_audio") { com.ryanheise.just_audio.JustAudioPlugin() }
        registerPlugin(flutterEngine, "network_info_plus") { dev.fluttercommunity.plus.network_info.NetworkInfoPlusPlugin() }
        registerPlugin(flutterEngine, "package_info_plus") { dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin() }
        registerPlugin(flutterEngine, "path_provider_android") { io.flutter.plugins.pathprovider.PathProviderPlugin() }
        registerPlugin(flutterEngine, "permission_handler_android") { com.baseflow.permissionhandler.PermissionHandlerPlugin() }
        registerPlugin(flutterEngine, "record_android") { com.llfbandit.record.RecordPlugin() }
        registerPlugin(flutterEngine, "shared_preferences_android") { io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin() }
        registerPlugin(flutterEngine, "sign_in_with_apple") { com.aboutyou.dart_packages.sign_in_with_apple.SignInWithApplePlugin() }
        registerPlugin(flutterEngine, "sqflite_android") { com.tekartik.sqflite.SqflitePlugin() }
        registerPlugin(flutterEngine, "tobias") { com.jarvan.tobias.TobiasPlugin() }
        registerPlugin(flutterEngine, "url_launcher_android") { io.flutter.plugins.urllauncher.UrlLauncherPlugin() }
        registerPlugin(flutterEngine, "video_player_android") { io.flutter.plugins.videoplayer.VideoPlayerPlugin() }
        registerPlugin(flutterEngine, "webview_flutter_android") { io.flutter.plugins.webviewflutter.WebViewFlutterPlugin() }
        registerPlugin(flutterEngine, "workmanager") { dev.fluttercommunity.workmanager.WorkmanagerPlugin() }
    }

    private fun registerPlugin(
        flutterEngine: FlutterEngine,
        name: String,
        pluginFactory: () -> FlutterPlugin
    ) {
        try {
            flutterEngine.plugins.add(pluginFactory())
        } catch (t: Throwable) {
            Log.e(TAG, "Error registering plugin $name", t)
        }
    }
    
    /**
     * 系统内存压力回调
     * 
     * 当系统内存不足时，通知 Flutter 层释放缓存
     */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        
        Log.d(TAG, "onTrimMemory: level=$level")
        
        when (level) {
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL,
            ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW -> {
                // 内存紧张，通知 Flutter 层释放缓存
                Log.w(TAG, "内存紧张，通知 Flutter 释放缓存")
                notifyFlutterLowMemory(level)
            }
            ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> {
                // UI 不可见，可以释放一些资源
                Log.d(TAG, "UI 不可见")
            }
            ComponentCallbacks2.TRIM_MEMORY_BACKGROUND,
            ComponentCallbacks2.TRIM_MEMORY_MODERATE,
            ComponentCallbacks2.TRIM_MEMORY_COMPLETE -> {
                // 后台内存压力
                Log.w(TAG, "后台内存压力，level=$level")
                notifyFlutterLowMemory(level)
            }
        }
    }
    
    /**
     * 低内存回调
     */
    override fun onLowMemory() {
        super.onLowMemory()
        Log.e(TAG, "系统低内存警告")
        notifyFlutterLowMemory(ComponentCallbacks2.TRIM_MEMORY_COMPLETE)
    }
    
    /**
     * 通知 Flutter 层释放内存
     */
    private fun notifyFlutterLowMemory(level: Int) {
        try {
            memoryChannel?.invokeMethod("onLowMemory", level)
        } catch (e: Exception) {
            Log.e(TAG, "通知 Flutter 失败: ${e.message}")
        }
    }

    private fun isHotspotEnabled(): Boolean {
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method = wifiManager.javaClass.getDeclaredMethod("isWifiApEnabled")
            method.isAccessible = true
            return method.invoke(wifiManager) as Boolean
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun enableHotspot(): Boolean {
        try {
            // Android 8.0+ 需要使用 LocalOnlyHotspot 或引导用户手动开启
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // 打开热点设置页面
                openHotspotSettings()
                return false // 返回 false 表示需要用户手动操作
            } else {
                // Android 7.1 及以下可以尝试直接开启
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val method = wifiManager.javaClass.getDeclaredMethod(
                    "setWifiApEnabled",
                    android.net.wifi.WifiConfiguration::class.java,
                    Boolean::class.javaPrimitiveType
                )
                method.isAccessible = true
                
                // 先关闭 WiFi
                wifiManager.isWifiEnabled = false
                
                // 开启热点
                return method.invoke(wifiManager, null, true) as Boolean
            }
        } catch (e: Exception) {
            e.printStackTrace()
            openHotspotSettings()
            return false
        }
    }

    private fun openHotspotSettings() {
        try {
            // 尝试直接打开热点设置
            val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            try {
                // 备用：打开设置主页
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }

    /**
     * 打开厂商自启动设置页面
     * 
     * 支持：小米/Redmi、华为/荣耀、OPPO/Realme、vivo、三星、联想等
     */
    private fun openAutoStartSettings() {
        val manufacturer = Build.MANUFACTURER.lowercase()
        Log.d(TAG, "设备厂商: $manufacturer")
        
        val intent = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> {
                // 小米 MIUI
                Intent().apply {
                    component = ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                // 华为 EMUI / 荣耀
                Intent().apply {
                    component = ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                    )
                }
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") -> {
                // OPPO ColorOS / Realme
                Intent().apply {
                    component = ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity"
                    )
                }
            }
            manufacturer.contains("vivo") -> {
                // vivo OriginOS / FuntouchOS
                Intent().apply {
                    component = ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                    )
                }
            }
            manufacturer.contains("samsung") -> {
                // 三星 One UI - 跳转到电池优化页面
                Intent().apply {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.parse("package:$packageName")
                }
            }
            manufacturer.contains("lenovo") || manufacturer.contains("zte") || manufacturer.contains("meizu") -> {
                // 联想、中兴、魅族
                Intent().apply {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.parse("package:$packageName")
                }
            }
            else -> {
                // 其他品牌 - 跳转到应用详情页
                Intent().apply {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.parse("package:$packageName")
                }
            }
        }
        
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        
        try {
            startActivity(intent)
            Log.d(TAG, "成功打开自启动设置页面")
        } catch (e: Exception) {
            Log.w(TAG, "打开自启动设置失败，尝试备用方案: ${e.message}")
            // 备用方案：尝试打开应用详情页
            openAppSettings()
        }
    }

    /**
     * 打开电池优化设置页面
     */
    private fun openBatteryOptimization() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            Log.d(TAG, "成功打开电池优化设置页面")
        } catch (e: Exception) {
            Log.w(TAG, "打开电池优化设置失败: ${e.message}")
            // 备用：跳转到应用设置
            openAppSettings()
        }
    }

    /**
     * 打开应用详情设置页面
     */
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            Log.d(TAG, "成功打开应用设置页面")
        } catch (e: Exception) {
            Log.e(TAG, "打开应用设置失败: ${e.message}")
            // 最后备用：打开设置主页
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }
}

