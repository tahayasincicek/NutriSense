import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/features/discover/models/discover_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nutrisense/features/discover/screens/article_detail_screen.dart';

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
      testWidgets('recipe detail layout dark=$dark scale=$scale',
          (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(ProviderScope(
            child: MaterialApp(
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
              child: ArticleDetailScreen(
                article: discoverArticles
                    .firstWhere((a) => a.title == 'Fırında Tarçınlı Elma'),
              )),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Fırında Tarçınlı Elma'), findsNWidgets(2));
        expect(find.byKey(const Key('article_listen')), findsOneWidget);
        if (const bool.fromEnvironment('EXPORT_RECIPE_DESIGN') && scale == 1) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file =
                File('tmp/design/recipe-detail-${dark ? 'dark' : 'light'}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.drag(find.byType(ListView), const Offset(0, -1800));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
