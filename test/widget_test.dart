import 'package:flutter_test/flutter_test.dart';

import 'package:takemeasure/main.dart';

void main() {
  testWidgets('L\'app si avvia e mostra la schermata iniziale',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TakeMeasureApp());
    await tester.pump();

    expect(find.text('Le mie misure'), findsOneWidget);
    expect(find.text('Nuova stanza'), findsOneWidget);
  });
}
