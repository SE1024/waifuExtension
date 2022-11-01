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
import Support

extension CGImage {
    
    /// Expand the original image by shrink_size and store rgb in float array.
    /// The model will shrink the input image by 7 px.
    ///
    /// - Returns: Float array of rgb values
    public func expand(withAlpha: Bool, shrink_size: Int, clip_eta8: Float) -> (array: UnsafeMutablePointer<Float>, length: Int, requiresDeallocate: Bool) {
        
        let width = self.width
        let height = self.height
        
        let rect = NSRect.init(origin: .zero, size: CGSize(width: width, height: height))
        
        // Redraw image in 32-bit RGBA
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
//        data.initialize(repeating: 0, count: width * height * 4)
        defer { data.deallocate() }
        
        autoreleasepool {
            let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: self.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.draw(self, in: rect)
        }
        
        let exwidth = width + 2 * shrink_size
        let exheight = height + 2 * shrink_size
        
        let arr: UnsafeMutablePointer<Float>
        let requiresDeallocate: Bool
        
        do {
            var manager = try MetalManager(name: "ExpandWidthHeight", outputElementType: Float.self)
            
            var shrink_size_pte = shrink_size
            var clip_eta8_pte = clip_eta8
            var width_pte = width
            var exwidth_pte = exwidth
            var exheight_pte = exheight
            
            manager.setConstant(&shrink_size_pte, type: .int)
            manager.setConstant(&clip_eta8_pte,   type: .float)
            manager.setConstant(&width_pte,       type: .int)
            manager.setConstant(&exwidth_pte,     type: .int)
            manager.setConstant(&exheight_pte,    type: .int)
            
            try manager.submitConstants()
            
            manager.setGridSize(width: width, height: height)
            
            try manager.setInputBuffer(data, length: width * height * 4)
            try manager.setOutputBuffer(count: width * height * 4)
            
            try manager.perform()
            
            arr = manager.getOutputPointer().bindMemory(to: Float.self, capacity: width * height * 4)
            requiresDeallocate = false
        } catch {
            arr = UnsafeMutablePointer<Float>.allocate(capacity: width * height * 4)
            requiresDeallocate = true
            
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
        
        return (arr, 3 * exwidth * exheight, requiresDeallocate)
    }
    
}
