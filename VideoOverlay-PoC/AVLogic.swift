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
            let fgAsset = { () -> AVAsset? in
                guard let bgURL = Bundle.main.url(forResource: "7A49A023-7DC2-4C62-AD48-3D489FBAC598", withExtension: "mov") else { return nil }
                return AVAsset(url: bgURL)
            }() else { fatalError()}
            print("\(bgAsset) - \(fgAsset)")
        let composition = AVMutableComposition()
        guard
            let bgTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let fgTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let bgVideoTrack = bgAsset.tracks(withMediaType: .video).first,
            let fgVideoTrack = fgAsset.tracks(withMediaType: .video).first
            else { fatalError() }
        do {
        // Note: maybe instead of bgVideoTrack.timeRange -> CMTimeRangeMake(start: .zero, duration: fgAsset.duration)
            try bgTrack.insertTimeRange(bgVideoTrack.timeRange, of: bgVideoTrack, at: .zero)
            try fgTrack.insertTimeRange(fgVideoTrack.timeRange, of: fgVideoTrack, at: .zero)
        } catch {
            fatalError()
        }
        /* Setup Video Composition */
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = bgTrack.timeRange // 🤔
        let fgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fgTrack)
        let bgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: bgTrack)
        /* ordered from fg to bg */
        instruction.layerInstructions = [fgLayerInstruction, bgLayerInstruction]
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
