import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilog/auth/auth_gate.dart';
import 'package:nutrilog/auth/auth_service.dart';
import 'package:nutrilog/pages/auth_page.dart';
import 'package:nutrilog/pages/settings_page.dart';

class FakeAuthService implements AuthService {
  final StreamController<bool> controller = StreamController<bool>.broadcast();
  bool signedIn;
  int signInCalls = 0;
  int signUpCalls = 0;
  int signOutCalls = 0;
  Future<void> Function()? onSignIn;
  Future<SignUpResult> Function()? onSignUp;
  Future<void> Function()? onSignOut;

  FakeAuthService({this.signedIn = false});

  @override
  Stream<bool> get authStateChanges => controller.stream;

  @override
  String? get currentUserEmail => signedIn ? 'person@example.com' : null;

  @override
  bool get hasSession => signedIn;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls += 1;
    await onSignIn?.call();
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls += 1;
    return onSignUp?.call() ??
        const SignUpResult(requiresEmailConfirmation: false);
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    await onSignOut?.call();
  }

  void emit(bool value) {
    signedIn = value;
    controller.add(value);
  }

  Future<void> dispose() => controller.close();
}

Widget testApp(Widget child) => MaterialApp(home: child);

Future<void> enterValidCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('authEmailField')),
    'person@example.com',
  );
  await tester.enterText(find.byKey(const Key('authPasswordField')), 'secret1');
}

void main() {
  testWidgets('AuthGate follows initial and changed session state', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      testApp(AuthGate(authService: auth, signedInChild: const Text('原本首頁'))),
    );
    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('原本首頁'), findsNothing);

    auth.emit(true);
    await tester.pump();
    expect(find.byType(AuthPage), findsNothing);
    expect(find.text('原本首頁'), findsOneWidget);

    auth.emit(false);
    await tester.pump();
    await tester.pump();
    expect(find.byType(AuthPage), findsOneWidget);
  });

  testWidgets('AuthGate restores an existing session immediately', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService(signedIn: true);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      testApp(AuthGate(authService: auth, signedInChild: const Text('已恢復首頁'))),
    );

    expect(find.text('已恢復首頁'), findsOneWidget);
    expect(find.byType(AuthPage), findsNothing);
  });

  testWidgets('Login validates required email and password', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('請輸入 Email。'), findsOneWidget);
    expect(find.text('請輸入密碼。'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('Login validates email format and password length', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));

    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'not-an-email',
    );
    await tester.enterText(find.byKey(const Key('authPasswordField')), '12345');
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('Email 格式不正確。'), findsOneWidget);
    expect(find.text('密碼至少需要 6 個字元。'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });

  testWidgets('Submit shows loading and prevents duplicate requests', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    final pending = Completer<void>();
    auth.onSignIn = () => pending.future;
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));
    await enterValidCredentials(tester);

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('authSubmitButton')),
    );
    expect(button.onPressed, isNull);
    expect(auth.signInCalls, 1);

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    expect(auth.signInCalls, 1);

    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Registration handles email confirmation result', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    auth.onSignUp = () async =>
        const SignUpResult(requiresEmailConfirmation: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));

    await tester.tap(find.byKey(const Key('authModeButton')));
    await tester.pump();
    expect(find.text('註冊'), findsOneWidget);
    await enterValidCredentials(tester);
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(auth.signUpCalls, 1);
    expect(find.text('註冊成功，請至信箱完成驗證後再登入。'), findsOneWidget);
    expect(find.text('登入'), findsOneWidget);
  });

  testWidgets('Registration handles immediate session result', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    auth.onSignUp = () async =>
        const SignUpResult(requiresEmailConfirmation: false);
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));

    await tester.tap(find.byKey(const Key('authModeButton')));
    await tester.pump();
    await enterValidCredentials(tester);
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(auth.signUpCalls, 1);
    expect(find.text('註冊成功，正在登入…'), findsOneWidget);
    expect(find.textContaining('註冊暫時無法完成'), findsNothing);
  });

  testWidgets('Authentication errors are shown without crashing', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    auth.onSignIn = () async => throw const AuthFailure('測試登入失敗');
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));
    await enterValidCredentials(tester);

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('測試登入失敗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Completing a request after dispose does not update state', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService();
    final pending = Completer<void>();
    auth.onSignIn = () => pending.future;
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(AuthPage(authService: auth)));
    await enterValidCredentials(tester);
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    await tester.pumpWidget(testApp(const SizedBox()));
    pending.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings signs out and handles failures', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService(signedIn: true);
    auth.onSignOut = () async => throw const AuthFailure('測試登出失敗');
    addTearDown(auth.dispose);
    await tester.pumpWidget(testApp(SettingsPage(authService: auth)));

    expect(find.text('person@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pump();

    expect(auth.signOutCalls, 1);
    expect(find.text('測試登出失敗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Successful sign-out returns to the root route', (
    WidgetTester tester,
  ) async {
    final auth = FakeAuthService(signedIn: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(authService: auth),
                ),
              ),
              child: const Text('開啟設定'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開啟設定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('signOutButton')));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('開啟設定'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
