import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oral_health_ai/app.dart';
import 'package:oral_health_ai/screens/auth/sign_in_screen.dart';
import 'package:oral_health_ai/screens/auth/sign_up_screen.dart';
import 'package:oral_health_ai/screens/home_screen.dart';
import 'package:oral_health_ai/screens/compare_scans_screen.dart';
import 'package:oral_health_ai/screens/result_detail_screen.dart';
import 'package:oral_health_ai/models/scan_item.dart';
import 'package:oral_health_ai/models/scan_result_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  testWidgets('App starts with sign-in when there is no saved session', (tester) async {
    await tester.pumpWidget(const OraQApp());
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final screen in [const SignInScreen(), const SignUpScreen()]) {
    testWidgets('${screen.runtimeType} scrolls when the keyboard reduces height', (tester) async {
      viewport(tester, const Size(390, 400));
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Twenty scans scroll and the last record is reachable', (tester) async {
    viewport(tester, const Size(390, 844));
    SharedPreferences.setMockInitialValues({'access_token': 'test-only'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byTooltip('Delete scan 20'), 500);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete scan 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => http.Response(jsonEncode({
      'total_scans': 20,
      'recent_scans': List.generate(20, (i) => {
        'scan_id': i + 1, 'date': '2026-10-18', 'prob_percent': 10,
        'level': 'Normal', 'summary': 'Normal model score',
      }),
    }), 200)));
  });
  testWidgets('Comparison uses two saved scores', (tester) async {
    viewport(tester, const Size(390, 600));
    final scans = [
      const ScanItem(scanId: 2, date: '2026-10-18', riskPercent: 35.5, riskLevel: RiskLevel.caution, summary: ''),
      const ScanItem(scanId: 1, date: '2026-10-17', riskPercent: 10, riskLevel: RiskLevel.normal, summary: ''),
    ];
    await tester.pumpWidget(MaterialApp(home: CompareScansScreen(scans: scans)));
    expect(find.textContaining('+25.50 percentage points'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Legacy fabricated findings and tooth map are not displayed', (tester) async {
    final result = ScanResultData.fromDetailResponse({
      'probability': 10, 'status_labels': 'Normal',
      'details': {'gums': 'Healthy', 'plaque': 'Moderate'}, 'advice_list': ['General guidance'],
    });
    await tester.pumpWidget(MaterialApp(home: ResultDetailScreen(result: result)));
    expect(find.text('Healthy'), findsNothing);
    expect(find.text('Moderate'), findsNothing);
    expect(find.textContaining('not assessed'), findsOneWidget);
  });
  testWidgets('Expired saved session clears token and returns to sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'expired'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const OraQApp());
      await tester.pumpAndSettle();
      expect(find.text('Sign In'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('access_token'), isNull);
    }, () => MockClient((request) async => http.Response('{"detail":"Expired"}', 401)));
  });
  testWidgets('Network failure preserves session and offers retry', (tester) async {
    SharedPreferences.setMockInitialValues({'access_token': 'saved'});
    await http.runWithClient(() async {
      await tester.pumpWidget(const OraQApp());
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('access_token'), 'saved');
    }, () => MockClient((request) async => throw http.ClientException('offline')));
  });
}
