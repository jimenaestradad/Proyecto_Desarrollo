import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/screens/settings/settings_screen.dart';

/// Pumps a button that opens the dialog and records what it pops with.
class Harness {
  DeleteAccountRequest? result;
  bool closed = false;
}

Future<Harness> openDialog(
  WidgetTester tester, {
  required bool hasPassword,
}) async {
  final harness = Harness();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            harness.result = await showDialog<DeleteAccountRequest>(
              context: context,
              builder: (_) => DeleteAccountDialog(
                username: 'Valeria',
                hasPassword: hasPassword,
              ),
            );
            harness.closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('Cancel closes the dialog with no result', (tester) async {
    final harness = await openDialog(tester, hasPassword: true);

    await tester.tap(find.text('Cancel'));
    // Settling runs the whole close animation, which is when a text
    // controller freed too early would be used after being disposed.
    await tester.pumpAndSettle();

    expect(harness.closed, isTrue);
    expect(harness.result, isNull);
    expect(find.byType(DeleteAccountDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Delete passes back the typed password and a case-insensitive '
      'username match', (tester) async {
    final harness = await openDialog(tester, hasPassword: true);

    await tester.enterText(find.byType(TextField).first, '  vALERIA ');
    await tester.enterText(find.byType(TextField).last, 'hunter2');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(harness.result?.usernameMatches, isTrue);
    expect(harness.result?.password, 'hunter2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wrong username is reported as not matching', (tester) async {
    final harness = await openDialog(tester, hasPassword: true);

    await tester.enterText(find.byType(TextField).first, 'someone else');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(harness.result?.usernameMatches, isFalse);
  });

  testWidgets('a Google-only account sees no password field', (tester) async {
    await openDialog(tester, hasPassword: false);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('sign in with Google'), findsOneWidget);
  });
}
