# Gimii Flutter sample

This app demonstrates the adjacent `gimii_flutter` SDK, with a native pop-in,
activity log, targeting display, reset control, and a scrolling/tap probe.
The integration reference is the
[Flutter SDK guide](https://github.com/Gimii-solutions/gimii-flutter/blob/main/README.md).

## Source dependencies

[pubspec.yaml](pubspec.yaml) selects `../gimii-flutter`, so SDK changes and this
sample are tested together. Clone that repository next to this one. The smaller
[bundled example](https://github.com/Gimii-solutions/gimii-flutter/blob/main/example/README.md)
uses the same API and configuration values.

A Dart path dependency still resolves published native SDKs unless native
source overrides are set. For this unreleased reset/embedder work, select the
adjacent native source modules before building:

```sh
export GIMII_ANDROID_SDK_PATH=/path/to/gimii-mobile/gimii-android/gimii-android
export GIMII_IOS_SDK_PATH=/path/to/gimii-mobile/gimii-ios/gimii-ios
```

To test a published plugin instead, replace the path dependency with the desired
pub.dev version, resolve packages again, and verify its native compatibility.
Do not assume an older published package contains these source changes.

## Requirements

- Flutter/Dart compatible with this app's manifest (`sdk: ^3.13.2`) and the
  selected plugin's native toolchain requirements.
- Android: a supported JDK/SDK and `FlutterFragmentActivity`. Check the selected
  native artifact's minimum API; current source builds require API 24+.
- iOS: a compatible Xcode, Swift Package Manager, and at least iOS 13 or the
  higher deployment target required by selected dependencies.
- A staging raiser ID, Didomi API key/notice ID, and your own Google Mobile Ads
  application IDs for the platforms you run.

## Configure

From this sample repository root:

```sh
cp .env.example .env
```

Fill in the three compile-time values in that file:

| Key | Meaning |
| --- | --- |
| `GIMII_RAISER_ID` | Raiser provisioned in staging |
| `GIMII_DIDOMI_API_KEY` | Didomi API key for the host app |
| `GIMII_DIDOMI_NOTICE_ID` | Didomi notice ID |

The names are defined in [.env.example](.env.example) and consumed by
[lib/main.dart](lib/main.dart) using `String.fromEnvironment`. They are passed
when building/running, not loaded automatically at runtime. Keep `.env` out of Git.

Review host-owned platform settings too:

| Platform file | Setting |
| --- | --- |
| [Android MainActivity](android/app/src/main/kotlin/fr/gimii/gimii_flutter_sample/MainActivity.kt) | Must extend `FlutterFragmentActivity` |
| [Android manifest](android/app/src/main/AndroidManifest.xml) | Declare your own Google Mobile Ads `APPLICATION_ID` metadata |
| [iOS Info.plist](ios/Runner/Info.plist) | Replace `GADApplicationIdentifier` with your own app ID |

Both platform files contain Google's test application IDs. Replace them with
your own IDs for production. If an older published SDK supplies conflicting
metadata, use the host-side merge override described in the Flutter SDK guide.
Application IDs differ from ad unit IDs.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=.env
```

For iOS, ensure Swift Package Manager is enabled. It is Flutter's default from
3.44; on earlier supported toolchains or if disabled, use:

```sh
flutter config --enable-swift-package-manager
```

See [Flutter's setup guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)
and the selected plugin's dependency constraints.

The screen initializes Gimii with staging and debug logs, subscribes to typed
events, and attempts execution only after initialization succeeds. Both platforms
wait for the initial notice answer; event subscriptions are cancelled when the
screen is disposed. Display depends
on service flags, configuration, consent, and capping; startup does not guarantee
an immediate pop-in.

## Screen controls

| Control | Behavior |
| --- | --- |
| **Run Gimii** | Executes the native eligibility flow |
| **Ad targeting** | Displays the current targeting map; empty before a charity is available |
| **Reset** | Closes Gimii, cancels pending work, clears Gimii state and Didomi consent, and clears the screen's log/tap count. Configuration is retained; use Run Gimii afterward |
| **Event log** | Shows method results, native events, and stream errors |
| Scrolling list and tap count | Helps verify touch pass-through in transparent areas |

The label in an acceptance event does not prove that a follow-up CMP flow or
charity persistence is complete. Fetch targeting after that flow finishes.
This sample does not load real ads; production hosts must attach the returned
keys to each new request using their ads plugin.

## Environment reference

| Dart value in the current SDK source | API origin | Static origin |
| --- | --- | --- |
| `dev` | `https://api.gimii.dev` | `https://static.gimii.dev` |
| `staging` | `https://api.staging.gimii.fr` | `https://static.staging.gimii.fr` |
| `production` | `https://api.gimii.fr` | `https://static.gimii.fr` |

This sample selects staging. Published native artifacts must contain these
mappings before their behavior matches the current source. A debug flag does
not switch the environment, and switching environments does not migrate local
consent/charity preferences.

## Verify the integration

1. Use a dedicated test installation with matching staging configuration.
2. Answer the initial CMP notice and execute Gimii after the answer is available.
3. Check that eligible refusal flows display a pop-in; direct full CMP consent
   should bypass the initial pop-in.
4. Complete charity selection and any follow-up CMP step. Verify the thank-you
   flow and persisted `gimii`, `gimii-asso`, and `gimii-cr` targeting values.
5. Exercise reminder minimization, scrolling, tapping, privacy preferences, and
   dismissal. Check Android Back behavior with the selected plugin.
6. Check native debug logs for states that produce no event, such as capping.
   `lastError` support and event delivery depend on the selected version; the
   current source exposes last error on Android only.

A reset/fresh install does not replace valid server configuration or guarantee
that all display delays are zero. For release verification, use production IDs,
disable debug logs, test a minified Android build, and validate an iOS device.

## Checks and troubleshooting

```sh
flutter analyze
flutter test
flutter test --dart-define=GIMII_RAISER_ID=test_raiser --dart-define=GIMII_DIDOMI_API_KEY=test_key --dart-define=GIMII_DIDOMI_NOTICE_ID=test_notice
```

Widget tests mock both native channels and cover the current Run Gimii,
Ad targeting and Reset controls, native events/errors, startup ordering, missing
configuration, failed initialization, and subscription cleanup. Mock test values
do not contact native services. Native SDK test suites belong to their own
repositories; widget tests do not validate a live consent/backend configuration.

| Symptom | Check |
| --- | --- |
| Missing configuration log | `.env` next to `pubspec.yaml`, exact key names, and `--dart-define-from-file=.env` on a fresh run |
| No display and no event | CMP readiness/answer, capping, server flags, and native logs |
| Unknown `reset` or another Dart method | Local plugin path, native source overrides, and compatible release versions |
| Minimum platform error | Selected native artifact requirements and host build settings |
| iOS package/link failure | SwiftPM, compatible native versions, host `-ObjC`, and duplicate manual package references |
| Android startup/manifest error | `FlutterFragmentActivity` and the host's own ad application ID |
| Missing targeting | Complete charity persistence and read keys again for the next request |

When reporting an issue, include the resolved package/native versions,
environment, error code/cause, and relevant logs without credentials. Start with
`flutter clean` and `flutter pub get` for stale artifacts; do not indiscriminately
remove shared Xcode caches or other applications' data.
