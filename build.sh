#!/bin/bash
# Build OpencodeTokens.app from main.swift. No Xcode needed.
set -e
cd "$(dirname "$0")"

APP="$HOME/Applications/OpencodeTokens.app"

swiftc -O -target "$(uname -m)-apple-macos12.0" main.swift -o opencode-tokens

mkdir -p "$APP/Contents/MacOS"
cp opencode-tokens "$APP/Contents/MacOS/OpencodeTokens"
chmod +x "$APP/Contents/MacOS/OpencodeTokens"
cp Info.plist "$APP/Contents/Info.plist"

echo "Built $APP"
echo "Launch with: open \"$APP\""
