import 'package:flutter_test/flutter_test.dart';
import 'package:resolvedesk_mobileapp/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders ResolveDeskApp', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const ResolveDeskApp());
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byType(ResolveDeskApp), findsOneWidget);
  });
}
