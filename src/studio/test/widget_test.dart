// 量潮密码云客户端冒烟测试。
import 'package:flutter_test/flutter_test.dart';

import 'package:studio/app_state.dart';
import 'package:studio/main.dart';

void main() {
  testWidgets('启动进入解锁页', (WidgetTester tester) async {
    await tester.pumpWidget(SecretApp(state: AppState()));
    expect(find.text('量潮密码云'), findsOneWidget);
    expect(find.text('解锁'), findsOneWidget);
  });
}
