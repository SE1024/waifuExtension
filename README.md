# waifuExtension
The waifu2x on Mac.

The new version is capable of taking advantages of CPU, GPU, and [ANE](https://github.com/hollance/neural-engine).

## Usage
- Enlarge videos or images with machine learning on Mac.
- Interpolate frames for videos.

## Install
Files and source code could be found in [releases](https://github.com/Vaida12345/waifuExtension/releases).

Note: If mac says the app was damaged / unknown developer, please go to Finder, right click on the App, and choose open.

## Privacy
This app works completely offline and requires no internet connection. Nothing is collected or stored, expect for:
- Your settings stored in its [containter](https://developer.apple.com/documentation/foundation/1413045-nshomedirectory/).
- Temp images during processing in its [containter](https://developer.apple.com/documentation/foundation/1413045-nshomedirectory/), the existance would only last for three lines of code, after which it is deleted.

If the app crashes, please choose not to share crash log with Apple.

## Models
The waifu2x models where obtained from [waifu2x-caffe](https://github.com/lltcggie/waifu2x-caffe), and translated to coreML via [coremltools](https://github.com/apple/coremltools).

Other models are:
 - [dain-ncnn-vulkan](https://github.com/nihui/dain-ncnn-vulkan)
 - [realsr-ncnn-vulkan](https://github.com/nihui/realsr-ncnn-vulkan)
 - [cain-ncnn-vulkan](https://github.com/nihui/cain-ncnn-vulkan)
 - [realcugan-ncnn-vulkan](https://github.com/nihui/realcugan-ncnn-vulkan)
 - [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN)
 - [rife-ncnn-vulkan](https://github.com/nihui/rife-ncnn-vulkan)

## Note
This app was based on the work of [waifu2x-ios](https://github.com/imxieyi/waifu2x-ios). Nearly all the files in the folder "waifu2x-mac" were created by him. However, modifications were done to improve speed.

## Speed
When processing a standard 1080p image (1920 × 1080) using Waifu2x Caffe, MacBook Pro with the M1 Max chip took only 0.7 seconds.

## Interface
This app was written with [SwiftUI](https://developer.apple.com/xcode/swiftui/).

<img width="2024" alt="Screen Shot 2022-07-07 at 7 16 07 PM" src="https://user-images.githubusercontent.com/91354917/177738899-7d1848e5-83a3-40f9-be21-4cbee768aa95.png">


## Preview
![Untitled-1](https://user-images.githubusercontent.com/91354917/177736461-f9a15b8e-fdda-4808-bd28-2c53d16e3b2e.png)

## Credits
 - [waifu2x-ios](https://github.com/imxieyi/waifu2x-ios) for nearly all the algorithms used to enlarge images.
 - [waifu2x-caffe](https://github.com/lltcggie/waifu2x-caffe) for all the models.
 - [stack overflow](https://stackoverflow.com) for all the solutions.
 - [dain-ncnn-vulkan](https://github.com/nihui/dain-ncnn-vulkan) for dain-ncnn-vulkan.
 - [realsr-ncnn-vulkan](https://github.com/nihui/realsr-ncnn-vulkan) for realsr-ncnn-vulkan.
 - [cain-ncnn-vulkan](https://github.com/nihui/cain-ncnn-vulkan) for cain-ncnn-vulkan.
 - [realcugan-ncnn-vulkan](https://github.com/nihui/realcugan-ncnn-vulkan) for realcugan-ncnn-vulkan.
 - [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) for Real-ESRGAN.
 - [rife-ncnn-vulkan](https://github.com/nihui/rife-ncnn-vulkan) for rife-ncnn-vulkan.
