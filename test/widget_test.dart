// 小宠习惯 · 基础冒烟测试
//
// 校验 App 能在测试环境中完成首帧构建。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_habit/main.dart';

void main() {
  testWidgets('App 可构建', (WidgetTester tester) async {
    await tester.pumpWidget(const PetHabitApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
