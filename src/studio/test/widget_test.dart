// 量潮机密云客户端冒烟测试（服务端加密方案：登录即用）。
import 'package:flutter_test/flutter_test.dart';

import 'package:studio/app_state.dart';
import 'package:studio/main.dart';

void main() {
  testWidgets('启动进入登录页（未登录）', (WidgetTester tester) async {
    await tester.pumpWidget(SecretApp(state: AppState()));
    expect(find.text('量潮机密云'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });

  testWidgets('登录后直接进入列表页（登录即用，无解锁环节）', (WidgetTester tester) async {
    final state = AppState();
    // 模拟已登录：直接注入会话态（不经网络）
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSetLoggedIn();
    await tester.pumpWidget(SecretApp(state: state));
    // 列表页立即可见
    expect(find.text('我的密码'), findsOneWidget);
    expect(find.text('暂无条目，点击右下角新建'), findsOneWidget);
    // 不应出现任何解锁/主密码/恢复码
    expect(find.text('主密码（本地解密，永不传输）'), findsNothing);
    expect(find.text('恢复码（Emergency Kit）'), findsNothing);
    expect(find.text('解锁'), findsNothing);
  });
}
