//
//  Models.swift
//  waifuExtension
//
//  Created by Vaida on 3/15/22.
//

import Foundation
import AppKit
import Support
import UniformTypeIdentifiers
import os
import Metal

public protocol InstalledModel: Codable, Hashable {
    
    static var name: String { get }
    static var rawName: String { get }
    static var source: URL { get }
    
    static var rootPath: String { get }
    
}

public extension InstalledModel {
    
    /// The finderItem which determines where the program is.
    static var programFolderItem: FinderItem {
        FinderItem(at: "\(rootPath)")
    }
    
    static var programItem: FinderItem {
        return FinderItem(at: "\(rootPath)/\(self.rawName)")
    }
    
    /// Changes the file name to something the exe can read
    static func preProsess(input: inout FinderItem) {
        var isReadable: Bool {
            guard input.isFile! else { return true }
            
            if let type = input.contentType, [.png, .jpeg, .tiff].contains(type) {
                return true
            } else if [".png", ".jpg", ".jpeg", ".tiff"].contains(input.extensionName) {
                return true
            } else {
                return false
            }
        }
        
        if !isReadable {
            let destination = FinderItem.temporaryDirectory.with(subPath: "\(input.fileName).png")
            try! input.image?.data(using: .png)?.write(to: destination)
            input = destination
        }
    }
    
}

public protocol InstalledImageModel: InstalledModel {
    
    func run(inputItem: inout FinderItem, outputItem: FinderItem, task: ShellManager)
    
}

public extension InstalledImageModel {
    
    static var rootPath: String {
        Bundle.main.bundlePath + "/Contents/Resources/\(self.rawName)"
    }
    
}

public protocol InstalledFrameModel: InstalledModel {
    
    func run(input1Item: FinderItem, input2Item: FinderItem, outputItem: FinderItem, task: ShellManager)
    
}

public extension InstalledFrameModel {
    
    static var rootPath: String {
        ModelDataProvider.main.location[self.rawName] ?? ""
    }
    
}

public struct Model_CAIN: InstalledFrameModel {
    
    public static var name: String { "CAIN" }
    public static var rawName: String { "cain-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/nihui/cain-ncnn-vulkan")! }
    
    /// Runs the model to achieve an output to `outputItem` from `input1Item` and `input2Item`.
    public func run(input1Item: FinderItem, input2Item: FinderItem, outputItem: FinderItem, task: ShellManager) {
//        Self.preProsess(input: &input1Item)
//        Self.preProsess(input: &input2Item) no pre preprocess
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName) -0 \(input1Item.shellPath) -1 \(input2Item.shellPath) -o \(outputItem.shellPath)")
        
    }
    
}

public struct Model_DAIN: InstalledFrameModel {
    
    public static var name: String { "DAIN" }
    public static var rawName: String { "dain-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/nihui/dain-ncnn-vulkan")! }
    
    /// Runs the model to achieve an output to `outputItem` from `input1Item` and `input2Item`.
    public func run(input1Item: FinderItem, input2Item: FinderItem, outputItem: FinderItem, task: ShellManager) {
//        Self.preProsess(input: &input1Item)
//        Self.preProsess(input: &input2Item)
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName) -0 \(input1Item.shellPath) -1 \(input2Item.shellPath) -o \(outputItem.shellPath)")
        
    }
    
}

public struct Model_RIFE: InstalledFrameModel {
    
    public static var name: String { "RIFE" }
    public static var rawName: String { "rife-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/nihui/rife-ncnn-vulkan")! }
    
    public var modelName: String = "rife-v2.3"
    public var modelNameOptions: [String] {
        ["rife", "rife-HD", "rife-UHD", "rife-anime", "rife-v2", "rife-v2.3", "rife-v2.4", "rife-v3.0", "rife-v3.1", "rife-v4"]
    }
    
    public var enableTTA: Bool = false
    public var enableUHD: Bool = true
    
    /// Runs the model to achieve an output to `outputItem` from `input1Item` and `input2Item`.
    public func run(input1Item: FinderItem, input2Item: FinderItem, outputItem: FinderItem, task: ShellManager) {
//        Self.preProsess(input: &input1Item)
//        Self.preProsess(input: &input2Item)
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName)-0 \(input1Item.shellPath) -1 \(input2Item.shellPath) -o \(outputItem.shellPath) \(self.enableTTA ? "-x" : "") \(self.enableUHD ? "-u" : "")")
        
    }
    
}

public struct Model_RealCUGAN: InstalledImageModel {
    
    public static var name: String { "Real-CUGAN" }
    public static var rawName: String { "realcugan-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/nihui/realcugan-ncnn-vulkan")! }
    
    public var scaleLevel: Int = 2 {
        didSet {
            updateWhenRequired(target: &denoiseLevel, options: denoiseLevelOption)
        }
    }
    public var scaleLevelOptions: [Int] {
        if modelName == "models-se" {
            return [2, 3, 4]
        } else if modelName == "models-nose" {
            return [2]
        } else {
            return [2, 3]
        }
    }
    
    public var denoiseLevel: Int = -1
    public var denoiseLevelOption: [Int] {
        if modelName == "models-se" {
            if scaleLevel == 2 {
                return [-1, 0, 1, 2, 3]
            } else {
                return [-1, 0, 3]
            }
        } else if modelName == "models-nose" {
            return [0]
        } else {
            return [-1, 0, 3]
        }
    }
    
    public var modelName: String = "models-se" {
        didSet {
            updateWhenRequired(target: &scaleLevel, options: scaleLevelOptions)
            updateWhenRequired(target: &denoiseLevel, options: denoiseLevelOption)
        }
    }
    
    public var modelNameOptions: [String] {
        ["models-se", "models-nose", "models-pro"]
    }
    
    public var enableTTA: Bool = false
    
    /// Runs the model to achieve an output to `outputItem` from `inputItem`.
    public func run(inputItem: inout FinderItem, outputItem: FinderItem, task: ShellManager) {
        Self.preProsess(input: &inputItem)
        let destinationDataProvider = DestinationDataProvider.main
        let format = destinationDataProvider.imageFormat.installedModelFormat(for: inputItem)
        
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName) -i \(inputItem.shellPath) -o \(outputItem.shellPath) -n \(self.denoiseLevel) -s \(self.scaleLevel) -m \(self.modelName) -g \(gpuID) \(self.enableTTA ? "-x" : "") -f \(format)")
    }
    
    private func updateWhenRequired(target: inout Int, options: [Int]) {
        if !options.contains(target) {
            target = options.nearestElement(to: target)!
        }
    }
}


public struct Model_RealESRGAN: InstalledImageModel {
    
    public static var name: String { "Real-ESRGAN" }
    public static var rawName: String { "realesrgan-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/xinntao/Real-ESRGAN")! }
    
    public var scaleLevel: Int = 4
    public var denoiseLevel: Int = -1
    
    public var scaleLevelOptions: [Int] {
        [4]
    }
    public var denoiseLevelOption: [Int] {
        [-1]
    }
    
    public var modelName: String = "realesrgan-x4plus"
    public var modelNameOptions: [String] {
        ["realesrgan-x4plus", "realesrgan-x4plus-anime", "realesr-animevideov3-x4"]
    }
    
    public var enableTTA: Bool = false
    
    /// Runs the model to achieve an output to `outputItem` from `inputItem`.
    public func run(inputItem: inout FinderItem, outputItem: FinderItem, task: ShellManager) {
        Self.preProsess(input: &inputItem)
        let destinationDataProvider = DestinationDataProvider.main
        let format = destinationDataProvider.imageFormat.installedModelFormat(for: inputItem)
        
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName) -i \(inputItem.shellPath) -o \(outputItem.shellPath) -s \(self.scaleLevel) -n \(self.modelName) -g \(gpuID) \(self.enableTTA ? "-x" : "") -f \(format)")
    }
}


public struct Model_RealSR: InstalledImageModel {
    
    public static var name: String { "RealSR" }
    public static var rawName: String { "realsr-ncnn-vulkan" }
    public static var source: URL { URL(string: "https://github.com/nihui/realsr-ncnn-vulkan")! }
    
    public var scaleLevel: Int = 4
    public var denoiseLevel: Int = -1 //unable
    public var scaleLevelOptions: [Int] {
        [2, 3, 4]
    }
    public var denoiseLevelOption: [Int] {
        [-1]
    }
    
    public var modelName: String = "models-DF2K_JPEG"
    public var modelNameOptions: [String] {
        ["models-DF2K_JPEG", "models-DF2K"]
    }
    
    public var enableTTA: Bool = false
    
    /// Runs the model to achieve an output to `outputItem` from `inputItem`.
    public func run(inputItem: inout FinderItem, outputItem: FinderItem, task: ShellManager) {
        Self.preProsess(input: &inputItem)
        let destinationDataProvider = DestinationDataProvider.main
        let format = destinationDataProvider.imageFormat.installedModelFormat(for: inputItem)
        
        task.run(arguments: "cd \(Self.programFolderItem.shellPath); ./\(Self.rawName) -i \(inputItem.shellPath) -o \(outputItem.shellPath) -s \(self.scaleLevel) -m \(self.modelName) -g \(gpuID) \(self.enableTTA ? "-x" : "") -f \(format)")
    }
}

fileprivate let gpuID = {
    let deviceCount = MTLCopyAllDevices().count
    if deviceCount == 0 { return "-1" }
    return [Int](0..<deviceCount).map { String($0) }.joined(separator: ", ")
}()
