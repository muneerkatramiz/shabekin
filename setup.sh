#!/usr/bin/env bash
# One-time project setup. Run from this folder:  bash setup.sh
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null 2>&1 || { echo "Install Flutter first: https://docs.flutter.dev/get-started/install"; exit 1; }

# Generates the android/ and ios/ folders (bundle id: net.shabekin.app - permanent once published!)
flutter create --org net.shabekin --project-name app --platforms=android,ios .
rm -f test/widget_test.dart

# ---- Android ----
MAN=android/app/src/main/AndroidManifest.xml
perl -0pi -e 's/android:label="[^"]*"/android:label="شابكين"/' "$MAN"
if ! grep -q 'android.permission.INTERNET' "$MAN"; then
  perl -0pi -e 's|<application|<uses-permission android:name="android.permission.INTERNET"/>\n    <application|' "$MAN"
fi
QINT='<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent><intent><action android:name="android.intent.action.DIAL"/></intent><intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>'
if grep -q '<queries>' "$MAN"; then
  perl -0pi -e "s|<queries>|<queries>$QINT|" "$MAN"
else
  perl -0pi -e "s|</manifest>|    <queries>$QINT</queries>\n</manifest>|" "$MAN"
fi
for f in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$f" ] && perl -pi -e 's/minSdk(Version)?\s*=?\s*flutter\.minSdkVersion/minSdk = 23/' "$f"
done

# ---- iOS (macOS only) ----
PL=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy
if [ -x "$PB" ]; then
  $PB -c "Set :CFBundleDisplayName شابكين" "$PL" 2>/dev/null || $PB -c "Add :CFBundleDisplayName string شابكين" "$PL"
  $PB -c "Add :CFBundleLocalizations array" "$PL" 2>/dev/null || true
  $PB -c "Add :CFBundleLocalizations:0 string ar" "$PL" 2>/dev/null || true
  $PB -c "Add :CFBundleLocalizations:1 string en" "$PL" 2>/dev/null || true
  $PB -c "Add :NSPhotoLibraryUsageDescription string 'Choose your commercial register and license files.'" "$PL" 2>/dev/null || true
else
  echo "NOTE: not on macOS - skipping iOS Info.plist edits (see PUBLISHING.md)."
fi

flutter pub get
dart run flutter_launcher_icons
flutter analyze || true
echo "Done. Test with:  flutter run"
