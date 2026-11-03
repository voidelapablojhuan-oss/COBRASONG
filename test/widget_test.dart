import 'package:flutter_test/flutter_test.dart';
import 'package:cobrasong/main.dart';

void main() {
  testWidgets('COBRASONG opens the home experience', (tester) async {
    await tester.pumpWidget(const CobraSongApp());
    expect(find.text('SINTA O SOM.\\nCONECTE A GALERA.'), findsOneWidget);
    expect(find.text('Tocando no radar'), findsOneWidget);
  });
}
