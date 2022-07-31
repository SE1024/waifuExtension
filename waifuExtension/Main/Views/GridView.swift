//
//  GridView.swift
//  waifuExtension
//
//  Created by Vaida on 5/4/22.
//

import SwiftUI
import Support

struct GridItemView: View {
    
    let item: WorkItem
    let geometry: GeometryProxy
    let gridNumber: Double
    
    @ObservedObject var images: MainModel
    
    @AppStorage("ContentView.aspectRatio") private var aspectRatio = true
    
    var body: some View {
        VStack(alignment: .center) {
            
            AsyncView {
                item.originalFile.image ?? NativeImage(cgImage: item.originalFile.avAsset?.firstFrame) ?? NSImage(named: "placeholder")!
            } content: { result in
                Image(nsImage: result)
                    .resizable()
                    .aspectRatio(contentMode: aspectRatio ? .fit : .fill)
                    .cornerRadius(5)
                    .frame(width: geometry.size.width * gridNumber / 8.5)
                    .cornerRadius(5)
                    .padding()
                    .help {
                        if let size = result.pixelSize {
                            var value = """
                            name: \(item.finderItem.fileName)
                            path: \(item.finderItem.path)
                            size: \(size.width) × \(size.height)
                            """
                            if item.type == .video {
                                value += "\nlength: \(item.originalFile.avAsset?.duration.seconds.expressedAsTime() ?? "0s")"
                            }
                            return .init(value)
                        } else {
                            return """
                            Loading...
                            name: \(item.finderItem.fileName)
                            path: \(item.finderItem.path)
                            (If this continuous, please transcode your video into HEVC and retry)
                            """
                        }
                    }
            } placeHolderValue: {
                NSImage(named: "placeholder")!
            }
            
            Text(item.finderItem.relativePathWithoutExtension ?? item.finderItem.fileName)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .padding([.leading, .bottom, .trailing])
        }
        .contextMenu {
            Button("Open") {
                item.finderItem.open()
            }
            
            Button("Show in Finder") {
                item.finderItem.revealInFinder()
            }
            
            Divider()
            
            Button("Remove") {
                withAnimation {
                    images.items.removeAll { $0 == item }
                }
            }
        }
        .onTapGesture(count: 2) {
            item.finderItem.open()
        }
    }
}
