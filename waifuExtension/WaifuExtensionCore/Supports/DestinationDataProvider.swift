//
//  DestinationDataProvider.swift
//  waifuExtension
//
//  Created by Vaida on 7/29/22.
//

import Foundation
import Support
import AVFoundation
import SwiftUI

final class DestinationDataProvider: DataProvider {
    
    typealias Container = _DestinationDataProvider
    
    @Published var container: Container
    
    /// The main ``DataProvider`` to work with.
    static var main = DestinationDataProvider()
    
    /// Load contents from disk, otherwise initialize with the default parameters.
    init() {
        if let container = DestinationDataProvider.decoded() {
            self.container = container
        } else {
            self.container = Container()
            save()
        }
    }
    
    enum ImageFormat: String, DestinationDataProvidee {
        case source, png, tiff, heic, pdf, jpg, webp
        
        private var nativeImageFormat: NativeImage.ImageFormatOption? {
            switch self {
            case .png:
                return .png
            case .tiff:
                return .tiff
            case .heic:
                return .heic
            case .pdf:
                return .pdf
            case .jpg:
                return .jpeg
            default:
                return nil
            }
        }
        
        private var installedModelFormat: String? {
            guard ImageFormat.InstalledModelsFormats.contains(self) else { return nil }
            return self.rawValue
        }
        
        var prompt: LocalizedStringKey {
            switch self {
            case .source:
                return "The source codec would be used, if possible."
            case .jpg, .png:
                return "The \(self.rawValue) format"
            default:
                return "The format of \(self.rawValue), if possible."
            }
        }
        
        private var extensionName: String {
            "." + self.rawValue
        }
        
        static var `default`: ImageFormat {
            .source
        }
        
        static var label: LocalizedStringKey {
            "Image Format"
        }
        
        static let Waifu2xFormats: [ImageFormat] = [.png, .tiff, .heic, .pdf, .jpg]
        static let InstalledModelsFormats: [ImageFormat] = [.png, .jpg, .webp]
        
        init?(contentType: UTType) {
            switch contentType {
            case .png:
                self = .png
            case .tiff:
                self = .tiff
            case .heic:
                self = .heic
            case .heif:
                self = .heic
            case .pdf:
                self = .pdf
            case .jpeg:
                self = .jpg
            case .webP:
                self = .webp
            default:
                return nil
            }
        }
        
        func nativeImageFormat(for item: FinderItem) -> NativeImage.ImageFormatOption {
            getOptimalFormat(for: item)?.nativeImageFormat ?? ImageFormat.png.nativeImageFormat!
        }
        
        func installedModelFormat(for item: FinderItem) -> String {
            getOptimalFormat(for: item)?.installedModelFormat ?? ImageFormat.png.installedModelFormat!
        }
        
        func extensionName(for item: FinderItem, isCaffe: Bool) -> String {
            let optimalFormat = self.getOptimalFormat(for: item)
            if let optimalFormat, isCaffe && ImageFormat.Waifu2xFormats.contains(optimalFormat) {
                return optimalFormat.extensionName
            } else if let optimalFormat, !isCaffe && ImageFormat.InstalledModelsFormats.contains(optimalFormat) {
                return optimalFormat.extensionName
            } else {
                return ImageFormat.png.extensionName
            }
        }
        
        private func getOptimalFormat(for item: FinderItem) -> ImageFormat? {
            switch self {
            case .source:
                guard let contentType = item.contentType else { return nil }
                guard let sourceType = ImageFormat(contentType: contentType) else { return nil }
                return sourceType
            default:
                return self
            }
        }
    }
    
    enum VideoContainer: String, DestinationDataProvidee {
        case m4v, mov, mp4
        
        var avFileType: AVFileType {
            switch self {
            case .m4v:
                return .m4v
            case .mov:
                return .mov
            case .mp4:
                return .mp4
            }
        }
        
        var prompt: LocalizedStringKey {
            switch self {
            case .m4v:
                return "The format for apple devices"
            case .mov:
                return "The quicktime format for apple devices"
            case .mp4:
                return "The most compatible format"
            }
        }
        
        var codecs: [VideoCodec] {
            switch self {
            case .mp4:
                return [.H264, .HEVC]
            case .m4v:
                return [.H264, .HEVC]
            case .mov:
                return VideoCodec.allCases
            }
        }
        
        var extensionName: String {
            "." + self.rawValue
        }
        
        static var `default`: VideoContainer {
            .m4v
        }
        
        static var label: LocalizedStringKey {
            "Video Container"
        }
    }
    
    enum VideoCodec: String, DestinationDataProvidee {
        case H264, HEVC, HEVCWithAlpha, ProRes422, ProRes422LT, ProRes422HQ, ProRes422Proxy, ProRes4444
        
        var avVideoCodecType: AVVideoCodecType {
            switch self {
            case .H264:
                return .h264
            case .HEVC:
                return .hevc
            case .HEVCWithAlpha:
                return .hevcWithAlpha
            case .ProRes422:
                return .proRes422
            case .ProRes422LT:
                return .proRes422LT
            case .ProRes422HQ:
                return .proRes422HQ
            case .ProRes422Proxy:
                return .proRes422Proxy
            case .ProRes4444:
                return .proRes4444
            }
        }
        
        var prompt: LocalizedStringKey {
            switch self {
            case .H264:
                return "The most compatible format"
            case .HEVC:
                return "The H.265 format, a successor for H.264"
            case .HEVCWithAlpha:
                return "The H.265 format, a successor for H.264"
            default:
                return "Please use Apple ProRes only when you are sure about it"
            }
        }
        
        static var `default`: VideoCodec {
            .HEVC
        }
        
        static var label: LocalizedStringKey {
            "Video Codec"
        }
    }
    
}

struct _DestinationDataProvider: Codable, Hashable, Equatable {
    
    var destinationFolder = FinderItem.downloadsDirectory.with(subPath: NSLocalizedString("Waifu Output", comment: ""))
    
    var imageFormat = DestinationDataProvider.ImageFormat.default
    var videoContainer = DestinationDataProvider.VideoContainer.default
    var videoCodec = DestinationDataProvider.VideoCodec.default
    
    var isNoneDestination: Bool {
        destinationFolder == .generatedFolder
    }
    
}

protocol DestinationDataProvidee: RawRepresentable, Equatable, Codable, Hashable, CaseIterable where RawValue == String, AllCases: RandomAccessCollection {
    
    static var `default`: Self { get }
    
    var prompt: LocalizedStringKey { get }
    
    static var label: LocalizedStringKey { get }
}

//TODO: fix file extension
