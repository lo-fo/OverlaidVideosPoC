//
//  AVLogic.swift
//  VideoOverlay-PoC
//
//  Created by Louis Fournier on 5/6/20.
//  Copyright © 2020 Louis Fournier. All rights reserved.
//

import AVFoundation

final class Renderer {

    var exportSession: AVAssetExportSession!

    func yo() {
        /* Setup Composition */
        guard
            let bgAsset = { () -> AVAsset? in
                guard let bgURL = Bundle.main.url(forResource: "IMG_7277", withExtension: "mp4") else { return nil }
                return AVAsset(url: bgURL)
            }(),
            let bgAsset2 = { () -> AVAsset? in
                guard let bgURL = Bundle.main.url(forResource: "IMG_7248", withExtension: "mp4") else { return nil }
                return AVAsset(url: bgURL)
            }(),
            let fgAsset = { () -> AVAsset? in
                guard let bgURL = Bundle.main.url(forResource: "7A49A023-7DC2-4C62-AD48-3D489FBAC598", withExtension: "mov") else { return nil }
                return AVAsset(url: bgURL)
            }() else { fatalError()}
            print("\(bgAsset) - \(fgAsset)")
        let composition = AVMutableComposition()
        guard
            let bgTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let bgTrack2 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let fgTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let bgVideoTrack = bgAsset.tracks(withMediaType: .video).first,
            let bgVideoTrack2 = bgAsset2.tracks(withMediaType: .video).first,
            let fgVideoTrack = fgAsset.tracks(withMediaType: .video).first
            else { fatalError() }
        /* Compute times to make fgAsset overlap on the cutting point between the two bgAssets */
        let halfLength = CMTimeMultiplyByRatio(fgAsset.duration, multiplier: -1, divisor: 2)
        let insertionTime = CMTimeAdd(bgAsset.duration, halfLength)
        /* end of computation */
        do {
        // Note: maybe instead of bgVideoTrack.timeRange -> CMTimeRangeMake(start: .zero, duration: fgAsset.duration)
            try bgTrack.insertTimeRange(bgVideoTrack.timeRange, of: bgVideoTrack, at: .zero)
            try bgTrack2.insertTimeRange(bgVideoTrack2.timeRange, of: bgVideoTrack2, at: CMTimeAdd(.zero, bgAsset.duration))
            try fgTrack.insertTimeRange(fgVideoTrack.timeRange, of: fgVideoTrack, at: insertionTime)
        } catch {
            fatalError()
        }
        /* Setup Video Composition */
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: CMTimeAdd(bgAsset.duration, bgAsset2.duration)) // 🤔
        let fgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fgTrack)
        fgLayerInstruction.setOpacity(0.0, at: CMTimeAdd(insertionTime, fgAsset.duration))
        let bgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: bgTrack)
        bgLayerInstruction.setOpacity(0.0, at: bgAsset.duration)
        let bgLayerInstruction2 = AVMutableVideoCompositionLayerInstruction(assetTrack: bgTrack2)
        /* ordered from fg to bg */
        instruction.layerInstructions = [fgLayerInstruction, bgLayerInstruction, bgLayerInstruction2]
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        videoComposition.frameDuration = bgTrack.minFrameDuration // 🤔
        videoComposition.renderSize = bgTrack.naturalSize // 🤔
        videoComposition.instructions = [instruction]
        /* Setup & Run Export */
        guard let fileURL = FileManager
            .default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(String(Date().timeIntervalSinceReferenceDate))
            .appendingPathExtension("mov") else { fatalError() }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try! FileManager.default.removeItem(atPath: fileURL.path)
        }
        exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality)
        exportSession.videoComposition = videoComposition
        exportSession.outputURL = fileURL
        exportSession.outputFileType = .mov
        exportSession?.exportAsynchronously { [weak self] in
            guard self?.exportSession.error == nil, let s = self?.exportSession.status, s == .completed else { fatalError() }
            print("successfully exported")
        }
    }
}
