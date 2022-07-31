- Added noneDestination
- Restructured Source code, making the developer happier
- Some minor memory optimization
- Fixed the issue where the app may crash unexpected if the output image is extremely large
- May have allowed installed models to run on multiple GPUs.

- Now you can choose your video / image output format
- Waifu2x performance improvements. Note: From now on, it would only check 10% of the pixels for checking whether an image contains alpha. Please inform me if you encounter any issue caused by this.
    - Now a standard 1080p image takes only 464ms with waifu2x anime scale level 2, on M1 Max.
