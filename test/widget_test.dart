import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cobrasong/main.dart';

void main() {
  testWidgets('COBRASONG opens the home experience', (tester) async {
    await tester.pumpWidget(const CobraSongApp());
    expect(find.text('SINTA O SOM.\nCONECTE A GALERA.'), findsOneWidget);
    expect(find.text('Tocando no radar'), findsOneWidget);
  });

  testWidgets('startup gate shows progress then opens the app', (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(
      CobraSongApp(audioInitialization: initialization.future),
    );

    expect(find.text('Preparando o COBRASONG...'), findsOneWidget);

    initialization.complete();
    await tester.pumpAndSettle();

    expect(find.text('Tocando no radar'), findsOneWidget);
  });
}
