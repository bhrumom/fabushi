package com.ombhrum.fabushi

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * User-visible Android foreground service for account device discovery.
 *
 * Android may still reclaim the process and may enforce foreground-service
 * quotas. START_STICKY plus the agent's signed reconnect protocol restores the
 * session without replaying any previous tool call.
 */
class FabushiDeviceMeshService : Service() {
    companion object {
        private const val ChannelId = "fabushi-device-mesh"
        private const val NotificationId = 0xFAB4
        const val ActionStart = "com.ombhrum.fabushi.device_mesh.START"
        const val ActionStop = "com.ombhrum.fabushi.device_mesh.STOP"

        fun start(context: Context) {
            val intent = Intent(context, FabushiDeviceMeshService::class.java).setAction(ActionStart)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent)
            else context.startService(intent)
        }

        fun stop(context: Context) {
            context.startService(Intent(context, FabushiDeviceMeshService::class.java).setAction(ActionStop))
        }
    }

    private var agent: FabushiDeviceMeshAgent? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannel()
        startForeground(NotificationId, notification("正在连接同账号设备网格"))
        agent = FabushiDeviceMeshAgent(this, FabushiAppAgentRegistry.surface).also(FabushiDeviceMeshAgent::start)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ActionStop) {
            stopSelf()
            return START_NOT_STICKY
        }
        val current = agent?.state()
        val message = when {
            current?.registered == true -> "此设备已可由同账号 Fabushi 安全发现"
            current?.connected == true -> "正在注册此设备"
            else -> "等待 Fabushi 登录并连接设备网格"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NotificationId, notification(message))
        agent?.start()
        return START_STICKY
    }

    override fun onDestroy() {
        agent?.close()
        agent = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(
            ChannelId,
            "同账号设备控制",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "在用户可见的前台服务中保持 Fabushi 设备发现和受控应用操作"
            setShowBadge(false)
        })
    }

    private fun notification(message: String): Notification {
        val openIntent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, FabushiDeviceMeshService::class.java).setAction(ActionStop),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, ChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Fabushi 设备网格")
            .setContentText(message)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "停止", stopIntent)
            .build()
    }
}
