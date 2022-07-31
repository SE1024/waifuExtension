//
//  HeavilyDistributed.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import Support
import CoreMedia

/// Process video in memory only mode, multiple core. This method is memory-inefficient, but fastest.
func processVideoMemoryOnlyDistributed(currentVideo: WorkItem, destination: FinderItem, manager: ProgressManager, model: ModelCoordinator) async {
    manager.status("Generating frames for \(currentVideo.fileName)")
    
    guard let videoAsset = currentVideo.avAsset else { return }
    guard let framesCount = videoAsset.framesCount else { return }
    var firstFrame: CGImage?
    
    guard var frames = await videoAsset.getFrames() else { return }
    firstFrame = frames.first?.cgImage
    let locker = NSRecursiveLock()
    
    let waifu2x = Waifu2x()
    
    DispatchQueue.concurrentPerform(iterations: framesCount) { index in
        autoreleasepool {
            let image = waifu2x.run(frames[index], model: model)
            
            locker.lock()
            frames[index] = image!
            locker.unlock()
            
            manager.videos[currentVideo]!.updateEnlarge()
        }
    }
    
    manager.status("Converting frames to video for \(currentVideo.fileName)")
    print(destination, "<><><>")
    
    await asyncAutoreleasepool {
        await FinderItem.convertImageSequenceToVideo(frames, videoPath: destination.path, videoSize: firstFrame!.size.scaled(by: CGFloat(model.caffe.scale)), videoFPS: videoAsset.frameRate!, colorSpace: firstFrame?.colorSpace)
    }
    
    manager.status("Merging video with audio for \(currentVideo.fileName)")
    await asyncAutoreleasepool {
        await FinderItem.mergeVideoWithAudio(videoUrl: destination.url, audioUrl: currentVideo.finderItem.url)
    }
    
    manager.status("\(currentVideo.fileName) Completed")
    
    // replace item
    if DestinationDataProvider.main.isNoneDestination {
        currentVideo.path = destination.path
    }
}
