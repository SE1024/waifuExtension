//
//  ConfigurationView.swift
//  waifuExtension
//
//  Created by Vaida on 12/2/21.
//

import SwiftUI
import os
import Support

struct ConfigurationView: View {
    
    @State private var isShowingImportDialog = false
    @State private var alterManager = AlertManager()
    
    @EnvironmentObject private var destination: DestinationDataProvider
    
    private var destinationName: LocalizedStringKey {
        if destination.destinationFolder == .defaultOutputFolder {
            return "Downloads/Waifu Output"
        } else {
            return .init(destination.destinationFolder.relativePath(to: .homeDirectory) ?? destination.destinationFolder.path)
        }
    }
    
    var destinationMenu: some View {
        Menu(destinationName) {
            Button("Downloads/Waifu Output") {
                destination.destinationFolder = .defaultOutputFolder
            }
            
            Divider()
            
            Button("Other...") {
                isShowingImportDialog = true
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            
            Group {
                HStack {
                    Text("Destination")
                    
                    destinationMenu
                }
            }
            .fileImporter(isPresented: $isShowingImportDialog, allowedContentTypes: [.directory]) { result in
                guard let resultItem = FinderItem(at: try? result.get()), resultItem.isDirectory! else {
                    alterManager = AlertManager("Please choose a folder.")
                    return
                }
                destination.destinationFolder = resultItem
            }
            
            Text {
                "The folder where the generated images are stored."
            }
            .font(.callout)
            .foregroundColor(.secondary)
//            .padding(.bottom)
            
            Divider()
                .padding(.bottom)
            
            Form {
                DestinationDataProvideeView(providee: $destination.imageFormat, options: DestinationDataProvider.ImageFormat.allCases)
                DestinationDataProvideeView(providee: $destination.videoContainer, options: DestinationDataProvider.VideoContainer.allCases)
                    .onChange(of: destination.videoContainer) { newValue in
                        if !newValue.codecs.contains(destination.videoCodec) {
                            // not all the options are available.
                            destination.videoCodec = DestinationDataProvider.VideoCodec.default
                        }
                    }
                DestinationDataProvideeView(providee: $destination.videoCodec, options: destination.videoContainer.codecs)
            }
            
            Text {
                "When unavailable, a default format would be used instead."
            }
            .font(.callout)
            .foregroundColor(.secondary)
        }
        .padding()
    }
    
}

struct DestinationDataProvideeView<Providee: DestinationDataProvidee>: View {
    
    @Binding var providee: Providee
    
    let options: [Providee]
    
    var body: some View {
        Group {
            Picker(Providee.label, selection: $providee, options: options)
                .help(providee.prompt)
        }
    }
}

extension FinderItem {
    
    static var defaultOutputFolder: FinderItem {
        .downloadsDirectory.with(subPath: NSLocalizedString("Waifu Output", comment: ""))
    }
    
}
