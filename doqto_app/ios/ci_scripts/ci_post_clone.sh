#!/bin/sh
# Xcode Cloud runs this after cloning, before resolving dependencies.
# The runners have no Flutter, so install it and generate the iOS artefacts
# (Generated.xcconfig, the plugin registrant, Pods) that the Xcode build needs.
set -e

FLUTTER_VERSION=3.38.5

echo "==> Installing Flutter $FLUTTER_VERSION"
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter precache --ios

echo "==> Resolving Dart packages"
cd "$CI_PRIMARY_REPOSITORY_PATH/doqto_app"
flutter pub get

# Produces ios/Flutter/Generated.xcconfig and App.framework inputs. Without
# this the Xcode build fails on a missing Generated.xcconfig.
echo "==> Building iOS artefacts (signing handled by Xcode Cloud)"
flutter build ios --release --no-codesign --no-pub

echo "==> CocoaPods"
cd ios
pod install

echo "==> ci_post_clone complete"
