package com.nfcstudio.nfc_studio

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

// In-app update: Dart downloads the new APK into cacheDir, then this hands it
// to Android's PackageInstaller, which shows the system "Update" prompt.
// tapmaroc/device: phone model, processor type, the APK's signing
// certificate and root / emulator signs (account security), plus the
// tapmaroc://activate?t=... invitation link.
class MainActivity : FlutterActivity() {
    private val action = "com.nfcstudio.nfc_studio.UPDATE_STATUS"
    private var receiverOn = false
    private var deviceChannel: MethodChannel? = null
    private var pendingLink: String? = null

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

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        pendingLink = linkOf(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = linkOf(intent) ?: return
        pendingLink = link
        deviceChannel?.invokeMethod("link", link)
    }

    private fun linkOf(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "tapmaroc") data.toString() else null
    }

    private fun certSha256(): String {
        val sigs = if (Build.VERSION.SDK_INT >= 28) {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        val first = sigs?.firstOrNull() ?: return ""
        return MessageDigest.getInstance("SHA-256").digest(first.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    private fun rooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) return true
        val paths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su", "/system/app/Superuser.apk",
            "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su", "/system/sd/xbin/su",
            "/system/bin/failsafe/su", "/data/adb/magisk", "/sbin/.magisk", "/cache/.disable_magisk"
        )
        if (paths.any { File(it).exists() }) return true
        val apps = listOf("com.topjohnwu.magisk", "eu.chainfire.supersu", "com.koushikdutta.superuser",
            "me.weishu.kernelsu", "com.noshufou.android.su")
        return apps.any {
            try {
                packageManager.getPackageInfo(it, 0); true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun emulator(): Boolean {
        val f = Build.FINGERPRINT ?: ""
        val m = Build.MODEL ?: ""
        val h = Build.HARDWARE ?: ""
        return f.startsWith("generic") || f.startsWith("unknown") || f.contains("emulator") ||
            m.contains("Emulator") || m.contains("Android SDK built for") || m.contains("sdk_gphone") ||
            h == "goldfish" || h == "ranchu" || h.contains("vbox") ||
            (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
            Build.PRODUCT.contains("sdk") || Build.MANUFACTURER.contains("Genymotion")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tapmaroc/device").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "info" -> result.success(
                        mapOf(
                            "model" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                            "os" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
                            "abi" to (Build.SUPPORTED_ABIS.firstOrNull() ?: ""),
                            "cert" to try { certSha256() } catch (_: Exception) { "" },
                            "rooted" to rooted(),
                            "emulator" to emulator(),
                            "debuggable" to ((applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
                        )
                    )
                    "initialLink" -> {
                        result.success(pendingLink)
                        pendingLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
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
