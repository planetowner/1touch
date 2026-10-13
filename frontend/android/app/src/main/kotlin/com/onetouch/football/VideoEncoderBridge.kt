package com.onetouch.football

import android.net.Uri
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.TransformationRequest
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

@OptIn(UnstableApi::class)
class VideoEncoderBridge(private val activity: FlutterActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "onetouch/video_encoder")
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "encode") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val jobId = call.argument<String>("jobId")
            if (path.isNullOrBlank() || jobId.isNullOrBlank() || !File(path).isFile) {
                result.error("invalid_media", null, null)
                return@setMethodCallHandler
            }
            encode(path, jobId, result)
        }
    }

    private fun emit(jobId: String, fraction: Double) {
        channel.invokeMethod("progress", mapOf(
            "jobId" to jobId,
            "fraction" to fraction.coerceIn(0.0, 1.0)
        ))
    }

    private fun emitVerification(jobId: String, fraction: Double) {
        mainHandler.post {
            channel.invokeMethod("verificationProgress", mapOf(
                "jobId" to jobId,
                "fraction" to fraction.coerceIn(0.0, 1.0)
            ))
        }
    }

    private fun encode(path: String, jobId: String, result: MethodChannel.Result) {
        val output = File(activity.cacheDir, "video-${System.nanoTime()}.mp4")
        val encoderFactory = DefaultEncoderFactory.Builder(activity)
            .setEnableFormatFallback(false)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(3_080_000).build()
            )
            .setRequestedAudioEncoderSettings(
                AudioEncoderSettings.Builder().setBitrate(92_000).build()
            )
            .build()
        var finished = false
        var fallback = false
        lateinit var poll: Runnable
        val transformer = Transformer.Builder(activity)
            .setVideoMimeType(MimeTypes.VIDEO_H265)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .addListener(object : Transformer.Listener {
                override fun onFallbackApplied(
                    composition: Composition,
                    originalTransformationRequest: TransformationRequest,
                    fallbackTransformationRequest: TransformationRequest
                ) {
                    fallback = true
                }

                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finished = true
                    mainHandler.removeCallbacks(poll)
                    if (fallback || exportResult.videoMimeType != MimeTypes.VIDEO_H265 ||
                        !output.isFile || output.length() == 0L) {
                        output.delete()
                        result.error("encode_failed", "HEVC export was unavailable on this device.", null)
                        return
                    }
                    emit(jobId, 1.0)
                    Thread {
                        try {
                            verifyEncodedVideo(output, jobId)
                            mainHandler.post {
                                result.success(mapOf("path" to output.path, "mimeType" to "video/mp4"))
                            }
                        } catch (error: Exception) {
                            output.delete()
                            mainHandler.post {
                                result.error("verify_failed", error.message, null)
                            }
                        }
                    }.start()
                }

                override fun onError(
                    composition: Composition, exportResult: ExportResult, exception: ExportException
                ) {
                    finished = true
                    mainHandler.removeCallbacks(poll)
                    output.delete()
                    result.error("encode_failed", exception.message, null)
                }
            })
            .build()
        val progress = ProgressHolder()
        var lastPercent = -1
        poll = object : Runnable {
            override fun run() {
                if (finished) return
                if (transformer.getProgress(progress) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    val percent = progress.progress.coerceIn(0, 99)
                    if (percent > lastPercent) {
                        lastPercent = percent
                        emit(jobId, percent / 100.0)
                    }
                }
                mainHandler.postDelayed(this, 250)
            }
        }
        try {
            transformer.start(MediaItem.fromUri(Uri.fromFile(File(path))), output.path)
            mainHandler.post(poll)
        } catch (error: Exception) {
            finished = true
            output.delete()
            result.error("encode_failed", error.message, null)
        }
    }

    private fun verifyEncodedVideo(file: File, jobId: String) {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        try {
            extractor.setDataSource(file.absolutePath)
            val track = (0 until extractor.trackCount).firstOrNull { index ->
                extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME)
                    ?.startsWith("video/") == true
            } ?: error("The encoded file has no video track.")
            val format = extractor.getTrackFormat(track)
            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: error("The encoded video has no MIME type.")
            val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION)
            } else 0L
            extractor.selectTrack(track)
            val codec = MediaCodec.createDecoderByType(mime)
            decoder = codec
            codec.configure(format, null, null, 0)
            codec.start()
            emitVerification(jobId, 0.0)

            // 인코딩 결과의 마지막 프레임까지 디코딩한 경우에만 업로드를 시작해요.
            val info = MediaCodec.BufferInfo()
            var inputEnded = false
            var outputEnded = false
            var frames = 0
            var lastPercent = -1
            var lastOutputAt = System.nanoTime()
            while (!outputEnded) {
                if (!inputEnded) {
                    val index = codec.dequeueInputBuffer(10_000)
                    if (index >= 0) {
                        val buffer = codec.getInputBuffer(index)
                            ?: error("The video decoder has no input buffer.")
                        buffer.clear()
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputEnded = true
                        } else {
                            codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val index = codec.dequeueOutputBuffer(info, 10_000)
                if (index >= 0) {
                    if (info.size > 0 && (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        frames++
                        if (durationUs > 0) {
                            val percent = ((info.presentationTimeUs.toDouble() / durationUs) * 100)
                                .toInt().coerceIn(0, 99)
                            if (percent > lastPercent) {
                                lastPercent = percent
                                emitVerification(jobId, percent / 100.0)
                            }
                        }
                    }
                    outputEnded = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                    codec.releaseOutputBuffer(index, false)
                    lastOutputAt = System.nanoTime()
                } else if (System.nanoTime() - lastOutputAt > 30_000_000_000L) {
                    error("The encoded video decoder stopped responding.")
                }
            }
            check(frames > 0) { "The encoded video has no decodable frames." }
            emitVerification(jobId, 1.0)
        } finally {
            decoder?.let {
                runCatching { it.stop() }
                it.release()
            }
            extractor.release()
        }
    }
}
