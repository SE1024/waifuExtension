//
//  Waifu2xMLOut.metal
//  waifuExtension
//
//  Created by Vaida on 7/30/22.
//

#include <metal_stdlib>
using namespace metal;

constant int out_block_size  [[function_constant(0)]]; // the number in the argument is rising.
constant int out_fullWidth   [[function_constant(1)]]; // the number in the argument is rising.
constant int out_fullHeight  [[function_constant(2)]]; // the number in the argument is rising.
constant int channels        [[function_constant(3)]]; // the number in the argument is rising.
constant int out_width       [[function_constant(4)]]; // the number in the argument is rising.
constant int out_scale       [[function_constant(5)]]; // the number in the argument is rising.
constant int rectsCount      [[function_constant(6)]]; // the number in the argument is rising.


uint8_t normalize(float input) {
    float output = input * 255;
    if (output > 255) { return 255; }
    if (output < 0) { return 0; }
    return (uint8_t)output;
}

// reconstruct the loop with Metal Shading Language (MSL), which looks like c.
kernel void Waifu2xMLOut(device const float* array, // the array to perform calculation.
                         device const int* originXArray,
                         device const int* originYArray,
                         device uint8_t* result, // the array to obtain the results. It is initially empty.
                         uint3 index [[thread_position_in_grid]]) { // defines the dimension of the index. use `uint2`, `uint3` for higher dimension. Then use x = index.x, y = index.y. Each index is assigned to individual thread to perform concurrently.
    
    int dest_x = originXArray[index.z] * out_scale + index.x;
    int dest_y = originYArray[index.z] * out_scale + index.y;
    
    if (dest_x >= out_fullWidth || dest_y >= out_fullHeight) { return; }
    
    for (int channel = 0; channel < 3; channel ++) {
        int src_index = index.x + index.y * out_block_size + out_block_size * out_block_size * channel + (out_block_size * out_block_size * 3) * index.z / 2;
        int dest_index = (dest_x + dest_y * out_width) * channels + channel;
        uint8_t resulT = normalize(array[src_index]);
        result[dest_index] = resulT;
    }
}


//        let shapedArray = MLMultiArray(MLShapedArray<Float>(concatenating: mlArray.map { MLShapedArray(converting: try! mlModel.prediction(input: $0)) }, alongAxis: 0))
//        let originXArray = rects.map { Int($0.origin.x) }
//        let originYArray = rects.map { Int($0.origin.y) }
//
//        var mlArrayLength = (shapedArray.shape[2] as! Int) * (shapedArray.shape[3] as! Int) * (shapedArray.shape[4] as! Int)
//
//        DispatchQueue.concurrentPerform(iterations: out_block_size) { x in
//            DispatchQueue.concurrentPerform(iterations: out_block_size) { y in
//                DispatchQueue.concurrentPerform(iterations: rects.count) { z in
//                    let dest_x = originXArray[z] * out_scale + x
//                    let dest_y = originYArray[z] * out_scale + y
//
//                    if (dest_x >= out_fullWidth || dest_y >= out_fullHeight) { return }
//
//                    DispatchQueue.concurrentPerform(iterations: 3) { channel in
//                        let src_index = x + y * out_block_size + out_block_size * out_block_size * channel + mlArrayLength * z
//                        let dest_index = (dest_x + dest_y * out_width) * channels + channel
//                        imgData[dest_index] = UInt8(normalize(Double(shapedArray[src_index] as! Float)))
//                    }
//                }
//            }
//        }
