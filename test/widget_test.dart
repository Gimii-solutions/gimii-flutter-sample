import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gimii_flutter_sample/main.dart';

void main() {
  const method = MethodChannel('fr.gimii/method');
  const events = MethodChannel('fr.gimii/events');
  const configured =
      String.fromEnvironment('GIMII_RAISER_ID') != '' &&
      String.fromEnvironment('GIMII_DIDOMI_API_KEY') != '' &&
      String.fromEnvironment('GIMII_DIDOMI_NOTICE_ID') != '';
  final calls = <MethodCall>[];
  final subscriptions = <String>[];
  var failInitialize = false;
  var failExecute = false;

  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    subscriptions.clear();
    failInitialize = false;
    failExecute = false;
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      if ((call.method == 'initialize' && failInitialize) ||
          (call.method == 'execute' && failExecute)) {
        throw PlatformException(
          code: 'test-failure',
          message: 'Native failure',
        );
      }
      if (call.method == 'adTargeting') {
        return {
          'gimii': 'raiser_1',
          'gimii-asso': 'asso_1',
          'gimii-cr': 'raiser_1-asso_1',
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(events, (call) async {
      subscriptions.add(call.method);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(method, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  testWidgets('starts with configuration or explains missing values', (
    tester,
  ) async {
    await tester.pumpWidget(const SampleApp());
    await tester.pumpAndSettle();
    expect(find.text('Run Gimii'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(subscriptions, ['listen']);
    if (configured) {
      expect(calls.map((c) => c.method), ['initialize', 'execute']);
      expect(calls.first.arguments['environment'], 'staging');
    } else {
      expect(calls, isEmpty);
      expect(find.textContaining('Missing configuration:'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(subscriptions, ['listen', 'cancel']);
  });

  testWidgets('controls call the SDK and display targeting and reset results', (
    tester,
  ) async {
    await tester.pumpWidget(const SampleApp());
    await tester.pumpAndSettle();
    calls.clear();
    await tester.tap(find.text('Run Gimii'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ad targeting'));
    await tester.pumpAndSettle();
    expect(find.textContaining('gimii-asso=asso_1'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(calls.map((c) => c.method), ['execute', 'adTargeting', 'reset']);
    expect(find.text('reset ✓'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('logs native events and platform errors', (tester) async {
    await tester.pumpWidget(const SampleApp());
    await tester.pumpAndSettle();
    await messenger.handlePlatformMessage(
      'fr.gimii/events',
      const StandardMethodCodec().encodeSuccessEnvelope({
        'event': 'onDisplayed',
      }),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.text('pop-in displayed'), findsOneWidget);
    failExecute = true;
    await tester.tap(find.text('Run Gimii'));
    await tester.pumpAndSettle();
    expect(find.textContaining('execute ✗ PlatformException'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  if (configured) {
    testWidgets('does not execute after initialization fails', (tester) async {
      failInitialize = true;
      await tester.pumpWidget(const SampleApp());
      await tester.pumpAndSettle();
      expect(calls.map((c) => c.method), ['initialize']);
      expect(
        find.textContaining('initialize ✗ PlatformException'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
