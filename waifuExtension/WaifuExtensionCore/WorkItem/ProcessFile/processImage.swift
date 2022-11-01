//
//  work.processImage.swift
//  waifuExtension
//
//  Created by Vaida on 7/19/22.
//

import Foundation
import Support
import CoreMedia
import os

@Sendable func processImage(currentImage: WorkItem, manager: ProgressManager, task: ShellManagers, outputPath: FinderItem, model: ModelCoordinator, logger: Logger) {
    
    manager.addCurrentItems(currentImage)
    let destinationDataProvider = DestinationDataProvider.main
    
    let outputFileName: String
    if let name = currentImage.finderItem.relativePath {
        outputFileName = name[..<name.lastIndex(of: ".")!] + destinationDataProvider.imageFormat.extensionName(for: currentImage.finderItem, isCaffe: model.isCaffe)
    } else {
        outputFileName = currentImage.finderItem.fileName + destinationDataProvider.imageFormat.extensionName(for: currentImage.finderItem, isCaffe: model.isCaffe)
    }
    
    let finderItemAtImageOutputPath = outputPath.with(subPath: outputFileName)
    finderItemAtImageOutputPath.generateDirectory()
    
    if model.isCaffe {
        guard let image = currentImage.finderItem.image?.cgImage else { print("no image"); return }
        guard let output = processFrameWaifu2x(source: image, model: model, progress: manager.progress) else { return }
        
        try! output.write(to: finderItemAtImageOutputPath, option: destinationDataProvider.imageFormat.nativeImageFormat(for: currentImage.finderItem))
    } else {
        processFrameInstalled(source: &currentImage.finderItem, output: finderItemAtImageOutputPath, model: model, progress: manager.progress, task: task)
    }
    
    manager.removeFromCurrentItems(currentImage)
}
