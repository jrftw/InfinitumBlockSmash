#!/bin/bash

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is required. Please install it first."
    echo "On macOS: brew install imagemagick"
    exit 1
fi

# Check if source image is provided
if [ -z "$1" ]; then
    echo "Usage: ./generate_icons.sh <source_image>"
    echo "Source image should be at least 1024x1024 pixels"
    exit 1
fi

SOURCE_IMAGE="$1"
OUTPUT_DIR="AppIcon.appiconset"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate icons for different sizes
# iPhone
convert "$SOURCE_IMAGE" -resize 120x120 "$OUTPUT_DIR/Icon-60@2x.png"  # iPhone 60pt @2x
convert "$SOURCE_IMAGE" -resize 180x180 "$OUTPUT_DIR/Icon-60@3x.png"  # iPhone 60pt @3x

# iPad
convert "$SOURCE_IMAGE" -resize 152x152 "$OUTPUT_DIR/Icon-76@2x.png"  # iPad 76pt @2x

# App Store
convert "$SOURCE_IMAGE" -resize 1024x1024 "$OUTPUT_DIR/Icon-1024.png"  # App Store 1024pt @1x

# Create Contents.json for Xcode
cat > "$OUTPUT_DIR/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "Icon-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "Icons generated successfully in $OUTPUT_DIR"
echo "You can now drag the AppIcon.appiconset folder into your Xcode project's Assets.xcassets" 