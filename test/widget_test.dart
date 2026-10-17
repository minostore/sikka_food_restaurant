import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('restaurant home renders order dashboard', (tester) async {
    await tester.pumpWidget(const MaaRestaurantApp(firebaseReady: false));
    await tester.pumpAndSettle();
    expect(find.text('الطلبات الجديدة'), findsOneWidget);
    expect(find.text('مطعم النخلة'), findsOneWidget);
  });
}
