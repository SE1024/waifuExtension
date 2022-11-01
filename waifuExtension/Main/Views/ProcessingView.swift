//
//  ProcessingView.swift
//  waifuExtension
//
//  Created by Vaida on 5/4/22.
//

import SwiftUI
import Support


struct ProcessingView: View {
    
    @State private var timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()
    @State private var isShowingQuitConfirmation = false
    @State private var task = ShellManagers()
    
    @State private var isShowingTimeRemaining = true
    @State private var estimatedTotalTime = 0.0
    @State private var mainTask = Task(operation: { })
    
    @Binding var isFinished: Bool
    
    @ObservedObject var images: MainModel
    
    @StateObject private var progressManager = ProgressManager()
    @StateObject private var status = StatusObserver()
    
    @EnvironmentObject private var model: ModelCoordinator
    @EnvironmentObject private var destination: DestinationDataProvider
    
    @Environment(\.locale) private var local
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("defaultOutputPath") var outputPath: FinderItem = .defaultOutputFolder
    
    
    private var pendingCount: Int {
        images.items.count - status.processedItemsCounter - status.currentItems.count
    }
    
    var body: some View {
        VStack {
            
            HStack {
                Text(status.status)
                    .lineLimit(1)
                    .font(.title3)
                
                Spacer()
            }
            
            if images.items.count > 1 {
                HStack {
                    if status.processedItemsCounter >= 2 {
                        if pendingCount >= 2 {
                            Text("Processed: \(status.processedItemsCounter.description) items, \(pendingCount.description) items pending")
                        } else if pendingCount == 1 {
                            Text("Processed: \(status.processedItemsCounter.description) items, \(pendingCount.description) item pending")
                        } else {
                            Text("Processed: \(status.processedItemsCounter.description) items")
                        }
                    } else {
                        if pendingCount >= 2 {
                            Text("Processed: \(status.processedItemsCounter.description) item, \(pendingCount.description) items pending")
                        } else if pendingCount == 1 {
                            Text("Processed: \(status.processedItemsCounter.description) item, \(pendingCount.description) item pending")
                        } else {
                            Text("Processed: \(status.processedItemsCounter.description) item")
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 5)
            }
            
            ProgressView(progressManager.progress)
                .help("\(String(format: "%.2f", status.progress * 100))%")
                .padding(.vertical)
            
            HStack {
                if !status.isFinished {
                    Button() {
                        if images.items.contains(where: { $0.type == .video }) {
                            isShowingQuitConfirmation = true
                        } else {
                            self.mainTask.cancel()
                            self.task.terminate()
                            self.progressManager.progress.cancel()
                            dismiss()
                        }
                    } label: {
                        Text("Cancel")
                            .frame(width: 80)
                    }
                    .padding(.trailing)
                }
                
                Spacer()
                
                if status.isFinished {
                    Button("Show in Finder") {
                        outputPath.open()
                        images.reset()
                        dismiss()
                    }
                    .padding(.trailing)
                    
                    Button() {
                        images.reset()
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(width: 80)
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        .task {
            
            progressManager.status = { status in
                Task { @MainActor in
                    self.status.status = status
                }
            }
            
            progressManager.onStatusProgressChanged = { progress,total in
                Task { @MainActor in
                    if let progress, let total, total > 1 {
                        self.status.statusProgress = (progress, total)
                    } else {
                        self.status.statusProgress = nil
                    }
                }
            }
            
            progressManager.addCurrentItems = { item in
                Task { @MainActor in
                    self.status.currentItems.append(item)
                }
            }
            
            progressManager.removeFromCurrentItems = { item in
                Task { @MainActor in
                    self.status.currentItems.removeAll { $0 == item }
                    self.status.processedItemsCounter += 1
                }
            }
            
            if model.isCaffe {
                model.caffe.finalizeModel()
            }
            
            self.mainTask = Task.detached {
                await images.work(model: model, task: task, manager: progressManager, outputPath: outputPath)
                Task { @MainActor in
                    isFinished = true
                    status.isFinished = true
                    
                    timer.upstream.connect().cancel()
                    
                    progressManager.progress.completedUnitCount = progressManager.progress.totalUnitCount
                    progressManager.progress.setUserInfoObject(nil, forKey: .estimatedTimeRemainingKey)
                }
            }
            
        }
        .onReceive(timer) { timer in
            status.pastTimeTaken += 1
            
            if estimatedTotalTime - status.pastTimeTaken >= 0 {
                progressManager.progress.setUserInfoObject(estimatedTotalTime - status.pastTimeTaken, forKey: .estimatedTimeRemainingKey)
            }
        }
        .onChange(of: progressManager.progress.fractionCompleted) { newValue in
            if newValue > 0 {
                estimatedTotalTime = status.pastTimeTaken / newValue
            }
        }
        .confirmationDialog("Quit the app?", isPresented: $isShowingQuitConfirmation) {
            Button("Quit", role: .destructive) {
                task.terminateIfPosible()
                exit(0)
            }
            
            Button("Cancel", role: .cancel) {
                isShowingQuitConfirmation = false
            }
        }
        .onAppear {
            self.status.coordinator = model
        }
    }
}
