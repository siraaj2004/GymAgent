#!/bin/bash
set -euo pipefail
# Builds the app for a real device WITHOUT signing, then packages Payload/*.app
# into an unsigned .ipa. Sideloadly / AltStore sign it with your Apple ID.
# Do NOT rename a zip to .ipa and do NOT claim an IPA exists until this script
# has produced build/GymAI-unsigned.ipa and `unzip -l` shows Payload/GymAI.app.
xcodegen generate
xcodebuild -project GymAI.xcodeproj -scheme GymAI -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
APP=$(find build/DerivedData/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' | head -1)
test -n "$APP"
rm -rf build/Payload build/GymAI-unsigned.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
cd build && zip -qr GymAI-unsigned.ipa Payload && cd ..
ls -lh build/GymAI-unsigned.ipa
unzip -l build/GymAI-unsigned.ipa | head -20
