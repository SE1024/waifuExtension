//
//  processVideo.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import Support
import os
import CoreMedia
import AVFoundation

func processVideo(currentVideo: WorkItem, manager: ProgressManager, task: ShellManagers, outputPath: FinderItem, model: ModelCoordinator, logger: Logger) async {
    
    let increment = Int64(model.isCaffe ? log2(Double(model.scaleLevel)) : 1)
    
    let filePath = currentVideo.finderItem.relativePath ?? (currentVideo.finderItem.fileName + currentVideo.finderItem.extensionName)
    let destinationFinderItem = outputPath.with(subPath: filePath)
    destinationFinderItem.extensionName = DestinationDataProvider.main.videoContainer.extensionName
    print(DestinationDataProvider.main.videoContainer)
    print(">>>", destinationFinderItem)
    
    if model.enableMemoryOnly && model.isCaffe {
        await processVideoMemoryOnlyDistributed(currentVideo: currentVideo, destination: destinationFinderItem, manager: manager, model: model)
        return
    }
    
    outputPath.with(subPath: "tmp/\(filePath)").generateDirectory(isFolder: true)
    
    let asset = AVAsset(at: currentVideo.finderItem)!
    let duration = asset.duration.seconds
    let frameRate = asset.frameRate!
    
    // enter what it used to be splitVideo(duration: Double, filePath: String, currentVideo: WorkItem)
    
    manager.status("Splitting videos for \(currentVideo.fileName)")
    logger.info("Splitting videos for \(currentVideo.fileName)")
    
    outputPath.with(subPath: "tmp/\(filePath)/raw/splitVideo").generateDirectory(isFolder: true)
    
    // enter what it used to be splitVideo(withIndex segmentIndex: Int, duration: Double, filePath: String, currentVideo: WorkItem)
    
    let videoSegmentLength = Double(model.videoSegmentFrames) / Double(frameRate)
    let videoSegmentCount = Int((duration / videoSegmentLength).rounded(.up))
    
    // split into smaller videos
    for segmentIndex in 0..<videoSegmentCount {
        await asyncAutoreleasepool {
            
            var segmentSequence = String(segmentIndex)
            while segmentSequence.count <= 5 { segmentSequence.insert("0", at: segmentSequence.startIndex) }
            
            let segmentItem = outputPath.with(subPath: "tmp/\(filePath)/raw/splitVideo/video \(segmentSequence).m4v")
            segmentItem.generateDirectory()
            guard AVAsset(at: segmentItem) == nil else {
                manager.onStatusProgressChanged(segmentIndex, videoSegmentCount)
                return
            }
            
            await FinderItem.trimVideo(sourceURL: currentVideo.finderItem.url, outputURL: segmentItem.url, startTime: (Double(segmentIndex) * Double(videoSegmentLength)), endTime: {()->Double in
                if Double(segmentIndex) * videoSegmentLength + videoSegmentLength <= duration {
                    return Double(Double(segmentIndex) * videoSegmentLength + videoSegmentLength)
                } else {
                    return Double(duration)
                }
            }())
            
            
            manager.onStatusProgressChanged(segmentIndex, videoSegmentCount)
        }
    }
    
    manager.onStatusProgressChanged(nil, nil)
    logger.info("splitting videos finished")
    
    // enters the completion of split video
    for index in 0..<videoSegmentCount {
        
        // generate images
        await asyncAutoreleasepool {
            
            manager.status("Generating images for \(currentVideo.fileName)")
            logger.info("generating images for \(filePath), \(index) / \(videoSegmentCount)")
            
            manager.onStatusProgressChanged(index, videoSegmentCount)
            
            // generateImagesAndMergeToVideoForSegment
            
            let segmentsFinderItem = outputPath.with(subPath: "tmp/\(filePath)/raw/splitVideo/video \(generateFileName(from: index)).m4v")
            guard let asset = AVAsset(at: segmentsFinderItem) else { return }
            
            let vidLength: CMTime = asset.duration
            let seconds: Double = CMTimeGetSeconds(vidLength)
            
            var requiredFramesCount = Int((seconds * Double(frameRate)).rounded())
            
            if requiredFramesCount == 0 { requiredFramesCount = 1 }
            
            let indexSequence = generateFileName(from: index)
            
            let mergedVideoPath = outputPath.with(subPath: "/tmp/\(filePath)/processed/videos/\(indexSequence).m4v")
            mergedVideoPath.generateDirectory()
            
            guard AVAsset(at: mergedVideoPath) == nil else {
                outputPath.with(subPath: "/tmp/\(filePath)/processed/\(indexSequence)").removeFile()
                manager.progress.completedUnitCount += Int64(requiredFramesCount) * increment
                // completion after all videos are finished.
                return
            }
            
            logger.info("frames to process: \(requiredFramesCount)")
            
            let rawFramesFolder = outputPath.with(subPath: "/tmp/\(filePath)/processed/\(indexSequence)/raw frames")
            rawFramesFolder.generateDirectory(isFolder: true)
            var interpolatedFramesFolder = outputPath.with(subPath: "/tmp/\(filePath)/processed/\(indexSequence)/interpolated frames")
            interpolatedFramesFolder.generateDirectory(isFolder: true)
            let finishedFramesFolder = outputPath.with(subPath: "/tmp/\(filePath)/processed/\(indexSequence)/finished frames")
            finishedFramesFolder.generateDirectory(isFolder: true)
            
            var colorSpace: CGColorSpace? = nil
            
            var framesCounter = 0
            
            // write raw images
            guard let frames = await AVAsset(at: segmentsFinderItem)!.getFrames() else { return }
            framesCounter = frames.count
            
            for index in 0..<framesCounter {
                autoreleasepool {
                    let finderItemAtImageOutputPath = FinderItem(at: rawFramesFolder.path + "/\(generateFileName(from: index)).png")
                    guard !finderItemAtImageOutputPath.isExistence else { return }
                    try! frames[index].write(to: finderItemAtImageOutputPath, option: .png)
                }
            }
            
            // interpolate frames
            if model.enableFrameInterpolation {
                manager.onStatusProgressChanged(nil, nil)
                
                for frameCounter in 0..<framesCounter {
                    autoreleasepool {
                        
                        var sequence = String(frameCounter)
                        while sequence.count < 6 { sequence.insert("0", at: sequence.startIndex) }
                        
                        // Add frames
                        if frameCounter == 0 {
                            FinderItem(at: "\(rawFramesFolder.path)/\(sequence).png").copy(to: FinderItem(at: "\(interpolatedFramesFolder.path)/\(generateFileName(from: 0)).png"))
                            
//                            manager.videos[currentVideo]!.updateInterpolation()
                            
                            return
                        }
                        
                        let previousSequence = generateFileName(from: frameCounter - 1)
                        let processedSequence = generateFileName(from: frameCounter * model.frameInterpolation)
                        let intermediateSequence = generateFileName(from: frameCounter * model.frameInterpolation - model.frameInterpolation / 2)
                        
                        // will not save the previous frame
                        
                        FinderItem(at: "\(rawFramesFolder.path)/\(sequence).png").copy(to: FinderItem(at: "\(interpolatedFramesFolder.path)/\(processedSequence).png"))
                        
                        if FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence).png").image == nil {
                            let item1 = FinderItem(at: "\(rawFramesFolder.path)/\(previousSequence).png")
                            let item2 = FinderItem(at: "\(rawFramesFolder.path)/\(sequence).png")
                            let output = FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence).png")
                            
                            if item1.image?.tiffRepresentation == item2.image?.tiffRepresentation {
                                item1.copy(to: output)
                            } else {
                                let newTask = task.addManager()
                                model.container.runFrameModel(input1: item1, input2: item2, outputItem: output, task: newTask)
                                newTask.wait()
                            }
                        }
                        
                        guard model.frameInterpolation == 4 else {
//                            manager.videos[currentVideo]!.updateInterpolation()
                            return
                        }
                        
                        let intermediateSequence1 = generateFileName(from: frameCounter * model.frameInterpolation - model.frameInterpolation / 2 - 1)
                        let intermediateSequence3 = generateFileName(from: frameCounter * model.frameInterpolation - model.frameInterpolation / 2 + 1)
                        
                        guard (FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence1).png").image == nil || FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence3).png").image == nil) else {
                            
//                            manager.videos[currentVideo]!.updateInterpolation()
                            return
                        }
                        
                        let item1 = FinderItem(at: "\(rawFramesFolder.path)/\(previousSequence).png")
                        let item2 = FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence).png")
                        let output = FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence1).png")
                        
                        if item1.image?.tiffRepresentation == item2.image?.tiffRepresentation {
                            item1.copy(to: output)
                        } else {
                            let newTask = task.addManager()
                            model.container.runFrameModel(input1: item1, input2: item2, outputItem: output, task: newTask)
                            newTask.wait()
                        }
                        
                        let item3 = FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence).png")
                        let item4 = FinderItem(at: "\(interpolatedFramesFolder.path)/\(processedSequence).png")
                        let output2 = FinderItem(at: "\(interpolatedFramesFolder.path)/\(intermediateSequence3).png")
                        
                        if item3.image?.tiffRepresentation == item4.image?.tiffRepresentation {
                            item3.copy(to: output2)
                        } else {
                            let newTask = task.addManager()
                            model.container.runFrameModel(input1: item3, input2: item4, outputItem: output2, task: newTask)
                            newTask.wait()
                        }
                        
//                        manager.videos[currentVideo]!.updateInterpolation()
                        
                    }
                    
                }
            } else {
                interpolatedFramesFolder = rawFramesFolder
            }
            
            framesCounter = interpolatedFramesFolder.children(range: .contentsOfDirectory)?.filter{ $0.image != nil }.count ?? framesCounter
            
            // now process whatever interpolatedFramesFolder refers to
            
            if model.isCaffe {
                let folder = interpolatedFramesFolder
                
                if colorSpace == nil {
                    let path = folder.path + "/\(generateFileName(from: 0)).png"
                    let imageItem = FinderItem(at: path)
                    
                    colorSpace = imageItem.image!.cgImage?.colorSpace
                }
                
                DispatchQueue.concurrentPerform(iterations: framesCounter) { index in
                    
                    let path = folder.path + "/\(generateFileName(from: index)).png"
                    let imageItem = FinderItem(at: path)
                    
                    let finderItemAtImageOutputPath = FinderItem(at: finishedFramesFolder.path + "/\(generateFileName(from: index)).png")
                    
                    guard finderItemAtImageOutputPath.image == nil else {
                        manager.progress.completedUnitCount += increment
                        return
                    }
                    
                    autoreleasepool {
                        if index >= 1 && imageItem.image?.tiffRepresentation == FinderItem(at: folder.path + "/\(generateFileName(from: index - 1)).png").image?.tiffRepresentation {
                            FinderItem(at: finishedFramesFolder.path + "/\(generateFileName(from: index - 1)).png").copy(to: finderItemAtImageOutputPath)
                            manager.progress.completedUnitCount += increment
                            return
                        }
                        
                        guard let image = imageItem.image?.cgImage else { print("no image"); return }
                        let output = processFrameWaifu2x(source: image, model: model, progress: manager.progress)
                        
                        try! NativeImage(cgImage: output)?.write(to: finderItemAtImageOutputPath, option: .png)
                    }
                }
                
                
            } else {
                
                for index in 0..<framesCounter {
                    let path = interpolatedFramesFolder.path + "/\(generateFileName(from: index)).png"
                    var imageItem = FinderItem(at: path)
                    
                    let finderItemAtImageOutputPath = FinderItem(at: finishedFramesFolder.path + "/\(generateFileName(from: index)).png")
                    
                    guard finderItemAtImageOutputPath.image == nil else {
                        manager.progress.completedUnitCount += 1
                        return
                    }
                    
                    /// Here it is safe to pass a mutable path, as no preprocess is needed.
                    processFrameInstalled(source: &imageItem, output: finderItemAtImageOutputPath, model: model, progress: manager.progress, task: task)
                }
            }
            
            outputPath.with(subPath: "tmp/\(filePath)/raw/splitVideo/video \(indexSequence).m4v").removeFile()
            
            let enlargedFrames: [FinderItem] = finishedFramesFolder.children(range: .contentsOfDirectory)!
            print(finishedFramesFolder)
            
            logger.info("Start to convert image sequence to video at \(mergedVideoPath)")
            
            let destinationDataProvider = DestinationDataProvider()
            try! await AVAsset.convert(images: enlargedFrames, toVideo: mergedVideoPath, videoFPS: frameRate * Float(model.frameInterpolation), colorSpace: colorSpace, container: destinationDataProvider.videoContainer.avFileType, codec: destinationDataProvider.videoCodec.avVideoCodecType) { item in
                item.image!.cgImage!
            }
            
            logger.info("Convert image sequence to video at \(mergedVideoPath): finished")
            outputPath.with(subPath: "/tmp/\(filePath)/processed/\(indexSequence)").removeFile()
            
            
            // delete raw images
            rawFramesFolder.removeFile()
            interpolatedFramesFolder.removeFile()
            
        }
        
        // generateImagesAndMergeToVideoForSegment finished
        
        let outputPatH = outputPath.with(subPath: "/tmp/\(filePath)/\(currentVideo.finderItem.fileName).m4v")
        
        // status: merge videos
        manager.status("Merging video for \(currentVideo.fileName)")
        logger.info("merging video for \(filePath)")
        
        await FinderItem.mergeVideos(from: outputPath.with(subPath: "/tmp/\(filePath)/processed/videos").children(range: .contentsOfDirectory)!, toPath: outputPatH.path, tempFolder: outputPath.with(subPath: "tmp/\(filePath)/merging video").path, frameRate: frameRate * Float(model.frameInterpolation))
        
        manager.status("Merging video with audio for \(currentVideo.fileName)")
        logger.info("merging video and audio for \(filePath)")
        manager.onStatusProgressChanged(nil, nil)
        
        if asset.audioTrack != nil {
            try! await AVAsset.merge(video: outputPatH, withAudio: currentVideo.finderItem)
        }
        
        manager.status("\(currentVideo.fileName) Completed")
        logger.info("Merging video and audio finished for \(currentVideo.fileName)")
        
        if destinationFinderItem.isExistence { destinationFinderItem.removeFile() }
        outputPatH.copy(to: destinationFinderItem)
        outputPath.with(subPath: "tmp").removeFile()
        
        logger.info(">>>>> results: ")
        logger.info("Video \(currentVideo.finderItem.fileName) done")
    }
}
