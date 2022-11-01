//
//  HeavilyDistributed.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import Support
import CoreMedia
import AVFoundation

/// Process video in memory only mode, multiple core. This method is memory-inefficient, but fastest.
func processVideoMemoryOnlyDistributed(currentVideo: WorkItem, destination: FinderItem, manager: ProgressManager, model: ModelCoordinator) async {
    manager.status("Generating frames for \(currentVideo.fileName)")
    
    guard let videoAsset = AVAsset(at: currentVideo.finderItem) else { return }
    var firstFrame: CGImage?
    
    let frames: [CGImage]
    
    if #available(macOS 13, *) {
        guard let generated = await videoAsset.generateFrames() else { return }
        frames = generated
    } else {
        guard let generated = await videoAsset.getFrames() else { return }
        frames = generated
    }
    
    firstFrame = frames.first
    
    if model.enableCompressIntermediateFrames {
        let inferredFrames = frames.concurrentMap {
            processFrameWaifu2x(source: $0, model: model, progress: manager.progress)!.data(using: .heic)!
        }
        
        manager.status("Converting frames to video for \(currentVideo.fileName)")
        
        let destinationDataProvider = DestinationDataProvider()
        try! await AVAsset.convert(images: inferredFrames, toVideo: destination, videoFPS: videoAsset.frameRate!, colorSpace: firstFrame?.colorSpace, container: destinationDataProvider.videoContainer.avFileType, codec: destinationDataProvider.videoCodec.avVideoCodecType, getImage: { NativeImage(data: $0)!.cgImage! })
    } else {
        let inferredFrames = frames.concurrentMap {
            processFrameWaifu2x(source: $0, model: model, progress: manager.progress)!
        }
        
        manager.status("Converting frames to video for \(currentVideo.fileName)")
        
        let destinationDataProvider = DestinationDataProvider()
        try! await AVAsset.convert(images: inferredFrames, toVideo: destination, videoFPS: videoAsset.frameRate!, colorSpace: firstFrame?.colorSpace, container: destinationDataProvider.videoContainer.avFileType, codec: destinationDataProvider.videoCodec.avVideoCodecType, getImage: { $0 })
    }
    
    
    manager.status("Merging video with audio for \(currentVideo.fileName)")
    
    if AVAsset(at: currentVideo.finderItem)?.audioTrack != nil {
        try! await AVAsset.merge(video: destination, withAudio: currentVideo.finderItem)
    }
    manager.status("\(currentVideo.fileName) Completed")
}
