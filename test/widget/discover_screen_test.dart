import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/core/theme/app_theme.dart';
import 'package:nutrisense/features/discover/models/discover_content.dart';
import 'package:nutrisense/features/discover/screens/article_detail_screen.dart';
import 'package:nutrisense/features/discover/screens/category_screen.dart';
import 'package:nutrisense/features/discover/screens/discover_screen.dart';

Widget _app({double textScale = 1}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DiscoverScreen(),
      ),
    ),
  );
}

void main() {
  group('Keşfet ekranı', () {
    testWidgets('ipucu kartına dokunmak detay ekranını açar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      // "Uyku ve Beslenme" kartı — kullanıcının çalışmadığını bildirdiği kart.
      final tip = find.text('Uyku ve Beslenme');
      await tester.scrollUntilVisible(
        tip,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(tip);
      await tester.pumpAndSettle();
      await tester.tap(tip, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(ArticleDetailScreen), findsOneWidget);
      expect(find.textContaining('Triptofan'), findsOneWidget);
    });

    testWidgets('kategori kutucuğu kategori ekranını açar', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text('Kahvaltılık'));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryScreen), findsOneWidget);
      expect(find.byKey(const Key('category_list')), findsOneWidget);
      expect(find.text('Protein Yüklü Menemen'), findsOneWidget);
    });

    testWidgets('haftanın tarifi malzeme ve adımlarıyla açılır',
        (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      await tester.tap(find.text(featuredRecipe.title));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('article_listen')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Malzemeler'), 200);
      expect(find.text('Malzemeler'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Yapılışı'), 200);
      expect(find.text('Yapılışı'), findsOneWidget);
    });

    testWidgets('her dokunulabilir kart onTap taşıyan buton semantiği sunar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pump();

      // Ekran okuyucuya "buton" diye tanıtılan her şey gerçekten
      // etkinleştirilebilmeli; aksi hâli kör kullanıcı için çıkmazdır.
      final buttons = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((widget) => widget.properties.button ?? false);
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        expect(
          button.properties.onTap,
          isNotNull,
          reason: 'Buton etiketli ama eylemsiz: ${button.properties.label}',
        );
      }
      handle.dispose();
    });

    testWidgets('yüzde 200 fontta taşma üretmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_app(textScale: 2));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Keşfet içeriği', () {
    test('her kaydın kimliği benzersiz', () {
      final ids = [featuredRecipe, ...discoverArticles].map((a) => a.id);
      expect(ids.toSet().length, ids.length);
    });

    test('her kategoride en az bir tarif var', () {
      for (final category in discoverCategories) {
        expect(
          articlesForCategory(category.id),
          isNotEmpty,
          reason: '${category.title} kategorisi boş',
        );
      }
    });

    test('sesli okuma metni malzeme ve adımları içerir', () {
      final spoken = featuredRecipe.spokenArticle;
      expect(spoken, contains('Malzemeler'));
      expect(spoken, contains('1. adım'));
      expect(spoken, contains(featuredRecipe.ingredients.first));
    });

    test('her kategoride en az üç tarif var', () {
      // Kategoriye girip tek tarif görmek "boş" hissi veriyordu.
      for (final category in discoverCategories) {
        expect(
          articlesForCategory(category.id).length,
          greaterThanOrEqualTo(3),
          reason: '${category.title} kategorisinde yeterli tarif yok',
        );
      }
    });

    test('her tarif malzeme, adım, süre ve kalori taşır', () {
      final recipes = [
        featuredRecipe,
        ...discoverArticles.where((article) => article.isRecipe),
      ];
      for (final recipe in recipes) {
        expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
        expect(recipe.steps.length, greaterThanOrEqualTo(3), reason: recipe.id);
        expect(recipe.prepMinutes, isNotNull, reason: recipe.id);
        expect(recipe.calories, isNotNull, reason: recipe.id);
        // Kalori değerleri makul aralıkta olmalı.
        expect(recipe.calories! >= 80 && recipe.calories! <= 900, isTrue,
            reason: '${recipe.id} kalori değeri şüpheli');
      }
    });

    test('her tarifin kategorisi tanımlı bir kategoriye ait', () {
      final ids = discoverCategories.map((c) => c.id).toSet();
      for (final article in discoverArticles) {
        if (article.category == null) continue;
        expect(ids, contains(article.category), reason: article.id);
      }
    });

    test('günün ipuçları yalnızca tarif olmayanları listeler', () {
      expect(dailyTips, isNotEmpty);
      for (final tip in dailyTips) {
        expect(tip.isRecipe, isFalse);
      }
    });
  });
}
