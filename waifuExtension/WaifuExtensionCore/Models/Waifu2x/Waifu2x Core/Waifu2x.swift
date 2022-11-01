//
//  Waifu2x.swift
//  Waifu2x-mac
//
//  Created by xieyi on 2018/1/24.
//  Copyright © 2018年 xieyi. All rights reserved.
//

import Foundation
import CoreML
import Cocoa
import Metal
import MetalKit
import Support
import os

public final class Waifu2x {
    
//    var didFinishedOneBlock: ( _ total: Double) -> Void  = {_ in }
    
    func run(_ image: NativeImage, model: ModelCoordinator) -> NativeImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let image = self.run(cgImage, model: model) else { return nil }
        return NativeImage(cgImage: image)
    }
    
    func run(_ image: CGImage, model: ModelCoordinator) -> CGImage? {
        
//        let fullDate = Date()
        let logger = Logger()
        
        /// The output block size.
        /// It is dependent on the model.
        /// Do not modify it until you are sure your model has a different number.
        var block_size = model.caffe.block_size // ?? 128
        /// The difference between output and input block size
        var shrink_size = 7
        
        /// Do not exactly know its function
        /// However it can on average improve PSNR by 0.09
        /// https://github.com/nagadomi/self/commit/797b45ae23665a1c5e3c481c018e48e6f0d0e383
        let clip_eta8 = Float(0.00196)
        
        let out_scale = model.caffe.scale
        var image = image
        
        let width = Int(image.width)
        let height = Int(image.height)
        var fullWidth = width
        var fullHeight = height
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        
//        BiasRecorder.add(bias: .init(stage: .initial0, time: fullDate.distance(to: Date())))
//        didFinishedOneBlock(68540.22)
//        let initial0Date = Date()
        
        // If image is too small, expand it
        if width < block_size || height < block_size {
            if width < block_size {
                fullWidth = block_size
            }
            if height < block_size {
                fullHeight = block_size
            }
            var bitmapInfo = image.bitmapInfo.rawValue
            if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.first.rawValue {
                bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
            } else if bitmapInfo & CGBitmapInfo.alphaInfoMask.rawValue == CGImageAlphaInfo.last.rawValue {
                bitmapInfo = bitmapInfo & ~CGBitmapInfo.alphaInfoMask.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            }
            let context = CGContext(data: nil, width: fullWidth, height: fullHeight, bitsPerComponent: image.bitsPerComponent, bytesPerRow: image.bytesPerRow / width * fullWidth, space: colorSpace, bitmapInfo: bitmapInfo)
            var y = fullHeight - height
            if y < 0 {
                y = 0
            }
            context?.draw(image, in: CGRect(x: 0, y: y, width: width, height: height))
            guard let contextCG = context?.makeImage() else { return nil }
            image = contextCG
        }
        
        var hasalpha = image.alphaInfo != CGImageAlphaInfo.none
        var channels = 3
        var alpha: [UInt8]! = nil
        
        if hasalpha {
            alpha = image.alpha()
            var ralpha = false
            // Check if it really has alpha
            var aIndex = 0
            
            while aIndex < alpha.count {
                let a = alpha[aIndex]
                if a < 255 {
                    ralpha = true
                    break
                }
                
                aIndex += 10
            }
            
            if ralpha {
                channels = 4
            } else {
                hasalpha = false
            }
        }
        
        guard !Task.isCancelled else { return nil }
//        BiasRecorder.add(bias: .init(stage: .initial1, time: initial0Date.distance(to: Date())))
//        didFinishedOneBlock(35.27377)
//        let initial1Date = Date()
        
        let out_width = width * out_scale
        let out_height = height * out_scale
        let out_fullWidth = fullWidth * out_scale
        let out_fullHeight = fullHeight * out_scale
        let out_block_size = block_size * out_scale
        let rects = image.getCropRects(block_size: block_size)
        // Prepare for output pipeline
        // Merge arrays into one array
        let normalize = { (input: Double) -> Double in
            let output = input * 255
            if output > 255 {
                return 255
            }
            if output < 0 {
                return 0
            }
            return output
        }
        
        let bufferSize = out_block_size * out_block_size * 3
        let imgData = UnsafeMutablePointer<UInt8>.allocate(capacity: out_width * out_height * channels)
//        var deallocateImageDataWhenFinishes = true
        defer {
//            if deallocateImageDataWhenFinishes {
                imgData.deallocate()
//            }
        }
        
//        BiasRecorder.add(bias: .init(stage: .initial2, time: initial1Date.distance(to: Date())))
//        didFinishedOneBlock(156912.95)
//        let initial2Date = Date()
        
        // Alpha channel support
        // The alpha task starts asyc in the background
        var alpha_task: BackgroundTask? = nil
        if hasalpha {
            alpha_task = BackgroundTask("alpha") {
                if out_scale > 1 {
                    var outalpha: [UInt8]? = nil
                    if let metalBicubic = try? MetalBicubic(), out_width <= metalBicubic.maxTextureSize() && out_height <= metalBicubic.maxTextureSize()  {
                        outalpha = metalBicubic.resizeSingle(alpha, width, height, Float(out_scale))
                    }
                    
                    var emptyAlpha = true
                    if let outalpha {
                        let outAlphaCount = outalpha.count
                        var index = 0
                        while index < outAlphaCount {
                            if outalpha[index] > 0 {
                                emptyAlpha = false
                                break
                            }
                            index += 1
                        }
                    }
                    
                    if outalpha != nil && !emptyAlpha {
                        alpha = outalpha!
                    } else {
                        // Fallback to CPU scale
                        logger.log("fallback to cpu for Bicubic")
                        let bicubic = Bicubic(image: alpha, channels: 1, width: width, height: height)
                        alpha = bicubic.resize(scale: Float(out_scale))
                    }
                }
                
                DispatchQueue.concurrentPerform(iterations: out_height) { y in
                    DispatchQueue.concurrentPerform(iterations: out_width) { x in
                        imgData[(y * out_width + x) * channels + 3] = alpha[y * out_width + x]
                    }
                }
                
                
            }
        }
        
//        BiasRecorder.add(bias: .init(stage: .initial3, time: initial2Date.distance(to: Date())))
//        didFinishedOneBlock(70890.199)
//        logger.info("initial date: \(fullDate.distance(to: Date()).expressedAsTime())")
        
        var mlArray: [MLMultiArray] = []
        
        // Start running model
//        let expendImageDate = Date()
        var expwidth = fullWidth + 2 * shrink_size
        var expheight = fullHeight + 2 * shrink_size
        let expanded = image.expand(withAlpha: hasalpha, shrink_size: shrink_size, clip_eta8: clip_eta8)
        defer { if expanded.requiresDeallocate { expanded.array.deallocate() } }
        
        guard !Task.isCancelled else { return nil }
//        BiasRecorder.add(bias: .init(stage: .expend, time: expendImageDate.distance(to: Date())))
//        didFinishedOneBlock(8.742)
//        logger.info("ExpendImage: \(expendImageDate.distance(to: Date()).expressedAsTime())")
        
//        let in_pipeDate = Date()
        
        do {
            var manager = try MetalManager(name: "Calculation", outputElementType: Float.self)
            
            var arrayLengthFull = 3 * (block_size + 2 * shrink_size) * (block_size + 2 * shrink_size)
            let arrayLength = (block_size + 2 * shrink_size)
            
            manager.setConstant(&block_size,      type: .int)
            manager.setConstant(&shrink_size,     type: .int)
            manager.setConstant(&expwidth,        type: .int)
            manager.setConstant(&expheight,       type: .int)
            manager.setConstant(&arrayLengthFull, type: .int)
            
            try manager.submitConstants()
            
            manager.setGridSize(width: arrayLength, height: arrayLength, depth: rects.count)
            
            try manager.setInputBuffer(expanded.array, length: expanded.length)
            try manager.setInputBuffer(rects.map { Float($0.origin.x) })
            try manager.setInputBuffer(rects.map { Float($0.origin.y) })
            
            try manager.setOutputBuffer(count: arrayLengthFull * rects.count)
            
            try manager.perform()
            
            mlArray = manager.getOutputShapedArray(shape: [rects.count, 3, block_size + 2 * shrink_size, block_size + 2 * shrink_size]).map { MLMultiArray($0) }
            
        } catch {
            print("GPU unavailable")
            // calculate with CPU
            var in_pipeResults: [(index: Int, value: MLMultiArray)] = []
            
            func calculate(with index: Int) {
                let rect = rects[index]
                
                let x = Int(rect.origin.x)
                let y = Int(rect.origin.y)
                let multi = try! MLMultiArray(shape: [3, NSNumber(value: block_size + 2 * shrink_size), NSNumber(value: block_size + 2 * shrink_size)], dataType: .float32)
                
                var y_exp = y
                
                while y_exp < (y + block_size + 2 * shrink_size) {
                    
                    var x_exp = x
                    while x_exp < (x + block_size + 2 * shrink_size) {
                        let x_new = x_exp - x
                        let y_new = y_exp - y
                        multi[y_new * (block_size + 2 * shrink_size) + x_new] = NSNumber(value: expanded.array[y_exp * expwidth + x_exp])
                        multi[y_new * (block_size + 2 * shrink_size) + x_new + (block_size + 2 * shrink_size) * (block_size + 2 * shrink_size)] = NSNumber(value: expanded.array[y_exp * expwidth + x_exp + expwidth * expheight])
                        multi[y_new * (block_size + 2 * shrink_size) + x_new + (block_size + 2 * shrink_size) * (block_size + 2 * shrink_size) * 2] = NSNumber(value: expanded.array[y_exp * expwidth + x_exp + expwidth * expheight * 2])
                        
                        x_exp += 1
                    }
                    
                    y_exp += 1
                }
                
                in_pipeResults.append((index, multi))
            }
            
            DispatchQueue.concurrentPerform(iterations: rects.count) { index in
                calculate(with: index)
            }
            
            mlArray = in_pipeResults.sorted(by: { $0.index < $1.index }).map({ $0.value })
        }
        
        guard !Task.isCancelled else { return nil }
//        BiasRecorder.add(bias: .init(stage: .inPipe, time: in_pipeDate.distance(to: Date())))
//        didFinishedOneBlock(83.626)
//        logger.info("Generate shaped ml array: \(in_pipeDate.distance(to: Date()).expressedAsTime())")
        
        // Prepare for model pipeline
        // Run prediction on each block
        
//        let model_pipelineDate = Date()
        let mlModel = model.caffe.finalizedModel!
        
        let currentProgress = Progress(totalUnitCount: Int64(rects.count))
        
//        do {
//            let shapedArray = MLMultiArray(concatenating: mlArray.map { try! mlModel.prediction(input: $0) }, axis: 0, dataType: .float)
//
//            logger.info("ML: \(model_pipelineDate.distance(to: Date()).expressedAsTime())")
//            let postMLDate = Date()
//
//            print(shapedArray.shape, rects.count, shapedArray.strides)
//            var rectsCount = rects.count
//
//            var manager = MetalManager(name: "Waifu2xMLOut")
//
//            manager.constants.setConstantValue(&out_block_size, type: MTLDataType.int, index: 0)
//            manager.constants.setConstantValue(&out_fullWidth,  type: MTLDataType.int, index: 1)
//            manager.constants.setConstantValue(&out_fullHeight, type: MTLDataType.int, index: 2)
//            manager.constants.setConstantValue(&channels,       type: MTLDataType.int, index: 3)
//            manager.constants.setConstantValue(&out_width,      type: MTLDataType.int, index: 4)
//            manager.constants.setConstantValue(&out_scale,      type: MTLDataType.int, index: 5)
//            manager.constants.setConstantValue(&rectsCount,     type: MTLDataType.int, index: 6)
//
//            // The size of the `thread_position_in_grid` in .metal. the three arguments represent the x, y, z dimensions.
//            manager.gridSize = MTLSize(width: out_block_size, height: out_block_size, depth: rectsCount * 2 - 1) // still wrong if `index.z` is 1.
//
//            let rawPointer = try manager.perform { device, commandEncoder in
//                // pass the input array. Be really careful with the length, otherwise memory error would occur.
//                let inputArrayBuffer = device.makeBuffer(length: shapedArray.shape.map{ $0 as! Int }.reduce(1, *) * MemoryLayout<Float>.size)!
//                memcpy(inputArrayBuffer.contents(), shapedArray.dataPointer, inputArrayBuffer.length) // it is still wrong if scalers array was passed
//
//                // generate the buffer for output array. Also be careful with length.
//                let resultArrayBuffer = device.makeBuffer(length: out_width * out_height * channels * MemoryLayout<UInt8>.size)!
//                // The noise came from here. use `bytes: &imgData, `.
//
//                var originXArray = rects.map { Int($0.origin.x) }
//                var originYArray = rects.map { Int($0.origin.y) }
//
//                let originXArrayBuffer = device.makeBuffer(bytes: &originXArray, length: MemoryLayout<Int>.size * rects.count)!
//                let originYArrayBuffer = device.makeBuffer(bytes: &originYArray, length: MemoryLayout<Int>.size * rects.count)!
//
//                // pass in the buffers. The indexes need to be the same as defined in .metal file
//                commandEncoder.setBuffer(inputArrayBuffer,   offset: 0, index: 0)
//                commandEncoder.setBuffer(originXArrayBuffer, offset: 0, index: 1)
//                commandEncoder.setBuffer(originYArrayBuffer, offset: 0, index: 2)
//                commandEncoder.setBuffer(resultArrayBuffer,  offset: 0, index: 3)
//
//                return resultArrayBuffer
//            }
//
//            // obtain the results. Now, the results are only just raw pointers.
//            imgData.deallocate()
//            deallocateImageDataWhenFinishes = false
//            imgData = rawPointer.bindMemory(to: UInt8.self, capacity: out_width * out_height * channels)
//
//            logger.info("post ml Date: \(postMLDate.distance(to: Date()).expressedAsTime())")
//
//            // fix the error on the first block
////            for _ in 0...0 {
////                DispatchQueue.concurrentPerform(iterations: out_block_size) { dest_x in
////                    DispatchQueue.concurrentPerform(iterations: out_block_size) { dest_y in
////                        if (dest_x >= out_fullWidth || dest_y >= out_fullHeight) { return; }
////
////                        DispatchQueue.concurrentPerform(iterations: 3) { channel in
////                            let src_index = dest_x + dest_y * out_block_size + out_block_size * out_block_size * channel
////                            let dest_index = (dest_x + dest_y * out_width) * channels + channel
////                            let resulT = normalize(Double(shapedArray[src_index] as! Float))
////                            imgData[dest_index] = UInt8(resulT)
////                        }
////                    }
////                }
////            }
//
//            logger.info("post ml Date total: \(postMLDate.distance(to: Date()).expressedAsTime())")
//
//        } catch {
            rects.concurrentEnumerate { index, rect in
//                print(Task.isCancelled)
                guard !Task.isCancelled else { return }
                guard !currentProgress.isCancelled else { return }
                
                autoreleasepool {
                    let array = mlArray[index]
                    
                    let mlOutput = try! mlModel.prediction(input: array)
                    
                    let origin_x = Int(rect.origin.x) * out_scale
                    let origin_y = Int(rect.origin.y) * out_scale
                    let dataPointer = UnsafeMutableBufferPointer(start: mlOutput.dataPointer.assumingMemoryBound(to: Double.self),
                                                                 count: bufferSize)
                    
                    DispatchQueue.concurrentPerform(iterations: 3) { channel in
                        DispatchQueue.concurrentPerform(iterations: out_block_size) { src_y in
                            DispatchQueue.concurrentPerform(iterations: out_block_size) { src_x in
                                let dest_x = origin_x + src_x
                                let dest_y = origin_y + src_y
                                if dest_x >= out_fullWidth || dest_y >= out_fullHeight { return }
                                
                                let src_index = src_y * out_block_size + src_x + out_block_size * out_block_size * channel
                                let dest_index = (dest_y * out_width + dest_x) * channels + channel
                                imgData[dest_index] = UInt8(normalize(dataPointer[src_index]))
                            }
                        }
                    }
                    
//                    didFinishedOneBlock(Double(rects.count))
                    DispatchQueue.main.async {
                        currentProgress.completedUnitCount += 1
                    }
                }
            }
//        }
        
        guard !Task.isCancelled else { return nil }
//        BiasRecorder.add(bias: .init(stage: .ml, time: model_pipelineDate.distance(to: Date())))
//        logger.info("ML Total: \(model_pipelineDate.distance(to: Date()).expressedAsTime())")
//
//        let date = Date()
        alpha_task?.wait()
//        logger.info("wait alpha: \(date.distance(to: Date()).expressedAsTime())")
        
//        let generateImageDate = Date()
        let cfbuffer = CFDataCreate(nil, imgData, out_width * out_height * channels)!
        let dataProvider = CGDataProvider(data: cfbuffer)!
        var bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        print(bitmapInfo, hasalpha)
        if hasalpha {
            bitmapInfo |= CGImageAlphaInfo.last.rawValue
        }
        
        guard !Task.isCancelled else { return nil }
        var cgImage: CGImage? {
            CGImage(width: out_width, height: out_height, bitsPerComponent: 8, bitsPerPixel: 8 * channels, bytesPerRow: out_width * channels, space: colorSpace, bitmapInfo: CGBitmapInfo.init(rawValue: bitmapInfo), provider: dataProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
            ??
            CGImage(width: out_width, height: out_height, bitsPerComponent: 8, bitsPerPixel: 8 * channels, bytesPerRow: out_width * channels, space: colorSpace, bitmapInfo: CGBitmapInfo.init(rawValue: 32), provider: dataProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
        }
        
//        BiasRecorder.add(bias: .init(stage: .generateOutput, time: generateImageDate.distance(to: Date())))
//        logger.info("Generate Image: \(generateImageDate.distance(to: Date()).expressedAsTime())")
//        didFinishedOneBlock(686.439)
//        logger.info("Waifu2x finished with time: \(fullDate.distance(to: Date()).expressedAsTime())")
        currentProgress.completedUnitCount = Int64(rects.count)
        
        return cgImage
    }
    
}
