//
//  StatusObserver.swift
//  waifuExtension
//
//  Created by Vaida on 7/13/22.
//

import Foundation
import SwiftUI

@MainActor
class StatusObserver: ObservableObject {
    
    @Published var processedItemsCounter: Int = 0
    @Published var pastTimeTaken: Double = 0 // up to 1s
    
    var isFinished: Bool = false {
        didSet {
            self.progress = 1
            self.status = updateProgress()
        }
    }
    @Published var progress: Double = 0
    
    @Published var status: LocalizedStringKey = "Loading..."
    @Published var statusProgress: (progress: Int, total: Int)? = nil
    
    @Published var currentItems: [WorkItem] = [] {
        didSet {
            self.status = updateProgress()
        }
    }
    @Published var coordinator: ModelCoordinator?
    
    private func updateProgress() -> LocalizedStringKey {
        guard let coordinator else { return "Loading.." }
        
        if !self.isFinished {
            guard !currentItems.isEmpty else { return "Loading..." }
            if coordinator.enableConcurrent && currentItems.count != 1 {
                let folder = currentItems.map({ $0.relativePath?.components(separatedBy: "/").last })
                if folder.allEqual(), let firstElement = folder.first, let firstElement {
                    return "Processing \(currentItems.count) images in \(firstElement)"
                }
                return "Processing \(currentItems.count) images"
            }
            let firstItem = currentItems.first!
            return "Processing \(firstItem.fileName)"
        } else {
            return "Finished"
        }
    }
    
    func reset() {
        self.processedItemsCounter = 0
        self.pastTimeTaken = 0
        self.isFinished = false
        self.progress = 0
        self.status = "Loading..."
        self.statusProgress = nil
        self.currentItems = []
        self.coordinator = nil
    }
    
}
