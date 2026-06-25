#!/bin/bash

# Create the iconset folder
mkdir ZigInvaders.iconset

# Generate all required sizes from your monitor image
# Replace monitor.png with whichever image you want as the icon
sips -z 16 16     assets/icon.png --out ZigInvaders.iconset/icon_16x16.png
sips -z 32 32     assets/icon.png --out ZigInvaders.iconset/icon_16x16@2x.png
sips -z 32 32     assets/icon.png --out ZigInvaders.iconset/icon_32x32.png
sips -z 64 64     assets/icon.png --out ZigInvaders.iconset/icon_32x32@2x.png
sips -z 128 128   assets/icon.png --out ZigInvaders.iconset/icon_128x128.png
sips -z 256 256   assets/icon.png --out ZigInvaders.iconset/icon_128x128@2x.png
sips -z 256 256   assets/icon.png --out ZigInvaders.iconset/icon_256x256.png
sips -z 512 512   assets/icon.png --out ZigInvaders.iconset/icon_256x256@2x.png
sips -z 512 512   assets/icon.png --out ZigInvaders.iconset/icon_512x512.png
sips -z 1024 1024 assets/icon.png --out ZigInvaders.iconset/icon_512x512@2x.png

# Convert to .icns
iconutil -c icns ZigInvaders.iconset -o assets/icon.icns

# Cleanup
rm -r ZigInvaders.iconset