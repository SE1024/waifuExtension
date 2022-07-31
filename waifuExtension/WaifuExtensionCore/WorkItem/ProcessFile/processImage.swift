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
        var output: CGImage? = nil
        let waifu2x = Waifu2x()
        
        if model.scaleLevel == 4 {
            waifu2x.didFinishedOneBlock = { total in
                manager.images[currentImage]!.progress += 1 / Double(total) / 2
            }
            output = waifu2x.run(image, model: model)
            output = waifu2x.run(output!, model: model)
        } else if model.scaleLevel == 8 {
            waifu2x.didFinishedOneBlock = { total in
                manager.images[currentImage]!.progress += 1 / Double(total) / 3
            }
            output = waifu2x.run(image, model: model)
            output = waifu2x.run(output!, model: model)
            output = waifu2x.run(output!, model: model)
        } else {
            waifu2x.didFinishedOneBlock = { total in
                manager.images[currentImage]!.progress += 1 / Double(total)
            }
            output = waifu2x.run(image, model: model)
        }
        try! output!.write(to: finderItemAtImageOutputPath, option: destinationDataProvider.imageFormat.nativeImageFormat(for: currentImage.finderItem))
    } else {
        let newTask = task.addManager()
        model.container.runImageModel(input: currentImage.finderItem, outputItem: finderItemAtImageOutputPath, task: newTask)
        newTask.onOutputChanged { newLine in
            guard let value = inferenceProgress(newLine) else { return }
            guard value <= 1 && value >= 0 else { return }
            manager.images[currentImage]?.progress = value
        }
        newTask.wait()
    }
    
    manager.images[currentImage]?.progress = 1
    manager.removeFromCurrentItems(currentImage)
    
    // replace item
    if destinationDataProvider.isNoneDestination {
        currentImage.path = finderItemAtImageOutputPath.path
    }
}
