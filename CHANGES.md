# Change Log - MFM Triumphant Church App

## Project Information
- **Package ID:** com.covenantofmercy.app
- **App Name:** MFM Triumphant Church
- **Version:** 3.29.0
- **Last Updated:** February 7, 2026

---

## Change History

### February 7, 2026 - Radio Card Removal
**Changes Made:**
- Removed Radio card from home page
- Updated `lib/screens/Home.dart`:
  - Removed `Radios` model import
  - Removed `RADIO` from `HomeIndex` enum
  - Removed Radio `ItemTile` widget from second row
  - Added `Spacer()` widget for proper layout alignment
  - Removed Radio navigation handlers from both switch statements (lines ~605 and ~733)

**Layout Changes:**
- Row 1: Categories, Videos, Audios (3 cards)
- Row 2: Bible, Livestreams (2 cards with spacer)

**Status:** ✅ Completed - No build generated (as requested)

---

### February 7, 2026 - WebView URL Bar Removal
**Changes Made:**
- Implemented in-app WebView without URL bar to replace FlutterWebBrowser

**Files Created:**
- `lib/screens/WebViewScreen.dart` - Custom WebView screen with:
  - WebViewController for page loading
  - NavigationDelegate for progress tracking
  - Custom AppBar showing page title only
  - Loading indicator during page load
  - No URL display anywhere

**Files Modified:**
- `lib/models/ScreenArguements.dart`:
  - Added `url` property (String?)
  - Added `title` property (String?)
  - Updated constructor with new parameters

- `lib/MyApp.dart`:
  - Imported `WebViewScreen`
  - Added WebViewScreen route to `onGenerateRoute` method
  - Route extracts url and title from ScreenArguements

- `lib/screens/DrawerScreen.dart`:
  - Replaced `FlutterWebBrowser` import with `WebViewScreen`
  - Added `ScreenArguements` import
  - Updated `openBrowserTab()` method to use Navigator.pushNamed with WebViewScreen
  - Affected menu items: Privacy Policy, Terms, About

- `lib/screens/Home.dart`:
  - Replaced `FlutterWebBrowser` import with `WebViewScreen`
  - Updated `openBrowserTab()` signature to accept optional title parameter
  - Added meaningful titles for all web links:
    - Website: "Website"
    - Donate: "Donate"
    - Facebook: "Facebook"
    - YouTube: "YouTube"
    - Twitter: "Twitter"
    - Instagram: "Instagram"

**Build Status:**
- ✅ APK built successfully: 85.1 MB
- ✅ Automatically installed to device: TECNO KM7 (151923756N009870)
- Build location: `build\app\outputs\flutter-apk\app-release.apk`

**User Impact:**
- Privacy Policy, Terms, and About pages now open in-app
- Social media links open in-app with custom titles
- URL "dashboard.mychurchapp.xyz" no longer visible to users
- Cleaner, more professional appearance

---

### Earlier: Translation File Regeneration
**Changes Made:**
- Regenerated `lib/i18n/strings.g.dart` using `dart run fast_i18n`
- Fixed app name display from "MyChurch App" to "MFM Triumphant Church" in all screens

**Status:** ✅ Completed

---

### Earlier: Build Configuration Updates
**Changes Made:**

**Android Build System:**
- `android/settings.gradle`:
  - Updated AGP from 8.1.0 to 8.7.0
  - Updated Kotlin from 1.9.0 to 2.1.0
  - Updated Gradle from 8.6 to 8.7

- `android/app/build.gradle`:
  - Updated NDK from 26.1.10909125 to 27.0.12077973
  - Changed signingConfig from release to debug (keystore missing)
  - Updated namespace to `com.covenantofmercy.app`
  - Updated applicationId to `com.covenantofmercy.app`

**Theme Fixes:**
- `lib/utils/app_themes.dart`:
  - Fixed deprecated DialogTheme → DialogThemeData
  - Fixed deprecated CardTheme → CardThemeData
  - Fixed deprecated BottomAppBarTheme → BottomAppBarThemeData

**Dependencies:**
- `pubspec.yaml`:
  - Added `value_layout_builder: ^0.5.0` to dependency_overrides

**Compliance:**
- ✅ Verified 16KB page size support (automatic with AGP 8.1+ and targetSdk 35)

**Status:** ✅ Completed

---

### Earlier: App Rebranding
**Changes Made:**

**Localization Files:**
- `lib/i18n/strings.i18n.json` (English)
- `lib/i18n/strings_es.i18n.json` (Spanish)
- `lib/i18n/strings_fr.i18n.json` (French)
- `lib/i18n/strings_pt.i18n.json` (Portuguese)
- All updated with: `"appname": "MFM Triumphant Church"`

**Android Configuration:**
- `android/app/build.gradle`:
  - namespace: `com.covenantofmercy.app`
  - applicationId: `com.covenantofmercy.app`

- `android/app/src/main/AndroidManifest.xml`:
  - package: `com.covenantofmercy.app`
  - android:label: "MFM Triumphant Church"

**Java Package Structure:**
- Moved from: `android/app/src/main/java/apps/envisionapps/churchapp_flutter/`
- Moved to: `android/app/src/main/java/com/covenantofmercy/app/`
- Files updated:
  - MainActivity.java
  - Application.java
  - FirebaseCloudMessagingPluginRegistrant.java
- Updated package declarations: `package com.covenantofmercy.app;`

**iOS Configuration:**
- `ios/Runner.xcodeproj/project.pbxproj`:
  - PRODUCT_BUNDLE_IDENTIFIER: `com.covenantofmercy.app`
  - INFOPLIST_KEY_CFBundleDisplayName: "MFM Triumphant Church"

- `ios/Runner/Info.plist`:
  - CFBundleName: "MFM Triumphant Church"

**Status:** ✅ Completed

---

## Build Summary

**Latest Successful Build:**
- Date: February 7, 2026, 3:45 PM
- APK Size: 85.1 MB
- Build Type: Release
- Target Device: TECNO KM7 (151923756N009870)
- Build Time: ~21 minutes
- Status: ✅ Successfully installed and running

**Build Optimizations:**
- Font tree-shaking enabled (99.3% size reduction for icons)
- LineAwesome.ttf: 387,248 → 2,868 bytes
- CupertinoIcons.ttf: 257,628 → 1,920 bytes
- MaterialIcons-Regular.otf: 1,645,184 → 18,668 bytes
- fa-regular-400.ttf: 67,976 → 1,272 bytes

---

## Known Issues
None at this time.

---

## Pending Tasks
None at this time.

---

## Technical Notes

**Package ID History:**
- Old: `apps.envisionapps.churchapp_flutter`
- New: `com.covenantofmercy.app`

**Keystore Configuration:**
- Currently using debug signing (release keystore not available)
- Previous keystore path: `/Users/envisionapps/Documents/projects/keys/appkey`
- Action Required: Provide release keystore for production builds

**Flutter Environment:**
- Flutter SDK: 3.x
- Dart SDK: >=2.17.0 <3.0.0
- Target Platform: Android (compileSdk 35, targetSdk 35)

**Dependencies Overview:**
- webview_flutter: 4.10.0 (for in-app browser)
- firebase_core: 2.32.0 (backend services)
- provider: 6.1.4 (state management)
- just_audio: 0.9.46 (audio playback)
- sqflite: 2.3.2 (local database)
- fast_i18n: 5.12.6 (internationalization)
