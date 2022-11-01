//
//  ProcessFile.swift
//  waifuExtension
//
//  Created by Vaida on 3/15/22.
//

import Foundation
import AVFoundation
import AppKit
import os
import Support
import SwiftUI


func inferenceProgress(_ text: String) -> Double? {
    if let index = text.lastIndex(of: "%") {
        guard let value = Double(text[text.startIndex..<index]) else { return nil }
        return value / 100
    } else {
        //        guard let lastIndex = text.lastIndex(where:  { $0.isNumber }) else { return nil }
        //        var startIndex = lastIndex
        //
        //        var lastCharacter = text[text.index(before: startIndex)]
        //        while Int(String(lastCharacter)) != nil || lastCharacter == "." {
        //            text.formIndex(before: &startIndex)
        //            guard startIndex != text.startIndex else { break }
        //            lastCharacter = text[text.index(before: startIndex)]
        //        }
        //
        //        guard startIndex < lastIndex else { return nil }
        //        return Double(text[text.index(after: startIndex)..<lastIndex])
        return nil
    }
}

public class ProgressManager: ObservableObject {
    
    @Published var progress = Progress(totalUnitCount: 1)
    
    public var status: (_ status: LocalizedStringKey) -> Void = { _ in }
    public var onStatusProgressChanged: (_ progress: Int?, _ total: Int?) -> Void = { _, _ in }
    public var addCurrentItems: (_ item: WorkItem) -> Void = { _ in }
    public var removeFromCurrentItems: (_ item: WorkItem) -> Void = { _ in }
    
    public init() { }
}


//TODO: recalculate estimate size

extension Array where Element == WorkItem {
    
    func contains(_ finderItem: FinderItem) -> Bool {
        return self.contains(WorkItem(at: finderItem, type: .image))
    }
    
}


extension FinderItem {
    
    static func trimVideo(sourceURL: URL, outputURL: URL, startTime: Double, endTime: Double) async {
        let asset = AVAsset(url: sourceURL as URL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { return }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4v
        
        let startTime = CMTime(startTime)
        let endTime = CMTime(endTime)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        
        if FinderItem(at: outputURL).isExistence {
            FinderItem(at: outputURL).removeFile()
        }
        
        exportSession.timeRange = timeRange
        print("awaiting export")
        await exportSession.export()
        print("exported")
    }
    
    /// merge videos from videos
    ///
    /// from [stackoverflow](https://stackoverflow.com/questions/38972829/swift-merge-avasset-videos-array)
    static func mergeVideos(from arrayVideos: [FinderItem], toPath: String, tempFolder: String, frameRate: Float) async {
        print(">>>>> \(frameRate)")
        
        let logger = Logger()
        logger.info("Merging videos...")
        
        func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
            AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        }
        
        func mergingVideos(from arrayVideos: [FinderItem], toPath: String) async {
            var atTimeM = CMTime.zero
            var layerInstructionsArray = [AVVideoCompositionLayerInstruction]()
            var completeTrackDuration = CMTime.zero
            var videoSize: CGSize = CGSize(width: 0.0, height: 0.0)
            
            let mixComposition = AVMutableComposition()
            var index = 0
            while index < arrayVideos.count {
                autoreleasepool {
                    guard let videoAsset = AVAsset(at: arrayVideos[index]) else { return }
                    
                    let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
                    do {
                        try videoTrack!.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration),
                                                        of: videoAsset.tracks(withMediaType: AVMediaType.video).first!,
                                                        at: atTimeM)
                        videoSize = (videoTrack!.naturalSize)
                        
                    } catch let error as NSError {
                        logger.error("error: \(error.localizedDescription)")
                    }
                    
                    let realDuration = { ()-> CMTime in
                        let framesCount = Double(videoAsset.frameRate!) * videoAsset.duration.seconds
                        return CMTime(framesCount / Double(frameRate))
                    }()
                    print(realDuration.seconds)
                    
                    videoTrack!.scaleTimeRange(CMTimeRangeMake(start: atTimeM, duration: videoAsset.duration), toDuration: realDuration)
                    
                    atTimeM = CMTimeAdd(atTimeM, realDuration)
                    print(atTimeM.seconds.expressedAsTime(), realDuration.seconds.expressedAsTime())
                    completeTrackDuration = CMTimeAdd(completeTrackDuration, realDuration)
                    
                    let firstInstruction = videoCompositionInstruction(videoTrack!, asset: videoAsset)
                    firstInstruction.setOpacity(0.0, at: atTimeM) // hide the video after its duration.
                    
                    layerInstructionsArray.append(firstInstruction)
                    
                    index += 1
                }
            }
            
            logger.info("add videos finished")
            
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.layerInstructions = layerInstructionsArray
            mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: completeTrackDuration)
            
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = [mainInstruction]
            let frameRate = Fraction(frameRate)
            mainComposition.frameDuration = CMTimeMake(value: Int64(frameRate.denominator), timescale: Int32(frameRate.numerator))
            mainComposition.renderSize = videoSize
            print(">><< \(1 / mainComposition.frameDuration.seconds)")
            
            let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetPassthrough)!
            exporter.outputURL = URL(fileURLWithPath: toPath)
            exporter.outputFileType = AVFileType.mov
            exporter.shouldOptimizeForNetworkUse = false
            exporter.videoComposition = mainComposition
            await exporter.export()
            
            if let error = exporter.error {
                logger.error("\(error.localizedDescription)")
            }
        }
        
        FinderItem(at: tempFolder).generateDirectory(isFolder: true)
        
        let threshold: Double = 50
        
        if arrayVideos.count >= Int(threshold) {
            var index = 0
            var finishedCounter = 0
            while index < Int((Double(arrayVideos.count) / threshold).rounded(.up)) {
                var sequence = String(index)
                while sequence.count < 6 { sequence.insert("0", at: sequence.startIndex) }
                let upperBound = ((index + 1) * Int(threshold)) > arrayVideos.count ? arrayVideos.count : ((index + 1) * Int(threshold))
                
                await mergingVideos(from: Array(arrayVideos[(index * Int(threshold))..<upperBound]), toPath: tempFolder + "/" + sequence + ".m4v")
                finishedCounter += 1
                guard finishedCounter == Int((Double(arrayVideos.count) / threshold).rounded(.up)) else { return }
                await mergingVideos(from: FinderItem(at: tempFolder).children(range: .contentsOfDirectory)!, toPath: toPath)
                
                index += 1
            }
        } else {
            await mergingVideos(from: arrayVideos, toPath: toPath)
        }
    }
}
