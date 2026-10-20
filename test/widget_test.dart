import 'package:flutter_test/flutter_test.dart';
import 'package:pinterus_mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the sign-in screen and opens account registration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Belum punya akun? Daftar'), findsOneWidget);

    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();

    expect(find.text('Gabung Pinterus'), findsOneWidget);
    expect(find.text('Buat akun'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}
