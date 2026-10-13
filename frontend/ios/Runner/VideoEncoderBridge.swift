@preconcurrency import AVFoundation
import Flutter
import UIKit
import VideoToolbox

final class VideoEncoderBridge {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "onetouch/video_encoder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, reply in
      self?.handle(call, reply: reply)
    }
  }

  private func handle(_ call: FlutterMethodCall, reply: @escaping FlutterResult) {
    guard call.method == "encode" else {
      reply(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let jobId = args["jobId"] as? String,
          FileManager.default.fileExists(atPath: path) else {
      reply(FlutterError(code: "invalid_media", message: nil, details: nil))
      return
    }
    Task { @MainActor in
      do {
        reply(try await encode(path: path, jobId: jobId))
      } catch {
        reply(FlutterError(code: "encode_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func emit(_ fraction: Double, jobId: String) {
    DispatchQueue.main.async {
      self.channel.invokeMethod("progress", arguments: [
        "jobId": jobId,
        "fraction": min(1, max(0, fraction)),
      ])
    }
  }

  private func emitVerification(_ fraction: Double, jobId: String) {
    DispatchQueue.main.async {
      self.channel.invokeMethod("verificationProgress", arguments: [
        "jobId": jobId,
        "fraction": min(1, max(0, fraction)),
      ])
    }
  }

  private func encode(path: String, jobId: String) async throws -> [String: Any] {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let tracks = try await asset.load(.tracks)
    let duration = try await asset.load(.duration)
    guard let track = tracks.first(where: { $0.mediaType == .video }) else {
      throw mediaError("The selected file has no video track.")
    }
    let size = try await track.load(.naturalSize)
    let transform = try await track.load(.preferredTransform)
    let frameRate = try await track.load(.nominalFrameRate)
    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("mp4")

    do {
      let reader = try AVAssetReader(asset: asset)
      let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
      let videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      ])
      videoOutput.alwaysCopiesSampleData = false
      guard reader.canAdd(videoOutput) else { throw mediaError("Video track could not be read.") }
      reader.add(videoOutput)

      var compression: [String: Any] = [
        AVVideoAverageBitRateKey: 3_080_000,
        AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
        AVVideoAllowFrameReorderingKey: true,
      ]
      if frameRate > 0 {
        compression[AVVideoExpectedSourceFrameRateKey] = Int(frameRate.rounded())
      }
      let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: Int(size.width.rounded()),
        AVVideoHeightKey: Int(size.height.rounded()),
        AVVideoCompressionPropertiesKey: compression,
      ]
      guard writer.canApply(outputSettings: videoSettings, forMediaType: .video) else {
        throw mediaError("HEVC encoding is unavailable on this device.")
      }
      let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
      videoInput.expectsMediaDataInRealTime = false
      videoInput.transform = transform
      guard writer.canAdd(videoInput) else { throw mediaError("Video encoder could not start.") }
      writer.add(videoInput)

      var audioOutput: AVAssetReaderOutput?
      var audioInput: AVAssetWriterInput?
      if let audioTrack = tracks.first(where: { $0.mediaType == .audio }) {
        let output = AVAssetReaderAudioMixOutput(audioTracks: [audioTrack], audioSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: 44_100,
          AVNumberOfChannelsKey: 2,
          AVLinearPCMBitDepthKey: 16,
          AVLinearPCMIsFloatKey: false,
          AVLinearPCMIsBigEndianKey: false,
          AVLinearPCMIsNonInterleaved: false,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw mediaError("Audio track could not be read.") }
        reader.add(output)
        let settings: [String: Any] = [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44_100,
          AVNumberOfChannelsKey: 2,
          AVEncoderBitRateKey: 92_000,
        ]
        guard writer.canApply(outputSettings: settings, forMediaType: .audio) else {
          throw mediaError("Audio encoder could not start.")
        }
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw mediaError("Audio encoder could not start.") }
        writer.add(input)
        audioOutput = output
        audioInput = input
      }

      guard writer.startWriting(), reader.startReading() else {
        throw writer.error ?? reader.error ?? mediaError("Video conversion could not start.")
      }
      writer.startSession(atSourceTime: .zero)
      try await appendSamples(reader: reader, writer: writer,
                              videoOutput: videoOutput, videoInput: videoInput,
                              audioOutput: audioOutput, audioInput: audioInput,
                              duration: duration.seconds, jobId: jobId)
      let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
      guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) > 0 else {
        throw mediaError("The encoded video is empty.")
      }
      emit(1, jobId: jobId)
      try await verifyEncodedVideo(at: destination, jobId: jobId)
      return ["path": destination.path, "mimeType": "video/mp4"]
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
  }

  private func verifyEncodedVideo(at url: URL, jobId: String) async throws {
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.load(.tracks)
    let duration = try await asset.load(.duration).seconds
    guard let track = tracks.first(where: { $0.mediaType == .video }) else {
      throw mediaError("The encoded file has no video track.")
    }
    emitVerification(0, jobId: jobId)
    // 변환된 파일의 모든 영상 프레임을 다시 디코딩해야 업로드를 허용해요.
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let reader = try AVAssetReader(asset: asset)
          let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String:
              kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
          ])
          guard reader.canAdd(output) else {
            throw self.mediaError("The encoded video could not be decoded.")
          }
          reader.add(output)
          guard reader.startReading() else {
            throw reader.error ?? self.mediaError("The encoded video could not be read.")
          }
          var frameCount = 0
          var lastPercent = -1
          while let sample = output.copyNextSampleBuffer() {
            frameCount += 1
            if duration.isFinite && duration > 0 {
              let fraction = CMSampleBufferGetPresentationTimeStamp(sample).seconds / duration
              if fraction.isFinite {
                let percent = Int((min(0.99, max(0, fraction)) * 100).rounded(.down))
                if percent > lastPercent {
                  lastPercent = percent
                  self.emitVerification(Double(percent) / 100, jobId: jobId)
                }
              }
            }
          }
          guard frameCount > 0 && reader.status == .completed else {
            throw reader.error ?? self.mediaError("The encoded video could not be decoded completely.")
          }
          self.emitVerification(1, jobId: jobId)
          continuation.resume()
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func appendSamples(reader: AVAssetReader, writer: AVAssetWriter,
                             videoOutput: AVAssetReaderOutput, videoInput: AVAssetWriterInput,
                             audioOutput: AVAssetReaderOutput?, audioInput: AVAssetWriterInput?,
                             duration: Double, jobId: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      let group = DispatchGroup()
      let lock = NSLock()
      var failure: Error?
      func fail(_ error: Error) {
        lock.lock()
        if failure == nil { failure = error; reader.cancelReading() }
        lock.unlock()
      }

      group.enter()
      var videoFinished = false
      videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "onetouch.video.encoder")) {
        guard !videoFinished else { return }
        while videoInput.isReadyForMoreMediaData {
          guard let sample = videoOutput.copyNextSampleBuffer() else {
            videoFinished = true
            videoInput.markAsFinished()
            group.leave()
            return
          }
          guard videoInput.append(sample) else {
            videoFinished = true
            videoInput.markAsFinished()
            fail(writer.error ?? self.mediaError("Video encoding failed."))
            group.leave()
            return
          }
          if duration > 0 {
            let fraction = CMSampleBufferGetPresentationTimeStamp(sample).seconds / duration
            self.emit(min(0.99, fraction), jobId: jobId)
          }
        }
      }
      if let audioOutput, let audioInput {
        group.enter()
        var audioFinished = false
        audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "onetouch.audio.encoder")) {
          guard !audioFinished else { return }
          while audioInput.isReadyForMoreMediaData {
            guard let sample = audioOutput.copyNextSampleBuffer() else {
              audioFinished = true
              audioInput.markAsFinished()
              group.leave()
              return
            }
            guard audioInput.append(sample) else {
              audioFinished = true
              audioInput.markAsFinished()
              fail(writer.error ?? self.mediaError("Audio encoding failed."))
              group.leave()
              return
            }
          }
        }
      }
      group.notify(queue: .global(qos: .userInitiated)) {
        lock.lock()
        let error = failure
        lock.unlock()
        if let error {
          writer.cancelWriting()
          continuation.resume(throwing: error)
        } else if reader.status == .failed {
          writer.cancelWriting()
          continuation.resume(throwing: reader.error ?? self.mediaError("Video reading failed."))
        } else {
          writer.finishWriting {
            if writer.status == .completed {
              continuation.resume()
            } else {
              continuation.resume(throwing: writer.error ?? self.mediaError("Video encoding failed."))
            }
          }
        }
      }
    }
  }

  private func mediaError(_ message: String) -> NSError {
    NSError(domain: "VideoEncoder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
