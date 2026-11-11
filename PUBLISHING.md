# Shabekin app — build & publish guide

App talks to `https://shabekin.net/wp-json/shabek/v1` (change in `lib/config.dart`).

## 1) WordPress (do first)
1. Plugins → Add New → Upload `shabek-platform-1.5.0.zip` → "Replace current with uploaded". Settings and data are kept.
2. Open `https://shabekin.net/wp-json/shabek/v1/config` in a browser. You should see JSON with the 9 services.
3. Settings → Privacy: publish a privacy policy page and select it (stores require a public URL). Then open **Shabekin → Mobile App** in WP Admin to set the app banner, support email, terms URL and which pages appear in the app.
4. Make sure the site uses HTTPS and no security plugin blocks `/wp-json/`. The app sends the token in both `Authorization` and `X-Shabek-Token` because some hosts strip `Authorization`.
5. Create two test accounts for store review: a customer, and a provider (register in the app, then approve in WP Admin → Shabekin → Providers).

## 2) Build the app
```
bash setup.sh        # creates android/ios folders, icon, permissions
flutter run          # test on a real phone
```
Test: browse services → register → send request → provider (approved) sends offer → customer accepts → provider sees customer phone → delete account.

## 3) Android (Google Play)
- Create keystore: `keytool -genkey -v -keystore ~/shabekin.jks -keyalg RSA -keysize 2048 -validity 10000 -alias shabekin` (back it up — losing it = cannot update the app).
- Create `android/key.properties` (storePassword, keyPassword, keyAlias=shabekin, storeFile=/path/shabekin.jks) and wire it into `android/app/build.gradle(.kts)` `signingConfigs.release` (Flutter docs: "Build and release an Android app").
- `flutter build appbundle` → upload `build/app/outputs/bundle/release/app-release.aab`.
- Play Console ($25 one-time): store listing, screenshots, 1024×500 feature graphic, privacy policy URL, Data safety form (collects: name, email, phone, documents; account deletion supported in-app), content rating.
- Personal developer accounts must run a closed test with ~12 testers for 14 days before production; organization accounts do not.

## 4) iOS (App Store)
- Needs a Mac with Xcode and an Apple Developer account ($99/year).
- `open ios/Runner.xcworkspace` → set Team, confirm bundle id `net.shabekin.app`.
- `flutter build ipa` → upload with Transporter / Xcode Organizer.
- App Store Connect: screenshots (6.7" and 6.5"), privacy nutrition labels, privacy URL. Put the test customer + approved provider credentials in "App Review Information" — reviewers must be able to log in.
- Account deletion is built in (Account → Delete account), as Apple requires.

## Not included yet
Push notifications (needs Firebase project + keys), online payment, live tracking, an approval/rejection email to providers (currently they see status in the app), terms/privacy text.

## What syncs from WordPress
Services (names/modes), requests & statuses, provider approval, offers, vehicles, banner, extra pages, privacy/terms links. The app re-syncs when opened, every 60 s while open, and on pull-to-refresh. Instant push notifications are not included (need Firebase).

## Quick test APK without installing Flutter
Upload the contents of this folder (including `.github`) to a new GitHub repository, open Actions → "Build APK" → Run workflow. When it finishes, download `shabekin-apk` from the run page and install the APK on an Android phone. (This APK is debug-signed: for testing only, not for Google Play.)
