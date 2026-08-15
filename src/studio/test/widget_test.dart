// 量潮机密云客户端冒烟测试。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studio/app_state.dart';
import 'package:studio/main.dart';
import 'package:studio/ui/settings_page.dart';
import 'package:studio/ui/unlock_page.dart';

void main() {
  testWidgets('启动进入登录页（未登录不出现主密码/恢复码）', (WidgetTester tester) async {
    await tester.pumpWidget(SecretApp(state: AppState()));
    expect(find.text('量潮机密云'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    // 登录页只应有账号/账号密码，不应出现解锁凭据
    expect(find.text('主密码（本地解密，永不传输）'), findsNothing);
    expect(find.text('恢复码（Emergency Kit）'), findsNothing);
  });

  testWidgets('登录后直接进入列表页（先见资源，无需先解锁）', (WidgetTester tester) async {
    final state = AppState();
    // 模拟已登录：直接注入会话态（不经网络）
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSetLoggedIn();
    await tester.pumpWidget(SecretApp(state: state));
    // 列表页立即可见，且不解锁也能看到资源清单提示
    expect(find.text('我的密码'), findsOneWidget);
    expect(find.text('暂无条目，点击右下角新建'), findsOneWidget);
    // 解锁页不应自动出现（按需解锁）
    expect(find.text('主密码（本地解密，永不传输）'), findsNothing);
    expect(find.text('恢复码（Emergency Kit）'), findsNothing);
  });

  testWidgets('解锁页（按需弹出）只包含主密码与恢复码，不含账号密码与地址', (WidgetTester tester) async {
    final state = AppState();
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
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('切换账号'), findsOneWidget);
  });

  testWidgets('设置页：未解锁提示去解锁，恢复码生成器可用', (WidgetTester tester) async {
    final state = AppState();
    // ignore: invalid_use_of_visible_for_testing_member
    state.debugSetLoggedIn();
    await tester.pumpWidget(MaterialApp(home: SettingsPage(state: state)));
    // 未解锁：提示去解锁，不显示修改密钥表单
    expect(find.text('去解锁'), findsOneWidget);
    expect(find.text('新主密码（≥8 位）'), findsNothing);
    // 恢复码生成器
    await tester.tap(find.text('生成恢复码'));
    await tester.pump();
    expect(find.text('重新生成'), findsOneWidget);
    expect(find.text('复制恢复码'), findsOneWidget);
  });
}
