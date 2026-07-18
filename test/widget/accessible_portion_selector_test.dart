import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/food_scan/widgets/accessible_portion_selector.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';

void main() {
  testWidgets('gerçek porsiyon bileşeni hızlı, manuel ve sesli seçim sunar',
      (tester) async {
    final fixture = jsonDecode(
      File('contracts/fixtures/food_analysis_success.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final result = FoodAnalysisResult.fromJson(fixture);
    double? selectedValue;
    String? selectedUnit;
    var manual = false;
    var voice = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: AccessiblePortionSelector(
          result: result,
          enabled: true,
          loading: false,
          onSelected: (value, unit) {
            selectedValue = value;
            selectedUnit = unit;
          },
          onManual: () => manual = true,
          onVoice: () => voice = true,
        ),
      ),
    ));

    expect(find.textContaining('Tahmini 150 g'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);
    expect(find.text('1 adet'), findsOneWidget);

    await tester.tap(find.text('100 g'));
    expect(selectedValue, 100);
    expect(selectedUnit, 'gram');
    await tester.tap(find.text('Başka'));
    await tester.tap(find.text('Sesle'));
    expect(manual, isTrue);
    expect(voice, isTrue);
  });
}
