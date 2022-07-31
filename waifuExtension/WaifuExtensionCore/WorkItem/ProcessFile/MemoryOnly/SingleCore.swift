//
//  memoryOnlySingle.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import os
import Support
import AVKit

/// Process video in memory only mode, single core only. This method is memory-efficient, but slowest.
func processVideoMemoryOnlySingleCore(currentVideo: WorkItem, destination: FinderItem, manager: ProgressManager, model: ModelCoordinator) async {
    manager.status("Converting frames to video for \(currentVideo.fileName)")
    
    await asyncAutoreleasepool {
        let logger = Logger()
        
        let source = currentVideo.finderItem
        
        let sourceAsset = source.avAsset!
        let videoFPS = sourceAsset.frameRate!
        var videoSize: CGSize! = nil
        var colorSpace: CGColorSpace?
        autoreleasepool {
            let firstFrame = sourceAsset.firstFrame!
            videoSize = firstFrame.size.scaled(by: Double(model.caffe.scale))
            colorSpace = firstFrame.colorSpace
        }
        
        logger.info("Generate video from \(source) from images at fps of \(videoFPS)")
        
        // Create AVAssetWriter to write video
        if destination.isExistence {
            destination.removeFile()
        } else {
            destination.generateDirectory()
        }
        
        let assetWriter: AVAssetWriter
        
        // Return new asset writer or nil
        do {
            // Create asset writer
            assetWriter = try AVAssetWriter(outputURL: destination.url, fileType: .m4v)
            
            // Define settings for video input
            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecType.hevc as AnyObject,
                AVVideoWidthKey  : videoSize.width as AnyObject,
                AVVideoHeightKey : videoSize.height as AnyObject,
            ]
            
            // Add video input to writer
            let assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            assetWriter.add(assetWriterVideoInput)
            
            // Return writer
            logger.info("Created asset writer for \(videoSize.width)x\(videoSize.height) video")
        } catch {
            logger.error("Error creating asset writer: \(error.localizedDescription)")
            return
        }
        
        // If here, AVAssetWriter exists so create AVAssetWriterInputPixelBufferAdaptor
        let writerInput = assetWriter.inputs.filter{ $0.mediaType == .video }.first!
        let sourceBufferAttributes : [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB) as AnyObject,
            kCVPixelBufferWidthKey as String : videoSize.width as AnyObject,
            kCVPixelBufferHeightKey as String : videoSize.height as AnyObject,
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        // Start writing session
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
        if pixelBufferAdaptor.pixelBufferPool == nil {
            logger.error("Error converting images to video: pixelBufferPool nil after starting session")
            return
        }
        
        let mediaQueue = DispatchQueue.global()
        
        // -- Set video parameters
        let frameRate = Fraction(videoFPS)
        let frameDuration = CMTimeMake(value: Int64(frameRate.denominator), timescale: Int32(frameRate.numerator))
        
        // prepare for generating frames
        let vidLength: CMTime = sourceAsset.duration
        let seconds = vidLength.seconds
        
        var requiredFramesCount = Int(seconds * Double(frameRate))
        if requiredFramesCount == 0 { requiredFramesCount = 1 }
        
        let step = Int(vidLength.value / Int64(requiredFramesCount))
        let requestedTimes = [CMTime](iterations: requiredFramesCount) { index in
            CMTimeMake(value: Int64(step * index), timescale: vidLength.timescale)
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: sourceAsset)
        imageGenerator.requestedTimeToleranceAfter = CMTime.zero
        imageGenerator.requestedTimeToleranceBefore = CMTime.zero
        
        let waifu2x = Waifu2x()
        
        var frameIndex = 0
        // -- Add images to video
        await withCheckedContinuation{ continuation in
            writerInput.requestMediaDataWhenReady(on: mediaQueue) {
                // Append unadded images to video but only while input ready
                while writerInput.isReadyForMoreMediaData && frameIndex < requiredFramesCount - 1 {
                    let lastFrameTime = CMTime(value: Int64(frameIndex) * Int64(frameRate.denominator), timescale: Int32(frameRate.numerator))
                    let presentationTime = frameIndex == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                    
                    autoreleasepool {
                        if  let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                            let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity:1)
                            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                                kCFAllocatorDefault,
                                pixelBufferPool,
                                pixelBufferPointer
                            )
                            
                            if let pixelBuffer = pixelBufferPointer.pointee , status == 0 {
                                CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                                
                                let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
                                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                                
                                // Create CGBitmapContext
                                let context = CGContext(
                                    data: pixelData,
                                    width: Int(videoSize.width),
                                    height: Int(videoSize.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                    space: colorSpace ?? rgbColorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                )!
                                
                                // Draw image into context
                                guard let cgImage = try? imageGenerator.copyCGImage(at: requestedTimes[frameIndex], actualTime: nil) else { return }
                                guard var cgImage = waifu2x.run(cgImage, model: model) else { return }
                                manager.videos[currentVideo]!.updateEnlarge()
                                
                                if let colorSpace, colorSpace != cgImage.colorSpace {
                                    cgImage = cgImage.copy(colorSpace: colorSpace)!
                                }
                                
                                context.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: videoSize.width, height: videoSize.height))
                                
                                CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                                
                                guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                                    logger.error("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                                    return
                                }
                                pixelBufferPointer.deinitialize(count: 1)
                            } else {
                                logger.error("Error: Failed to allocate pixel buffer from pool")
                            }
                            
                            pixelBufferPointer.deallocate()
                        }
                    }
                    
                    frameIndex += 1
                }
                
                // No more images to add? End video.
                if frameIndex >= requiredFramesCount - 1 {
                    writerInput.markAsFinished()
                    continuation.resume()
                }
            }
        }
        
        mediaQueue.sync { logger.info("finished adding frames") }
        
        await assetWriter.finishWriting()
        
        if (assetWriter.error != nil) {
            logger.error("Error converting images to video: \(assetWriter.error.debugDescription)")
        } else {
            logger.info("Converted images to movie @ \(destination)")
        }
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
