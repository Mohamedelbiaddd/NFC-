package com.nfcstudio.nfc_studio

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// In-app update: Dart downloads the new APK into cacheDir, then this hands it
// to Android's PackageInstaller, which shows the system "Update" prompt.
class MainActivity : FlutterActivity() {
    private val action = "com.nfcstudio.nfc_studio.UPDATE_STATUS"
    private var receiverOn = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)
            if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm != null) {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(confirm)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tapmaroc/update")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkPath" -> result.success(File(cacheDir, "update.apk").absolutePath)
                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls()
                    )
                    "allowInstall" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                )
                            )
                        }
                        result.success(null)
                    }
                    "install" -> {
                        try {
                            install(File(call.argument<String>("path")!!))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun install(apk: File) {
        if (!receiverOn) {
            val filter = IntentFilter(action)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            receiverOn = true
        }
        val installer = packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(packageName)
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            session.openWrite("tapmaroc.apk", 0, apk.length()).use { out ->
                apk.inputStream().use { it.copyTo(out) }
                session.fsync(out)
            }
            val flags = if (Build.VERSION.SDK_INT >= 31) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val pending = PendingIntent.getBroadcast(
                this, id, Intent(action).setPackage(packageName), flags
            )
            session.commit(pending.intentSender)
        }
    }

    override fun onDestroy() {
        if (receiverOn) {
            unregisterReceiver(receiver)
            receiverOn = false
        }
        super.onDestroy()
    }
}
