package com.onetouch.football

import android.Manifest
import android.app.AlertDialog
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Gravity
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingSave: Pair<Map<*, *>, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VideoEncoderBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "onetouch/community_attachment")
            .setMethodCallHandler { call, result ->
                val args = call.arguments as? Map<*, *>
                if (args == null) {
                    result.error("invalid_arguments", null, null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "choose" -> {
                        val sheet = AlertDialog.Builder(this)
                        .setItems(arrayOf(args["save"] as? String ?: "Save", args["share"] as? String ?: "Share")) { _, which ->
                            result.success(if (which == 0) "save" else "share")
                        }
                        .setOnCancelListener { result.success(null) }
                        .create()
                        sheet.show()
                        sheet.window?.apply {
                            setGravity(Gravity.BOTTOM)
                            setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
                        }
                    }
                    "save" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingSave = args to result
                            requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 4117)
                        } else {
                            saveAttachment(args, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 4117) return
        val pending = pendingSave ?: return
        pendingSave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveAttachment(pending.first, pending.second)
        } else {
            pending.second.error("access_denied", null, null)
        }
    }

    private fun saveAttachment(args: Map<*, *>, result: MethodChannel.Result) {
        val source = (args["path"] as? String)?.let(::File)
        val isVideo = args["isVideo"] as? Boolean
        if (source == null || !source.isFile || isVideo == null) {
            result.error("invalid_arguments", null, null)
            return
        }
        val mime = args["mimeType"] as? String ?: if (isVideo) "video/mp4" else "image/jpeg"
        val name = "1touch_${System.currentTimeMillis()}.${source.extension.ifEmpty { if (isVideo) "mp4" else "jpg" }}"
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH,
                        (if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES) + "/1touch")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val collection = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    else MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                val uri = contentResolver.insert(collection, values) ?: throw IllegalStateException("MediaStore insert failed")
                try {
                    contentResolver.openOutputStream(uri)?.use { output -> source.inputStream().use { it.copyTo(output) } }
                        ?: throw IllegalStateException("MediaStore output failed")
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                } catch (error: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw error
                }
            } else {
                // Android 9 이하는 공유 저장소 권한을 받은 뒤 공개 갤러리에 저장해요.
                @Suppress("DEPRECATION")
                val folder = File(Environment.getExternalStoragePublicDirectory(
                    if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES), "1touch")
                if (!folder.exists() && !folder.mkdirs()) throw IllegalStateException("Gallery directory failed")
                val target = File(folder, name)
                source.copyTo(target)
                MediaScannerConnection.scanFile(this, arrayOf(target.path), arrayOf(mime), null)
            }
            result.success(null)
        } catch (error: Exception) {
            result.error("save_failed", error.message, null)
        }
    }
}
