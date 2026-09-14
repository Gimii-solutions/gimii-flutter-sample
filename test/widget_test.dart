import 'package:flutter_test/flutter_test.dart';
import 'package:gimii_flutter_sample/main.dart';

void main() {
  testWidgets('sample screen builds', (WidgetTester tester) async {
    await tester.pumpWidget(const SampleApp());
    expect(find.text('Show Gimii'), findsOneWidget);
    expect(find.textContaining('List taps'), findsOneWidget);
  });
}
