import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atmosphere_app/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AtmosphereApp()),
    );
    await tester.pumpAndSettle();

    // App should render without crashing
    expect(find.byType(AtmosphereApp), findsOneWidget);
  });
}
