//
//  processFrame.swift
//  waifuExtension
//
//  Created by Vaida on 8/11/22.
//

import Foundation
import CoreGraphics
import Support

/// Be really careful with `source` and `return value`. As force cast will be performed.
@Sendable func processFrameWaifu2x(source: CGImage, model: ModelCoordinator, progress: Progress) -> CGImage? {
    var output: CGImage? = source
    let waifu2x = Waifu2x()
    
    let upperBound = min(Int(log2(Double(model.scaleLevel))), 1)
    
    for _ in 1...upperBound {
        guard !Task.isCancelled else { return nil }
        progress.becomeCurrent(withPendingUnitCount: 1)
        guard output != nil else { return nil }
        output = waifu2x.run(output!, model: model)
        progress.resignCurrent()
    }
    
    return output
}

@Sendable func processFrameInstalled(source: inout FinderItem, output: FinderItem, model: ModelCoordinator, progress: Progress, task: ShellManagers) {
    progress.becomeCurrent(withPendingUnitCount: 1)
    let currentProgress = Progress(totalUnitCount: 100)
    
    let newTask = task.addManager()
    model.container.runImageModel(input: &source, outputItem: output, task: newTask)
    newTask.onOutputChanged { newLine in
        guard let value = inferenceProgress(newLine) else { return }
        guard value <= 1 && value >= 0 else { return }
        currentProgress.completedUnitCount = Int64(Double(currentProgress.totalUnitCount) * value)
    }
    newTask.wait()
    
    currentProgress.completedUnitCount = currentProgress.totalUnitCount
    progress.resignCurrent()
}
