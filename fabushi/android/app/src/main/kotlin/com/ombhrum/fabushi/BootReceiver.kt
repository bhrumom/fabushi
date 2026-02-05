package com.ombhrum.fabushi

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机自启动广播接收器
 * 
 * 设备重启后，检查是否有需要恢复的发送任务。
 * 如果有，尝试启动应用以恢复发送。
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        
        Log.d(TAG, "收到广播: $action")
        
        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == "android.intent.action.QUICKBOOT_POWERON") {
            
            // 检查 SharedPreferences 中是否有活跃的发送任务
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isActive = prefs.getBoolean("flutter.sending_is_active", false)
            
            if (isActive) {
                Log.d(TAG, "检测到需要恢复的发送任务，启动应用...")
                
                try {
                    // 启动应用主 Activity
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    launchIntent?.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        putExtra("from_boot_receiver", true)
                    }
                    
                    if (launchIntent != null) {
                        context.startActivity(launchIntent)
                        Log.d(TAG, "应用已启动")
                    } else {
                        Log.e(TAG, "无法获取启动 Intent")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "启动应用失败: ${e.message}")
                }
            } else {
                Log.d(TAG, "无需恢复发送任务")
            }
        }
    }
}
