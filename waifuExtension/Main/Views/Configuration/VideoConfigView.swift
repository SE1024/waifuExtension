//
//  VideoConfigView.swift
//  waifuExtension
//
//  Created by Vaida on 11/2/22.
//

import SwiftUI

struct VideoConfigView: View {
    @EnvironmentObject private var model: ModelCoordinator
    
    @State private var selectedSegmentation: CGFloat = 3
    
    @ViewBuilder private var dividingSpacer: some View {
        Divider()
        Spacer()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $model.enableMemoryOnly) {
                Text("Memory Only")
            }
            Text("Waifu2x only.\nStore intermediate frames in memory instead of on disk.")
                .font(.callout)
                .foregroundColor(.secondary)
            
            dividingSpacer
            
            Group {
                Toggle(isOn: $model.enableCompressIntermediateFrames) {
                    Text("Compress Intermediate Frames")
                }
                Text("Waifu2x only.\nEncode intermediate frames in heic to reduce memory usage, may effect performance.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .disabled(!model.enableMemoryOnly)
            
            dividingSpacer
            
            Text("Video segmentation: \(model.videoSegmentFrames.description) frames")
            
            Slider(value: $selectedSegmentation, in: 0...4, step: 1) {
                
            }
            .onChange(of: selectedSegmentation) { _ in
                model.videoSegmentFrames = [100, 500, 1000, 2000, 5000][Int(selectedSegmentation)]
            }
            Text("During processing, videos will be split into smaller ones, choose how long you want each smaller video be, in frames.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
