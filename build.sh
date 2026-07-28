#!/bin/sh
# Builds Pomodoro.app in the repository root.
set -e
cd "$(dirname "$0")"

swift build -c release

APP=Pomodoro.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Pomodoro "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"

# Ad-hoc signature so Gatekeeper lets it run locally.
codesign --force -s - "$APP"

echo "Built $APP — launch it with: open $APP"
