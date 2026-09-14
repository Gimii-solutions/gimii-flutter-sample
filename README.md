# Gimii Flutter SDK — Sample App

Gimii displays a charitable consent pop-in on top of your app: users who
declined cookies are offered to reconsider in exchange for a donation to the
charity of their choice, funded by your ad revenue.

This repository contains:

- **a sample Flutter app** you can run right away to see the pop-in in action;
- **this guide**, describing step by step how to integrate the SDK into your
  own Flutter app.

---

## Table of contents

1. [Requirements](#1-requirements)
2. [What you need before starting](#2-what-you-need-before-starting)
3. [Run the sample app](#3-run-the-sample-app)
4. [Integrate the SDK into your app](#4-integrate-the-sdk-into-your-app)
   - [4.1 Add the dependency](#41-add-the-dependency)
   - [4.2 Android setup](#42-android-setup)
   - [4.3 iOS setup](#43-ios-setup)
   - [4.4 Initialize the SDK](#44-initialize-the-sdk)
   - [4.5 Show the pop-in](#45-show-the-pop-in)
   - [4.6 Listen to events](#46-listen-to-events)
   - [4.7 Ad targeting — required for donations](#47-ad-targeting--required-for-donations)
   - [4.8 Apps already using Didomi](#48-apps-already-using-didomi)
   - [4.9 Back button on Android](#49-back-button-on-android)
5. [How the pop-in behaves](#5-how-the-pop-in-behaves)
6. [API reference](#6-api-reference)
7. [Error codes](#7-error-codes)
8. [Test your integration](#8-test-your-integration)
9. [Troubleshooting](#9-troubleshooting)
10. [Compatibility](#10-compatibility)

---

## 1. Requirements

| | Minimum |
|---|---|
| Flutter | 3.24, with **Swift Package Manager enabled** (see [4.3](#43-ios-setup)) |
| Dart | 3.13 |
| Android | `minSdk 24`, Java 17 |
| iOS | 13.0 |
| Consent management | [Didomi](https://www.didomi.io/) |
| Ads | Google Ad Manager / AdMob |

See [Compatibility](#10-compatibility) for exact dependency versions.

## 2. What you need before starting

**Provided by Gimii:**

| Item | Example | Used for |
|---|---|---|
| Raiser ID | `raiser_xxxxxxxx` | Identifies your app on Gimii's side |
| Didomi API key | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | Consent notice |
| Didomi notice ID | `XXXXXXXX` | Consent notice |

**From your own accounts:**

| Item | Where to find it |
|---|---|
| AdMob / Ad Manager **app ID** (`ca-app-pub-…~…`) | AdMob console → App settings |
| Ad unit IDs | Your Ad Manager or AdMob account |

If your app already uses Didomi, keep your own API key and notice ID — see
[4.8](#48-apps-already-using-didomi).

---

## 3. Run the sample app

```bash
git clone <this repository>
cd gimii-flutter-sample
flutter config --enable-swift-package-manager
flutter pub get
cp .env.example .env
```

Fill in the values provided by Gimii in `.env`:

```
GIMII_RAISER_ID=raiser_xxxxxxxx
GIMII_DIDOMI_API_KEY=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
GIMII_DIDOMI_NOTICE_ID=XXXXXXXX
```

`.env` is ignored by git, so your keys stay out of version control. Then:

```bash
flutter run --dart-define-from-file=.env
```

The values are compiled into the app: after editing `.env`, stop the app and
run it again — hot reload does not pick them up.

To run from an IDE, pass the same argument:

- **VS Code**: add `"args": ["--dart-define-from-file=.env"]` to your launch
  configuration.
- **Android Studio**: *Run → Edit Configurations → Additional run args*.
- **Xcode**: run `flutter build ios --config-only --dart-define-from-file=.env`
  once before building.

The sample runs against Gimii's **staging** environment. If a value is missing,
the event log says so and the SDK is not initialized.

### What the screen shows

| Element | Purpose |
|---|---|
| **Show Gimii** | Calls `Gimii.execute()` — displays the pop-in if all conditions are met |
| **Dismiss** | Calls `Gimii.dismiss()` |
| **Ad targeting** | Displays the keys returned by `Gimii.adTargeting()` |
| **Event log** (dark panel) | Every SDK event, as it arrives. Your main debugging tool. |
| **List** + **List taps** counter | Lets you check that touches go through the pop-in's transparent areas |

### A quick tour

1. Launch the app. The log shows `initialize ✓`.
2. Tap **Show Gimii**. The Didomi consent notice appears.
3. Tap **Disagree & Close**. The Gimii pop-in appears over the app, and the log
   shows `pop-in displayed`.
4. Tap **I accept (for free)**, then pick a charity. The log shows
   `charity selected`, and a thank-you screen appears before closing on its own.
5. Tap **Ad targeting**. The log now shows the three targeting keys.

---

## 4. Integrate the SDK into your app

### 4.1 Add the dependency

In your app's `pubspec.yaml`:

```yaml
dependencies:
  gimii_flutter: ^1.0.0
```

Then run:

```bash
flutter pub get
```

The plugin brings the native Gimii SDKs and their dependencies (Didomi, Google
Mobile Ads) with it. You do not need to declare them yourself.

### 4.2 Android setup

#### a. Change the parent class of `MainActivity` — required

The native SDK needs a `FragmentActivity`. Flutter's default `FlutterActivity`
is not one, so the app **will not work** without this change.

```kotlin
// android/app/src/main/kotlin/<your/package>/MainActivity.kt

// Before
import io.flutter.embedding.android.FlutterActivity
class MainActivity : FlutterActivity()

// After
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()
```

If your `MainActivity` overrides methods such as `configureFlutterEngine`, keep
them: `FlutterFragmentActivity` exposes the same ones.

If you forget this step, `Gimii.initialize` fails with an explicit error:

```
MainActivity must extend FlutterFragmentActivity, not FlutterActivity
```

#### b. Check `minSdk`

```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        minSdk = 24
    }
}
```

#### c. Add ProGuard / R8 rules — if you minify

Release builds are minified by default. Without these rules, the app
**crashes on launch** in release mode (`Failed to create an instance of
androidx.work.impl.WorkDatabase`), while debug builds work fine.

In `android/app/proguard-rules.pro` (create the file if needed):

```proguard
-keep class fr.gimii.** { *; }
-keep class androidx.work.** { *; }
```

And reference it in `android/app/build.gradle.kts`:

```kotlin
android {
    buildTypes {
        release {
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

The sample app already contains this configuration.

### 4.3 iOS setup

#### a. Enable Swift Package Manager — required

The iOS SDK is distributed through Swift Package Manager.

```bash
flutter config --enable-swift-package-manager
```

This is a one-time, machine-wide setting. Your team members and your CI need it
too.

#### b. Check the deployment target — iOS 13 or later

The SDK requires iOS 13 or later; recent Flutter templates already target a
higher version. To check, open `ios/Runner.xcworkspace` in Xcode, select the
**Runner** target, then look at **General → Minimum Deployments**.

If the target is too low, the build fails with a clear message:

```
The package product 'gimii-flutter' requires minimum platform version 13.0
for the iOS platform, but this target supports 12.0
```

#### c. Declare your AdMob app ID — required

In `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

> **This key is mandatory even if your app does not display ads.** The Gimii SDK
> relies on Google Mobile Ads, which checks for this key on launch and **crashes the
> app immediately** if it is missing:
>
> ```
> *** Terminating app due to uncaught exception 'GADInvalidInitializationException'
> ```
>
> This crash happens before Flutter starts, so no error can be caught or
> displayed at runtime.

#### d. Recommended: fail the build instead of crashing

Because the missing key can only be detected by crashing, we recommend checking
it at build time. In Xcode, select the **Runner** target → **Build Phases** →
**+** → **New Run Script Phase**, move it before **Compile Sources**, and paste:

```sh
PLIST="${SRCROOT}/Runner/Info.plist"
ID=$(/usr/libexec/PlistBuddy -c "Print :GADApplicationIdentifier" "$PLIST" 2>/dev/null)
if [ -z "$ID" ]; then
  echo "error: GADApplicationIdentifier is missing from Runner/Info.plist."
  exit 1
fi
case "$ID" in
  ca-app-pub-*~*) : ;;
  *) echo "error: GADApplicationIdentifier is malformed (\"$ID\")."; exit 1 ;;
esac
```

The build now stops with a readable error when the key is missing or still a
placeholder. The sample app already contains this build phase.

### 4.4 Initialize the SDK

Call `Gimii.initialize` **once**, as early as possible — typically in the
`initState` of your first screen.

```dart
import 'package:gimii_flutter/gimii_flutter.dart';

await Gimii.initialize(
  raiserId: 'YOUR_RAISER_ID',
  didomiApiKey: 'YOUR_DIDOMI_API_KEY',
  didomiNoticeId: 'YOUR_DIDOMI_NOTICE_ID',
);
```

To keep these values out of your source code, read them with
`String.fromEnvironment` and pass `--dart-define-from-file`, as the sample does
in `lib/main.dart`.

All parameters:

| Parameter | Default | Description |
|---|---|---|
| `raiserId` | — | **Required.** Your Gimii raiser ID. |
| `didomiApiKey` | `null` | Required when `initializesDidomi` is `true`. |
| `didomiNoticeId` | `null` | Required when `initializesDidomi` is `true`. |
| `environment` | `production` | `production`, `staging` or `qa`. Use `staging` while integrating. |
| `initializesDidomi` | `true` | Set to `false` if your app already initializes Didomi. See [4.8](#48-apps-already-using-didomi). |
| `dismissOnBackPressed` | `true` | Android only. See [4.9](#49-back-button-on-android). |
| `debug` | `false` | Prints each SDK step to the native console. Turn it off in production. |

When `initializesDidomi` is `true`, the SDK initializes both Didomi and Google
Mobile Ads for you.

### 4.5 Show the pop-in

```dart
await Gimii.execute();
```

`execute` does not force the pop-in to appear. It asks the SDK to **decide**:
the pop-in is displayed only if every condition is met — the SDK is enabled,
a consent status exists, your raiser configuration is valid, and the display
delay has elapsed. When a condition is not met, nothing is displayed. Network,
configuration and consent errors emit a `GimiiFailed` event; display delays do
not (see [Error codes](#7-error-codes)).

Call it where you want the pop-in to be able to appear, typically once the
user reaches your main screen:

```dart
@override
void initState() {
  super.initState();
  Gimii.events.listen(_onGimiiEvent); // subscribe first, see 4.6
  _startGimii();
}

Future<void> _startGimii() async {
  await Gimii.initialize(
    raiserId: 'YOUR_RAISER_ID',
    didomiApiKey: 'YOUR_DIDOMI_API_KEY',
    didomiNoticeId: 'YOUR_DIDOMI_NOTICE_ID',
  );
  await Gimii.execute();
}
```

If the user has not answered the Didomi notice yet, the SDK first displays it,
waits for the answer, then continues.

### 4.6 Listen to events

**Subscribe to `Gimii.events` before calling `execute`.** The SDK does not
throw when it decides not to display the pop-in: events are often the only way
to know what happened.

Events are sealed types, so the compiler warns you about unhandled cases:

```dart
void _onGimiiEvent(GimiiEvent event) {
  switch (event) {
    case GimiiDisplayed():
      // The pop-in is visible.
      break;

    case GimiiAccepted():
      // The user picked a charity. Ad targeting keys are now available:
      // refresh your ads so they include them (see 4.7).
      break;

    case GimiiRefused():
      // The user declined.
      break;

    case GimiiFailed(:final error):
      // A real failure: log it and report it to Gimii if it persists.
      debugPrint('Gimii failed: ${error.code} — ${error.cause}');
  }
}
```

Every failure carries a `GimiiErrorCode`, identical on Android and iOS. See
[Error codes](#7-error-codes).

### 4.7 Ad targeting — required for donations

**Without this step, no donation is attributed to the user's charity.**

Gimii identifies the chosen charity through three custom targeting keys that
must be attached to your ad requests. Since Flutter builds ad requests in Dart,
you have to pass them explicitly.

```dart
final Map<String, String> tags = await Gimii.adTargeting();
```

`tags` contains:

| Key | Value |
|---|---|
| `gimii` | your raiser ID |
| `gimii-asso` | the charity chosen by the user |
| `gimii-cr` | both, joined with a dash |

The map is **empty until the user has picked a charity**. Fetch it right before
building each ad request, rather than once at startup.

Example with [google_mobile_ads](https://pub.dev/packages/google_mobile_ads):

```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gimii_flutter/gimii_flutter.dart';

Future<AdManagerBannerAd> loadBanner() async {
  final tags = await Gimii.adTargeting();

  final banner = AdManagerBannerAd(
    adUnitId: '/1234567/your_ad_unit',
    sizes: const [AdSize.banner],
    request: AdManagerAdRequest(customTargeting: tags),
    listener: AdManagerBannerAdListener(
      onAdFailedToLoad: (ad, error) => ad.dispose(),
    ),
  );

  await banner.load();
  return banner;
}
```

If you already pass your own custom targeting, merge both maps:

```dart
AdManagerAdRequest(customTargeting: {...yourTargeting, ...tags});
```

> On iOS, use `google_mobile_ads` 8.0 or later. See
> [Compatibility](#10-compatibility).

### 4.8 Apps already using Didomi

If your app already initializes Didomi and displays its consent notice, tell the
SDK not to do it again:

```dart
await Gimii.initialize(
  raiserId: 'YOUR_RAISER_ID',
  initializesDidomi: false,
);
```

The SDK then leaves your Didomi setup untouched and only reads the consent
status. Make sure Didomi is initialized **before** calling `Gimii.execute()`.

In that mode, Google Mobile Ads is not initialized by the SDK either — your app
remains in charge of it.

### 4.9 Back button on Android

While the pop-in is displayed, the system back button closes it instead of
navigating back in your app. Once the pop-in is closed, the back button behaves
normally again.

To handle the back button yourself:

```dart
await Gimii.initialize(
  raiserId: 'YOUR_RAISER_ID',
  didomiApiKey: 'YOUR_DIDOMI_API_KEY',
  didomiNoticeId: 'YOUR_DIDOMI_NOTICE_ID',
  dismissOnBackPressed: false,
);
```

iOS has no system back button, so this option has no effect there.

---

## 5. How the pop-in behaves

### Display modes

| Mode | When | Behavior |
|---|---|---|
| **Default** | First display to a user who declined consent | Full-screen **modal**: a dimmed overlay covers the app and captures touches. The user must answer. |
| **Thanks** | Right after the user picked a charity | Thank-you message, closes automatically after a few seconds. |
| **Remind** | Later sessions, for a user who already supports a charity | A compact panel at the bottom of the screen, **without overlay**: the rest of the app stays usable, and touches and scrolling go through. |

The pop-in is rendered in a transparent web view layered over your Flutter
content. In **Remind** mode, only its visible parts capture touches.

### Display frequency

The pop-in is **not** shown on every call to `execute`. Display delays
("capping") are configured by Gimii for your raiser. When the delay has not
elapsed, `execute` does nothing and emits no event. On Android,
`Gimii.lastError()` then returns an error whose `isCapping` is `true`.

This means that while testing, **the pop-in will usually not reappear on a
second try**. See [Test your integration](#8-test-your-integration).

---

## 6. API reference

### `Gimii`

| Member | Description |
|---|---|
| `Gimii.initialize({...})` | Configures the SDK. Call once. See [4.4](#44-initialize-the-sdk). |
| `Gimii.execute()` | Asks the SDK to display the pop-in if conditions are met. |
| `Gimii.show()` | Shows the pop-in again after it was dismissed. |
| `Gimii.dismiss()` | Closes the pop-in. |
| `Gimii.adTargeting()` | Returns the ad targeting keys. Empty until a charity is chosen. |
| `Gimii.lastError()` | Returns the last `GimiiError`, including errors that are not emitted as events (such as display delays), or `null`. **Android only** — always `null` on iOS. |
| `Gimii.events` | `Stream<GimiiEvent>` of SDK events. |

### `GimiiEvent`

| Type | Meaning |
|---|---|
| `GimiiDisplayed` | The pop-in is displayed. |
| `GimiiAccepted` | The user picked a charity. |
| `GimiiRefused` | The user declined. |
| `GimiiFailed` | The SDK did not display the pop-in. Carries a `GimiiError`. |

### `GimiiError`

| Field | Description |
|---|---|
| `code` | A `GimiiErrorCode`. |
| `cause` | Underlying message when available (network or decoding error), otherwise `null`. |
| `raw` | Raw platform description, useful in bug reports. |
| `isCapping` | `true` when the failure is only a display delay not yet elapsed. |

### `GimiiEnvironment`

`production` (default), `staging`, `qa`.

---

## 7. Error codes

Only `bootstrap`, `noBootstrapData`, `raiserConfig`, `noRaiserConfig`,
`invalidRaiserId`, `invalidConsent` and `sendInteraction` are emitted as
`GimiiFailed` events, on both platforms. The other codes are only available
through `Gimii.lastError()`, on Android.

| `GimiiErrorCode` | Meaning | What to do |
|---|---|---|
| `noCmpConsent` | No consent status has been collected yet. | Make sure the Didomi notice is displayed and answered before `execute`. |
| `invalidConsent` | A consent status exists but does not allow display. | Expected for some users. Nothing to do. |
| `cappingPrimary` | First display delay not elapsed. | Expected. See [Display frequency](#display-frequency). |
| `cappingSecondary` | Subsequent display delay not elapsed. | Expected. |
| `cappingRemind` | Reminder delay not elapsed. | Expected. |
| `bootstrap` | Could not reach or read Gimii's service. | Check network connectivity. `cause` has details. |
| `noBootstrapData` | Gimii's service returned no usable data. | Retry later; contact Gimii if it persists. |
| `raiserConfig` | Could not load your raiser configuration. An unknown raiser ID gives an HTTP 404 here. | Check `raiserId` and `environment`. `cause` has details. |
| `noRaiserConfig` | Your raiser configuration is empty. | Contact Gimii. |
| `invalidRaiserId` | The raiser ID is unknown. | Check `raiserId` and that it matches the `environment`. |
| `sdkDisabled` | The SDK is disabled on Gimii's side. | Contact Gimii. |
| `appDisabled` | The app is disabled on Gimii's side. | Contact Gimii. |
| `noAssociation` | No charity has been chosen. | Expected before the user's first choice. |
| `sendInteraction` | An interaction could not be sent to Gimii. | Usually transient. `cause` has details. |
| `unknown` | Unrecognized code. | Report `raw` to Gimii. |

---

## 8. Test your integration

### The expected flow

Start from a **fresh install**, so that no consent or display delay is stored:

```bash
# Android
adb shell pm clear <your.application.id>

# iOS simulator
xcrun simctl uninstall booted <your.bundle.id>
```

Then, with `environment: GimiiEnvironment.staging` and `debug: true`:

| Step | Expected result |
|---|---|
| 1. Launch the app | `Gimii.initialize` completes without error |
| 2. Call `Gimii.execute()` | The Didomi notice appears |
| 3. Choose **Disagree & Close** | The Gimii pop-in appears — `GimiiDisplayed` |
| 4. Choose **I accept (for free)**, then a charity | `GimiiAccepted`, thank-you screen, then it closes on its own |
| 5. Call `Gimii.adTargeting()` | Returns `gimii`, `gimii-asso` and `gimii-cr` |
| 6. Load an ad | Your ad request contains the three keys |
| 7. *(Android)* Show the pop-in and press **Back** | The pop-in closes; your app stays on the same screen |

### Reading the native logs

With `debug: true`, the SDK prints each step. A successful display looks like
this:

```
✅ Start Gimii, App version: …
➡️ Step - checkCmpConsent
➡️ Check CMP - user refused cmp consent
➡️ Step - Fetch Config
✅⏱️ Primary Capping Reached
ℹ️ Display Gimii Webview with URL: …
```

**The step where the sequence stops tells you what is blocking.** Logs appear in
`adb logcat` on Android and in the Xcode console on iOS.

### Before going live

- [ ] `environment` is `production` (or omitted)
- [ ] `debug` is `false` (or omitted)
- [ ] `raiserId` is your production raiser ID
- [ ] `GADApplicationIdentifier` is your real AdMob app ID
- [ ] Ad requests include `Gimii.adTargeting()`
- [ ] A **release** build has been tested on Android (ProGuard rules)
- [ ] The app has been tested on a real iOS device

---

## 9. Troubleshooting

**Sample app: the log says the configuration is missing.**
`.env` is not being read. Check that it exists next to `pubspec.yaml`, then stop
the app and run `flutter run --dart-define-from-file=.env`.

**Nothing is displayed.**
Subscribe to `Gimii.events` and look for a `GimiiFailed` event: its
[error code](#7-error-codes) usually explains it. Display delays emit no event:
on Android, check `Gimii.lastError()`. Then enable `debug: true` and follow the
log sequence from [section 8](#reading-the-native-logs).

**The pop-in appeared once, then never again.**
This is the display delay, not a bug. Reinstall the app or clear its data, then
restart it — clearing data alone is not enough while the app is still running.

**iOS: the app crashes immediately on launch.**
`GADApplicationIdentifier` is missing from `Info.plist`. See
[4.3 c](#c-declare-your-admob-app-id--required).

**iOS: `requires minimum platform version 13.0`.**
Raise the deployment target. See [4.3 b](#b-check-the-deployment-target--ios-13-or-later).

**iOS: package resolution fails.**
Check that Swift Package Manager is enabled (`flutter config
--enable-swift-package-manager`), then check [Compatibility](#10-compatibility)
for conflicting Didomi or Google Mobile Ads versions.

**iOS: unexpected Xcode errors after changing dependencies.**
Errors such as `module.modulemap has been modified` usually come from stale
build artifacts:

```bash
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
find ios -name "Package.resolved" -delete
flutter pub get
```

**Android: the app crashes on launch in release mode only.**
ProGuard rules are missing. See [4.2 c](#c-add-proguard--r8-rules--if-you-minify).

**Android: `must extend FlutterFragmentActivity`.**
See [4.2 a](#a-change-the-parent-class-of-mainactivity--required).

**Donations are not attributed.**
Your ad requests do not include the targeting keys. See
[4.7](#47-ad-targeting--required-for-donations).

**Android emulator: first attempt fails with a timeout.**
A `bootstrap` error with `SocketTimeoutException` or `UnknownHostException`
right after the emulator boots is common. Call `execute` again.

---

## 10. Compatibility

### Dependencies brought by the SDK

| | Android | iOS |
|---|---|---|
| Gimii native SDK | `1.1.0-beta5` | `1.1.0-beta4` |
| Didomi | `2.26.0` or higher | `2.30.0` up to `3.0.0` (excluded) |
| Google Mobile Ads | `play-services-ads 23.5.0` or higher | `12.0.0` up to `14.0.0` (excluded) |

On **Android**, Gradle resolves the highest requested version, so the SDK
coexists with the versions your app already uses.

On **iOS**, Swift Package Manager picks a single version within these ranges.
**If your app requires a version of Didomi or Google Mobile Ads outside them,
package resolution fails.**

### With google_mobile_ads

| `google_mobile_ads` | iOS result |
|---|---|
| 8.0 and later | ✅ Supported (tested with 9.1.0, which brings Google Mobile Ads 13) |
| Before 8.0 | ❌ Not supported: these versions ship Google Mobile Ads through CocoaPods |

On Android, no conflict is expected since Gradle resolves the highest version
of each dependency.

---

## Support

For any question about your raiser configuration or the integration, contact
Gimii.
