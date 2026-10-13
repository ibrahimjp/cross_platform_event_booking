import 'package:flutter/material.dart';

import 'core/session.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session()..restore();
  runApp(AdminApp(session: session));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'EventBook Admin',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => switch (session.status) {
            SessionStatus.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
            SessionStatus.signedOut => const LoginScreen(),
            SessionStatus.signedIn => const AdminShell(),
          },
        ),
      ),
    );
  }
}

class SessionScope extends InheritedWidget {
  const SessionScope({super.key, required this.session, required super.child});

  final Session session;

  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.session;

  @override
  bool updateShouldNotify(SessionScope oldWidget) => session != oldWidget.session;
}
