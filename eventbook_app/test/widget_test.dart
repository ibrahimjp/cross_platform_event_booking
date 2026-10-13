import 'package:eventbook_app/providers/app_state.dart';
import 'package:eventbook_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login screen validates email and shows sign-up link', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(autoInit: false),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text('Sign Up'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });
}
