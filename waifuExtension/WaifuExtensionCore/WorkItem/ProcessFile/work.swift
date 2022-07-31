//
//  MainModel.work.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import Support
import os

extension MainModel {
    
    public func work(model: ModelCoordinator, task: ShellManagers, manager: ProgressManager, outputPath: FinderItem) async {
        let logger = Logger()
        logger.info("Process File started with model: \(model.description) with \(self.items.filter{ $0.type == .image }.count) images and \(self.items.filter{ $0.type == .video }.count) videos")
        
        // prepare progress, fill `manager: ProgressManager`
        Task { @MainActor in
            for i in self.items {
                if i.type == .image {
                    manager.images[i] = .init(manager: manager)
                } else {
                    let item = ProgressManager.Video.init(manager: manager)
                    item.interpolationLevel = Double(model.frameInterpolation)
                    item.totalFrames = Double(i.finderItem.avAsset!.frameRate!) * i.finderItem.avAsset!.duration.seconds
                    manager.videos[i] = item
                }
            }
        }
        
        let images = self.items.filter({ $0.type == .image })
        let videos = self.items.filter({ $0.type == .video })
        
        outputPath.generateDirectory(isFolder: true)
        
        if let image = FinderItem.bundleItem(forResource: "icon", withExtension: "icns")?.image {
            outputPath.setIcon(image: image)
        }
        
        // process Images
        if !images.isEmpty {
            manager.status("Processing Images")
            logger.info("Processing Images")
            
            if model.enableConcurrent && model.isCaffe {
                await asyncAutoreleasepool {
                    DispatchQueue.concurrentPerform(iterations: images.count) { imageIndex in
                        processImage(currentImage: images[imageIndex], manager: manager, task: task, outputPath: outputPath, model: model, logger: logger)
                    }
                }
            } else {
                for imageIndex in 0..<images.count {
                    processImage(currentImage: images[imageIndex], manager: manager, task: task, outputPath: outputPath, model: model, logger: logger)
                }
            }
            
            logger.info("Finished Processing Images")
        }
        
        // process videos
        guard !videos.isEmpty else {
            manager.status("Completed")
            return
        }
        logger.info("Processing Videos")
        
        manager.status("Processing videos")
        
        for currentVideo in videos {
            // Use this to prevent memory leak
            await asyncAutoreleasepool {
                manager.addCurrentItems(currentVideo)
                await processVideo(currentVideo: currentVideo, manager: manager, task: task, outputPath: outputPath, model: model, logger: logger)
                manager.removeFromCurrentItems(currentVideo)
            }
        }
        
    }
    
}


// MARK: - Supporting Functions

@Sendable internal func generateFileName(from index: Int) -> String {
    var segmentSequence = String(index)
    while segmentSequence.count <= 5 { segmentSequence.insert("0", at: segmentSequence.startIndex) }
    return segmentSequence
}

@Sendable internal func distributeAssignments(iterations: Int, action: @escaping (Int) -> Void) {
    let odd = iterations % 2 == 1
    let task1 = DispatchQueue(label: "task 1")
    let task2 = DispatchQueue(label: "task 2")
    
    for i in 0..<iterations/2 {
        task1.async {
            action(i*2)
        }
        task2.async {
            action(i*2+1)
        }
        
        task1.sync { }
        task2.sync { }
    }
    
    if odd {
        action(iterations - 1)
    }
}
