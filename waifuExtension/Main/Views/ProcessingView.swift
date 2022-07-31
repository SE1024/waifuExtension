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
    
    @Binding var isFinished: Bool
    
    @ObservedObject var images: MainModel
    
    @StateObject private var progressManager = ProgressManager()
    @StateObject private var status = StatusObserver()
    
    @EnvironmentObject private var model: ModelCoordinator
    @EnvironmentObject private var destination: DestinationDataProvider
    
    @Environment(\.locale) private var local
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("defaultOutputPath") var outputPath: FinderItem = .downloadsDirectory.with(subPath: NSLocalizedString("Waifu Output", comment: ""))
    
    
    private var pendingCount: Int {
        images.items.count - status.processedItemsCounter - status.currentItems.count
    }
    
    var body: some View {
        VStack {
            
            VStack(spacing: 10) {
                Spacer()
                
                DoubleView("Status:", text: status.status)
                    .lineLimit(1)
                
                if let statusProgress = status.statusProgress, !status.isFinished {
                    DoubleView("Progress:", text: "\(statusProgress.progress) / \(statusProgress.total)")
                }
                
                if images.items.count > 1 {
                    HStack {
                        DoubleView("Processed:") {
                            if status.processedItemsCounter >= 2 {
                                if pendingCount >= 2 {
                                    Text("\(status.processedItemsCounter.description) items, \(pendingCount.description) items pending")
                                } else if pendingCount == 1 {
                                    Text("\(status.processedItemsCounter.description) items, \(pendingCount.description) item pending")
                                } else {
                                    Text("\(status.processedItemsCounter.description) items")
                                }
                            } else {
                                if pendingCount >= 2 {
                                    Text("\(status.processedItemsCounter.description) item, \(pendingCount.description) items pending")
                                } else if pendingCount == 1 {
                                    Text("\(status.processedItemsCounter.description) item, \(pendingCount.description) item pending")
                                } else {
                                    Text("\(status.processedItemsCounter.description) item")
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom)
                }
                
                Spacer()
                
                DoubleView("Time Spent:", text: .init(status.pastTimeTaken.expressedAsTime()))
                
                Group {
                    if isShowingTimeRemaining {
                        DoubleView("Time Remaining:") {
                            Text {
                                guard !status.isFinished else { return "Finished" }
                                guard status.progress != 0 else { return "Calculating..." }
                                
                                var value = status.pastTimeTaken / status.progress
                                value -= status.pastTimeTaken
                                
                                guard value > 0 else { return "Calculating..." }
                                
                                return .init(value.expressedAsTime())
                            }
                            Spacer()
                        }
                    } else {
                        DoubleView("ETA:") {
                            Text {
                                guard !status.isFinished else { return "Finished" }
                                guard status.progress != 0 else { return "Calculating..." }
                                
                                var value = status.pastTimeTaken / status.progress
                                value -= status.pastTimeTaken
                                
                                guard value > 0 else { return "Calculating..." }
                                
                                let date = Date().addingTimeInterval(value)
                                
                                let formatter = DateFormatter()
                                if value < 10 * 60 * 60 {
                                    formatter.dateStyle = .none
                                } else {
                                    formatter.dateStyle = .medium
                                }
                                formatter.timeStyle = .medium
                                formatter.locale = self.local
                                
                                return .init(formatter.string(from: date))
                            }
                            Spacer()
                        }
                    }
                }
                .onTapGesture {
                    isShowingTimeRemaining.toggle()
                }
                
                Spacer()
            }
            
            ProgressView(value: {()->Double in
                guard !images.items.isEmpty else { return 1 }
                guard !status.isFinished else { return 1 }
                
                return status.progress <= 1 ? status.progress : 1
            }(), total: 1.0)
            .help("\(String(format: "%.2f", status.progress * 100))%")
            .padding(.bottom)
            
            Spacer()
            
            HStack {
                if !status.isFinished {
                    Button() {
                        isShowingQuitConfirmation = true
                    } label: {
                        Text("Cancel")
                            .frame(width: 80)
                    }
                    .padding(.trailing)
                }
                
                Spacer()
                
                if status.isFinished && !destination.isNoneDestination {
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
            
            progressManager.onProgressChanged = { progress in
                Task { @MainActor in
                    self.status.progress = progress
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
            
            Task.detached {
                await images.work(model: model, task: task, manager: progressManager, outputPath: outputPath)
                Task { @MainActor in
                    isFinished = true
                    status.isFinished = true
                    if destination.isNoneDestination {
                        dismiss()
                    }
                }
            }
            
        }
        .onReceive(timer) { timer in
            status.pastTimeTaken += 1
        }
        .onChange(of: status.isFinished) { newValue in
            if newValue {
                timer.upstream.connect().cancel()
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
