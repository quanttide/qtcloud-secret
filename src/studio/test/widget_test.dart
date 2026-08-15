// 量潮密码云客户端冒烟测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio/app_state.dart';
import 'package:studio/main.dart';
import 'package:studio/ui/unlock_page.dart';

void main() {
  testWidgets('启动进入登录页（未登录不出现主密码/恢复码）', (WidgetTester tester) async {
    await tester.pumpWidget(SecretApp(state: AppState()));
    expect(find.text('量潮密码云'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    // 登录页只应有账号/账号密码，不应出现解锁凭据
    expect(find.text('主密码（本地解密，永不传输）'), findsNothing);
    expect(find.text('恢复码（Emergency Kit）'), findsNothing);
  });

  testWidgets('解锁页只包含主密码与恢复码，不含账号密码与地址', (WidgetTester tester) async {
    final state = AppState();
    // 模拟已登录：直接注入会话态（不经网络）
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSetLoggedIn();
    await tester.pumpWidget(MaterialApp(home: UnlockPage(state: state)));
    expect(find.text('解锁'), findsOneWidget);
    expect(find.text('主密码（本地解密，永不传输）'), findsOneWidget);
    expect(find.text('恢复码（Emergency Kit）'), findsOneWidget);
    // 解锁页不应出现登录凭据与服务地址
    expect(find.text('账号'), findsNothing);
    expect(find.text('账号密码'), findsNothing);
    expect(find.textContaining('服务地址'), findsNothing);
    expect(find.text('切换账号'), findsOneWidget);
  });
}
