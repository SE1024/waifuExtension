//
//  NSImage+MultiArray.swift
//  Waifu2x-ios
//
//  Created by xieyi on 2017/9/14.
//  Copyright © 2017年 xieyi. All rights reserved.
//

import CoreML
import Cocoa
import os

extension CGImage {
    
    /// Expand the original image by shrink_size and store rgb in float array.
    /// The model will shrink the input image by 7 px.
    ///
    /// - Returns: Float array of rgb values
    public func expand(withAlpha: Bool, shrink_size: Int, clip_eta8: Float) -> (array: UnsafeMutablePointer<Float>, length: Int) {
        
        let width = self.width
        let height = self.height
        
        let rect = NSRect.init(origin: .zero, size: CGSize(width: width, height: height))
        
        let date = Date()
        // Redraw image in 32-bit RGBA
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        data.initialize(repeating: 0, count: width * height * 4)
        defer {
            data.deallocate()
        }
        autoreleasepool {
            let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: self.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(self, in: rect)
        }
        
        let exwidth = width + 2 * shrink_size
        let exheight = height + 2 * shrink_size
        
        var arr = UnsafeMutablePointer<Float>.allocate(capacity: 3 * exwidth * exheight)
        Logger().info("To expand image, allocate data array & draw cg context took: \(date.distance(to: Date()).expressedAsTime())")
        
        if let device = MTLCreateSystemDefaultDevice(), let library = device.makeDefaultLibrary() {
            let constants = MTLFunctionConstantValues()
            
            var shrink_size_pte = shrink_size
            var clip_eta8_pte = clip_eta8
            var width_pte = width
            var exwidth_pte = exwidth
            var exheight_pte = exheight
            
            constants.setConstantValue(&shrink_size_pte, type: MTLDataType.int,   index: 0)
            constants.setConstantValue(&clip_eta8_pte,   type: MTLDataType.float, index: 1)
            constants.setConstantValue(&width_pte,       type: MTLDataType.int,   index: 2)
            constants.setConstantValue(&exwidth_pte,     type: MTLDataType.int,   index: 3)
            constants.setConstantValue(&exheight_pte,    type: MTLDataType.int,   index: 4)
            
            // Call the metal function. The name is the function name.
            let metalFunction = try! library.makeFunction(name: "ExpandWidthHeight", constantValues: constants)
            // creates the pipe would stores the calculation
            let pipelineState = try! device.makeComputePipelineState(function: metalFunction)
            
            // generate the buffers where the argument is stored in memory.
            let commandQueue = device.makeCommandQueue()!
            let commandBuffer = commandQueue.makeCommandBuffer()!
            let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            // pass the input array. Be really careful with the length, otherwise memory error would occur.
            let inputArrayBuffer = device.makeBuffer(bytes: data, length: width * height * 4 * MemoryLayout<UInt8>.size, options: .storageModeShared)!
            // generate the buffer for output array. Also be careful with length.
            let resultArrayBuffer = device.makeBuffer(length: width * height * 4 * MemoryLayout<Float>.size, options: .storageModeShared)!
            
            // pass in the buffers. The indexes need to be the same as defined in .metal file
            commandEncoder.setComputePipelineState(pipelineState)
            commandEncoder.setBuffer(inputArrayBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(resultArrayBuffer, offset: 0, index: 1)
            
            // The size of the `thread_position_in_grid` in .metal. the three arguments represent the x, y, z dimensions.
            let gridSize = MTLSizeMake(width, height, 1)
            
            // Defines the size which can calculate concurrently. the three arguments represent the x, y, z dimensions.
            let w = pipelineState.threadExecutionWidth
            let h = pipelineState.maxTotalThreadsPerThreadgroup / w
            let threadsPerThreadGroup = MTLSizeMake(w, h, 1)
            commandEncoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadsPerThreadGroup)
            
            // Run the metal.
            commandEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // obtain the results. Now, the results are only just raw pointers.
            let rawPointer = resultArrayBuffer.contents()
            
            arr = rawPointer.bindMemory(to: Float.self, capacity: width * height * 4)
            
        } else {
            DispatchQueue.concurrentPerform(iterations: height) { y in
                DispatchQueue.concurrentPerform(iterations: width) { x in
                    let xx = x + shrink_size
                    let yy = y + shrink_size
                    let pixel = (width * y + x) * 4
                    let r = data[pixel]
                    let g = data[pixel + 1]
                    let b = data[pixel + 2]
                    
                    // !!! rgb values are from 0 to 1
                    // https://github.com/chungexcy/waifu2x-new/blob/master/image_test.py
                    let fr = Float(r) / 255 + clip_eta8
                    let fg = Float(g) / 255 + clip_eta8
                    let fb = Float(b) / 255 + clip_eta8
                    
                    arr[yy * exwidth + xx] = fr
                    arr[yy * exwidth + xx + exwidth * exheight] = fg
                    arr[yy * exwidth + xx + exwidth * exheight * 2] = fb
                }
            }
        }
        
        
        // Top-left corner
        for _ in 0...0 {
            let pixel = 0
            let r = data[pixel]
            let g = data[pixel + 1]
            let b = data[pixel + 2]
            let fr = Float(r) / 255
            let fg = Float(g) / 255
            let fb = Float(b) / 255
            
            DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    arr[y * exwidth + x] = fr
                    arr[y * exwidth + x + exwidth * exheight] = fg
                    arr[y * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
        }
        
        // Top-right corner
        for _ in 0...0 {
            let pixel = (width - 1) * 4
            let r = data[pixel]
            let g = data[pixel + 1]
            let b = data[pixel + 2]
            let fr = Float(r) / 255
            let fg = Float(g) / 255
            let fb = Float(b) / 255
            
            DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    let x = width + shrink_size + x
                    arr[y * exwidth + x] = fr
                    arr[y * exwidth + x + exwidth * exheight] = fg
                    arr[y * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
        }
        
        // Bottom-left corner
        for _ in 0...0 {
            let pixel = (width * (height - 1)) * 4
            let r = data[pixel]
            let g = data[pixel + 1]
            let b = data[pixel + 2]
            let fr = Float(r) / 255
            let fg = Float(g) / 255
            let fb = Float(b) / 255
            
            DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                let y = y + height+shrink_size
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    arr[y * exwidth + x] = fr
                    arr[y * exwidth + x + exwidth * exheight] = fg
                    arr[y * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
        }
        
        // Bottom-right corner
        for _ in 0...0 {
            let pixel = (width * (height - 1) + (width - 1)) * 4
            let r = data[pixel]
            let g = data[pixel + 1]
            let b = data[pixel + 2]
            let fr = Float(r) / 255
            let fg = Float(g) / 255
            let fb = Float(b) / 255
            
            DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                let y = y +  height+shrink_size
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    let x = x + width+shrink_size
                    
                    arr[y * exwidth + x] = fr
                    arr[y * exwidth + x + exwidth * exheight] = fg
                    arr[y * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
        }
        
        // Top & bottom bar
        DispatchQueue.concurrentPerform(iterations: width) { x in
            for _ in 0...0 {
                let pixel = x * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                let xx = x + shrink_size
                
                DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                    arr[y * exwidth + xx] = fr
                    arr[y * exwidth + xx + exwidth * exheight] = fg
                    arr[y * exwidth + xx + exwidth * exheight * 2] = fb
                }
            }
            
            for _ in 0...0 {
                let pixel = (width * (height - 1) + x) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                let xx = x + shrink_size
                
                DispatchQueue.concurrentPerform(iterations: shrink_size) { y in
                    let y = y + height+shrink_size
                    
                    arr[y * exwidth + xx] = fr
                    arr[y * exwidth + xx + exwidth * exheight] = fg
                    arr[y * exwidth + xx + exwidth * exheight * 2] = fb
                }
            }
        }
        
        // Left & right bar
        DispatchQueue.concurrentPerform(iterations: height) { y in
            for _ in 0...0 {
                let pixel = (width * y) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                let yy = y + shrink_size
                
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    arr[yy * exwidth + x] = fr
                    arr[yy * exwidth + x + exwidth * exheight] = fg
                    arr[yy * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
            
            for _ in 0...0 {
                let pixel = (width * y + (width - 1)) * 4
                let r = data[pixel]
                let g = data[pixel + 1]
                let b = data[pixel + 2]
                let fr = Float(r) / 255
                let fg = Float(g) / 255
                let fb = Float(b) / 255
                let yy = y + shrink_size
                
                DispatchQueue.concurrentPerform(iterations: shrink_size) { x in
                    let x = x + width+shrink_size
                    
                    arr[yy * exwidth + x] = fr
                    arr[yy * exwidth + x + exwidth * exheight] = fg
                    arr[yy * exwidth + x + exwidth * exheight * 2] = fb
                }
            }
        }
        
        return (arr, 3 * exwidth * exheight)
    }
    
}
