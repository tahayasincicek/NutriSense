import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/dietitian/models/shared_report_history.dart';
import 'package:nutrisense/features/dietitian/widgets/report_history_section.dart';

SharedReportHistoryItem report(String status, {String? reply}) =>
    SharedReportHistoryItem(
      reportId: status,
      reportType: 'weekly',
      fromDate: DateTime(2026, 9, 1),
      toDate: DateTime(2026, 9, 7),
      recordCount: 9,
      status: status,
      createdAt: DateTime(2026, 9, 7),
      dietitianReply: reply,
      dietitianRepliedAt: reply == null ? null : DateTime(2026, 9, 7),
      channels: [
        SharedReportChannel(
            channel: 'email', status: status == 'sent' ? 'sent' : 'failed'),
        SharedReportChannel(
            channel: 'sms', status: status == 'sent' ? 'sent' : 'failed')
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('report archive layout dark=$dark scale=$scale',
          (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              fontFamily: 'Inter',
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF065F46),
                brightness: dark ? Brightness.dark : Brightness.light,
                primary:
                    dark ? const Color(0xFF86EFAC) : const Color(0xFF065F46),
              )),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                backgroundColor:
                    dark ? const Color(0xFF0F172A) : const Color(0xFFF4F7F5),
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ReportHistorySection(items: [
                      report('sent',
                          reply:
                              'Öğün düzeniniz oldukça iyi. Ara öğünlerde lif içeren besinlere de yer verelim.'),
                      report('failed'),
                      report('partial_failed'),
                    ])),
              )),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Gönderdiğim Raporlar'), findsOneWidget);
        expect(find.text('Diyetisyeninizin notu'), findsOneWidget);
        if (const bool.fromEnvironment('EXPORT_REPORT_DESIGN') && scale == 1) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                'tmp/design/report-history-${dark ? 'dark' : 'light'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
