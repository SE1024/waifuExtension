//
//  ExpandWidthHeight.metal
//  waifuExtension
//
//  Created by Vaida on 7/30/22.
//

#include <metal_stdlib>
using namespace metal;

constant int shrink_size [[function_constant(0)]]; // pass whatever non-array constants from here
constant float clip_eta8 [[function_constant(1)]]; // pass whatever non-array constants from here
constant int width       [[function_constant(2)]]; // pass whatever non-array constants from here
constant int exwidth     [[function_constant(3)]]; // pass whatever non-array constants from here
constant int exheight    [[function_constant(4)]]; // pass whatever non-array constants from here



// reconstruct the loop with Metal Shading Language (MSL), which looks like c.
kernel void ExpandWidthHeight(device const uint8_t* array, // the array to perform calculation.
                        device float* result, // the array to obtain the results. It is initially empty.
                        uint2 index [[thread_position_in_grid]]) { // defines the dimension of the index. use `uint2`, `uint3` for higher dimension. Then use x = index.x, y = index.y. Each index is assigned to individual thread to perform concurrently.
    
    int xx = index.x + shrink_size;
    int yy = index.y + shrink_size;
    int pixel = (width * index.y + index.x) * 4;
    
    int red = array[pixel];
    int green = array[pixel + 1];
    int blue = array[pixel + 2];
    
    float fred = ((float) red) / 255 + clip_eta8;
    float fgreen = ((float) green)  / 255 + clip_eta8;
    float fblue = ((float) blue)  / 255 + clip_eta8;
    
    result[yy * exwidth + xx] = fred;
    result[yy * exwidth + xx + exwidth * exheight] = fgreen;
    result[yy * exwidth + xx + exwidth * exheight * 2] = fblue;
}

//DispatchQueue.concurrentPerform(iterations: height) { y in
//    DispatchQueue.concurrentPerform(iterations: width) { x in
//        let xx = x + shrink_size
//        let yy = y + shrink_size
//        let pixel = (width * y + x) * 4
//        let r = data[pixel]
//        let g = data[pixel + 1]
//        let b = data[pixel + 2]
//
//        // !!! rgb values are from 0 to 1
//        // https://github.com/chungexcy/waifu2x-new/blob/master/image_test.py
//        let fr = Float(r) / 255 + clip_eta8
//        let fg = Float(g) / 255 + clip_eta8
//        let fb = Float(b) / 255 + clip_eta8
//
//        arr[yy * exwidth + xx] = fr
//        arr[yy * exwidth + xx + exwidth * exheight] = fg
//        arr[yy * exwidth + xx + exwidth * exheight * 2] = fb
//    }
//    }
