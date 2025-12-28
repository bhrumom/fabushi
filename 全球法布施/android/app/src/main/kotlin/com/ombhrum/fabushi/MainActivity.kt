package com.ombhrum.fabushi

import android.content.ComponentCallbacks2
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fabushi.app/hotspot"
    private val DEVICE_INFO_CHANNEL = "com.ombhrum.fabushi/device_info"
    private val MEMORY_CHANNEL = "com.ombhrum.fabushi/memory"
    
    private var memoryChannel: MethodChannel? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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

