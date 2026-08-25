#!/usr/bin/env swift
//
// Prepares a replacement backdrop for Screen 1.
//
//   Scripts/prepare-welcome-clip.swift ~/Desktop/my-clip.mp4
//
// Does the two things that are easy to forget and invisible until they bite:
//
//   1. Strips the audio track. A decorative backdrop must be silent, and an mp4 that
//      still carries audio can make AVPlayer claim the audio session and stop
//      whatever the traveller is listening to. Passthrough, so no re-encode.
//   2. Regenerates the poster frame from the new clip. The poster sits under the
//      player at all times — before the first frame decodes, under Reduce Motion, and
//      if the clip goes missing — so a poster from the *old* clip is a visible jump.
//
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    print("usage: prepare-welcome-clip.swift <source-video>")
    exit(2)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let clip = root.appending(path: "Vihara/Resources/welcome_loop.mp4")
let poster = root.appending(path: "Vihara/Assets.xcassets/welcome_bg.imageset/welcome_bg.jpg")

guard FileManager.default.fileExists(atPath: poster.deletingLastPathComponent().path) else {
    print("error: run this from the repository root")
    exit(1)
}

let done = DispatchSemaphore(value: 0)

Task {
    do {
        let asset = AVURLAsset(url: source)

        // 1 — video-only copy.
        let composition = AVMutableComposition()
        guard let sourceTrack = try await asset.loadTracks(withMediaType: .video).first,
              let track = composition.addMutableTrack(withMediaType: .video,
                                                      preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            print("error: \(source.lastPathComponent) has no video track")
            exit(1)
        }
        let duration = try await asset.load(.duration)
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration),
                                  of: sourceTrack, at: .zero)
        track.preferredTransform = try await sourceTrack.load(.preferredTransform)

        try? FileManager.default.removeItem(at: clip)
        guard let export = AVAssetExportSession(asset: composition,
                                                presetName: AVAssetExportPresetPassthrough)
        else {
            print("error: could not create an export session")
            exit(1)
        }
        export.outputURL = clip
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        await export.export()
        if let error = export.error {
            print("error: export failed — \(error.localizedDescription)")
            exit(1)
        }

        // 2 — poster frame, from the clip we just wrote.
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: clip))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let (image, _) = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600))

        guard let destination = CGImageDestinationCreateWithURL(
            poster as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else {
            print("error: could not write the poster frame")
            exit(1)
        }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        CGImageDestinationFinalize(destination)

        let size = (try? FileManager.default.attributesOfItem(atPath: clip.path)[.size] as? Int) ?? 0
        print("""
              ✔ welcome_loop.mp4  \(size / 1024) KB, audio stripped
              ✔ welcome_bg.jpg    \(image.width)×\(image.height) poster frame
              """)
    } catch {
        print("error: \(error.localizedDescription)")
        exit(1)
    }
    done.signal()
}

done.wait()
