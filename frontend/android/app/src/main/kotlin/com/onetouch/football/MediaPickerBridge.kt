package com.onetouch.football

import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts.PickMultipleVisualMedia
import androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MediaPickerBridge(private val activity: FlutterActivity, messenger: BinaryMessenger) {
    private var pendingResult: MethodChannel.Result? = null
    private var maximum = 1

    init {
        MethodChannel(messenger, "onetouch/media_picker").setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingResult != null) {
                result.error("picker_open", null, null)
                return@setMethodCallHandler
            }
            val limit = call.argument<Int>("maxAssets")
            val imagesOnly = call.argument<Boolean>("imagesOnly")
            if (limit == null || limit < 1 || imagesOnly == null) {
                result.error("invalid_arguments", null, null)
                return@setMethodCallHandler
            }
            val request = PickVisualMediaRequest.Builder()
                .setMediaType(if (imagesOnly) PickVisualMedia.ImageOnly else PickVisualMedia.ImageAndVideo)
                .setOrderedSelection(true)
                .build()
            maximum = limit
            pendingResult = result
            try {
                // 시스템 선택기가 없는 기기는 AndroidX의 기본 파일 선택기를 사용해요.
                val intent = if (limit == 1) {
                    PickVisualMedia().createIntent(activity, request)
                } else {
                    PickMultipleVisualMedia(limit).createIntent(activity, request)
                }
                activity.startActivityForResult(intent, REQUEST_CODE)
            } catch (error: Exception) {
                pendingResult = null
                result.error("picker_failed", error.message, null)
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingResult ?: return true
        val uris = if (maximum == 1) {
            listOfNotNull(PickVisualMedia().parseResult(resultCode, data))
        } else {
            PickMultipleVisualMedia(maximum).parseResult(resultCode, data)
        }
        if (uris.isEmpty()) {
            pendingResult = null
            result.success(emptyList<Map<String, String>>())
            return true
        }
        Thread {
            val directory = File(activity.cacheDir, "picked-${UUID.randomUUID()}")
            try {
                check(directory.mkdirs()) { "Unable to create media cache." }
                // 파일 선택기의 개수 제한은 기기마다 달라서 기존 첨부 화면에서도 확인해요.
                val files = uris.mapIndexed { index, uri -> copyMedia(uri, directory, index) }
                activity.runOnUiThread {
                    pendingResult = null
                    result.success(files)
                }
            } catch (error: Exception) {
                directory.deleteRecursively()
                activity.runOnUiThread {
                    pendingResult = null
                    result.error("picker_failed", error.message, null)
                }
            }
        }.start()
        return true
    }

    private fun copyMedia(uri: Uri, directory: File, index: Int): Map<String, String> {
        val resolver = activity.contentResolver
        val mimeType = resolver.getType(uri) ?: error("Unable to read media type.")
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        val target = File(directory, if (extension == null) "$index" else "$index.$extension")
        // 임시 URI 대신 앱 파일을 넘겨 기존 미리보기·크롭·영상 인코딩에서 읽게 해요.
        resolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: error("Unable to open selected media.")
        return mapOf("path" to target.path, "mimeType" to mimeType)
    }

    private companion object {
        const val REQUEST_CODE = 4118

    }
}
