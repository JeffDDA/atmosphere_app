import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atmosphere_app/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Provide empty SharedPreferences for test environment
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: AtmosphereApp()),
    );
    await tester.pumpAndSettle();

    // App should render without crashing
    expect(find.byType(AtmosphereApp), findsOneWidget);
  });
}
