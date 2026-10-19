import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_stream/core/theme/app_theme.dart';
import 'package:study_stream/shared/widgets/study_animated_list.dart';

void main() {
  testWidgets('insertion fades in; removal disables input and reaches empty', (
    tester,
  ) async {
    final rows = ValueNotifier([const _Row('a', 'First note')]);
    addTearDown(rows.dispose);
    var taps = 0;
    await _pumpList(tester, rows, onTap: () => taps++);
    expect(_opacity(tester, 'a'), 1);

    rows.value = [...rows.value, const _Row('b', 'New bookmark')];
    await tester.pump();
    expect(_opacity(tester, 'b'), 0);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacity(tester, 'b'), allOf(greaterThan(0), lessThan(1)));
    await tester.tap(find.text('New bookmark'));
    expect(taps, 1);
    await tester.pumpAndSettle();

    rows.value = [];
    await tester.pump();
    expect(find.text('No saved entries'), findsNothing);
    final removed = find
        .ancestor(
          of: find.text('First note'),
          matching: find.byType(IgnorePointer),
        )
        .first;
    expect(tester.widget<IgnorePointer>(removed).ignoring, isTrue);
    final focus = find
        .ancestor(
          of: find.text('First note'),
          matching: find.byType(ExcludeFocus),
        )
        .first;
    expect(tester.widget<ExcludeFocus>(focus).excluding, isTrue);
    await tester.pump(const Duration(milliseconds: 80));
    expect(_opacity(tester, 'a'), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(find.text('No saved entries'), findsOneWidget);
    expect(find.text('First note'), findsNothing);
    expect(taps, 1);
  });

  testWidgets('rapid remove and reinsert keeps the latest content', (
    tester,
  ) async {
    final rows = ValueNotifier([const _Row('a', 'Original')]);
    addTearDown(rows.dispose);
    await _pumpList(tester, rows);
    rows.value = [];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    rows.value = [const _Row('a', 'Edited note')];
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Edited note'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
    expect(_opacity(tester, 'a'), 1);

    // Disposing during another removal must cancel cleanup work.
    rows.value = [];
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion updates immediately, including during removal', (
    tester,
  ) async {
    final rows = ValueNotifier([const _Row('a', 'Note')]);
    final reduceMotion = ValueNotifier(false);
    addTearDown(rows.dispose);
    addTearDown(reduceMotion.dispose);
    await _pumpList(tester, rows, reduceMotion: reduceMotion);
    rows.value = [];
    await tester.pump();
    reduceMotion.value = true;
    await tester.pump();
    expect(find.text('Note'), findsNothing);
    expect(find.text('No saved entries'), findsOneWidget);
    rows.value = [const _Row('b', 'Bookmark')];
    await tester.pump();
    expect(_opacity(tester, 'b'), 1);
    rows.value = [];
    await tester.pump();
    expect(find.text('Bookmark'), findsNothing);
    expect(find.text('No saved entries'), findsOneWidget);
  });

  testWidgets('edits retain scroll and offscreen removals still reach empty', (
    tester,
  ) async {
    final rows = ValueNotifier([
      for (var i = 0; i < 60; i++) _Row('$i', 'Note $i'),
    ]);
    addTearDown(rows.dispose);
    await _pumpList(tester, rows);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = position.position.pixels;
    expect(offset, greaterThan(0));
    rows.value = [
      for (final row in rows.value) _Row(row.id, 'Edited ${row.title}'),
    ];
    await tester.pump();
    expect(position.position.pixels, offset);
    rows.value = [];
    await tester.pumpAndSettle();
    expect(find.text('No saved entries'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Row {
  const _Row(this.id, this.title);
  final String id;
  final String title;
}

double _opacity(WidgetTester tester, String id) => tester
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(ValueKey<Object>(id)),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

Future<void> _pumpList(
  WidgetTester tester,
  ValueNotifier<List<_Row>> rows, {
  VoidCallback? onTap,
  ValueNotifier<bool>? reduceMotion,
}) async {
  Widget content(bool disabled) => MediaQuery(
    data: MediaQueryData(disableAnimations: disabled),
    child: ValueListenableBuilder(
      valueListenable: rows,
      builder: (context, value, _) => StudyAnimatedList<_Row>(
        items: value,
        itemId: (row) => row.id,
        emptyState: const Text('No saved entries'),
        itemBuilder: (context, row) => SizedBox(
          height: 80,
          child: TextButton(onPressed: onTap ?? () {}, child: Text(row.title)),
        ),
      ),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: reduceMotion == null
            ? content(false)
            : ValueListenableBuilder(
                valueListenable: reduceMotion,
                builder: (_, value, _) => content(value),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
