import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_sudoku/screens/stats_screen.dart';

void main() {
  testWidgets('StatsScreen pops when swiping right on the first tab', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    // Build the StatsScreen wrapped in a Navigator so we can verify pop
    final mockObserver = MockNavigatorObserver();
    
    await tester.pumpWidget(
      MaterialApp(
        home: const StatsScreen(),
        navigatorObservers: [mockObserver],
      ),
    );

    // Verify we are on Classic Sudoku tab (index 0)
    expect(find.text('Classic Sudoku'), findsOneWidget);

    // Initial check: Navigator has pushed the route
    // Note: Since we start with Home, we expect push. but we care about Pop.
    // Actually, maybePop will be called. 
    // We can just check if the widget gets removed or we can track calls.
    
    // Let's create a simple wrapper to track pop
    bool popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
               await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
               popped = true;
            },
            child: const Text('Go to Stats'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go to Stats'));
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);

    // Perform Swipe Right on the content area (center of screen)
    // The issue description says "below the header". 
    // StatsScreen header is about 100-150px height.
    // TabBar is below that.
    // Content is below that.
    // Let's drag from center-left to center-right.
    
    await tester.dragFrom(const Offset(20, 400), const Offset(300, 400));
    await tester.pumpAndSettle();

    // Verification: StatsScreen should be gone
    expect(find.byType(StatsScreen), findsNothing);
    expect(popped, isTrue);
  });
}

class MockNavigatorObserver extends NavigatorObserver {
  // We can track pushes/pops here if needed, but the simple popped boolean wrapper is easier.
}
