#!/bin/bash
set -e

echo "Killing Airlock..."
pkill -f Airlock || true

echo "Building..."
xcodebuild -project Airlock.xcodeproj -scheme Airlock -configuration Release build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath .xcode-build \
  -quiet

echo "Deploying to /Applications..."
rm -rf /Applications/Airlock.app
cp -r .xcode-build/Build/Products/Release/Airlock.app /Applications/Airlock.app

echo "Launching..."
open /Applications/Airlock.app

echo "Done."
