//
//  ContentView.swift
//  waifuExtension
//
//  Created by Vaida on 11/22/21.
//

import SwiftUI
import Support
import AVFoundation

struct ContentView: View {
    
    @State private var isSheetShown: Bool = false
    @State private var isProcessing: Bool = false
    @State private var isFinished = false
    @State private var isShowingExportDialog = false
    @State private var gridNumber = 1.6
    
    @StateObject private var images = MainModel()
    
    @EnvironmentObject private var destination: DestinationDataProvider
    @EnvironmentObject private var modelDataProvider: ModelDataProvider
    
    @AppStorage("ContentView.aspectRatio") private var aspectRatio = true
    @AppStorage("defaultOutputPath") private var outputPath: FinderItem = .defaultOutputFolder
    
    var body: some View {
        VStack {
            DropView(isShowingPrompt: images.items.isEmpty) { item in
                item.image != nil || AVAsset(at: item)?.videoTrack != nil
            } handler: { items in
                let newItems = items.compactMap { item in
                    if item.image != nil {
                        return WorkItem(at: item, type: .image)
                    } else if AVAsset(at: item)?.videoTrack != nil {
                        return WorkItem(at: item, type: .video)
                    } else {
                        return nil
                    }
                }
                images.items.formUnion(newItems)
            } content: {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: Int(8 / gridNumber))) {
                            ForEach(images.items) { item in
                                GridItemView(item: item, geometry: geometry, gridNumber: gridNumber, images: images)
                            }
                        }
                        .padding()
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .sheet(isPresented: $isSheetShown) {
            SpecificationsView(containVideo: self.images.items.contains{ $0.type == .video }, isProcessing: $isProcessing, images: images)
                .frame(width: 600)
        }
        .sheet(isPresented: $isProcessing) {
            ProcessingView(isFinished: $isFinished, images: images)
                .padding()
                .frame(width: 600, height: images.items.count > 1 ? 200 : 170)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Remove All") {
                    isFinished = false
                    images.reset()
                }
                .disabled(images.items.isEmpty)
                .help("Remove all files.")
            }

            ToolbarItemGroup {
                Button {
                    withAnimation {
                        aspectRatio.toggle()
                    }
                } label: {
                    Image(systemName: aspectRatio ? "rectangle.arrowtriangle.2.outward" : "rectangle.arrowtriangle.2.inward")
                }
                .help("Show thumbnails as square or in full aspect ratio.")
                
                Slider(value: $gridNumber, in: 1...8) {
                    Text("Grid Item Count.")
                } minimumValueLabel: {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12)
                } maximumValueLabel: {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                }
                .onTapGesture {
                    withAnimation {
                        gridNumber = 1.6
                    }
                }
                .frame(width: 150)
                .help("Set the size of each thumbnail.")

                Button("Add Item") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK {
                        Task {
                            await self.images.append(from: panel.urls.map{ FinderItem(at: $0) })
                        }
                    }
                }
                .help("Add another item.")
                
                Button("Done") {
                    isSheetShown = true
                }
                .disabled(images.items.isEmpty || isSheetShown)
                .help("Begin processing.")
            }
        }
        .onChange(of: images.items) { newValue in
            if newValue.isEmpty {
                isFinished = false
            }
        }
        .fileExporter(isPresented: $isShowingExportDialog, document: WorkItemDocument(container: images.items), contentType: .folder, defaultFilename: "WaifuExtension Output") { _ in
            images.reset()
        }
    }
}
