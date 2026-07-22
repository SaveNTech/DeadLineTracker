// Smoke test: the app boots into ProviderScope + MaterialApp.router without
// throwing. Auth/API-backed screens are covered by widget tests per feature
// once a fake ApiClient/repository is wired in — see CLAUDE.md roadmap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deadline_tracker/features/auth/data/auth_repository.dart';
import 'package:deadline_tracker/features/auth/state/auth_controller.dart';
import 'package:deadline_tracker/main.dart';

/// Never touches secure storage or the network — a widget test has neither.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<bool> hasSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // Widget tests run offline; don't let GoogleFonts try to fetch over the network.
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app boots and shows a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const DeadlineTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
