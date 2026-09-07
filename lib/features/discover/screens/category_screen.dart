// =============================================================================
// lib/features/discover/screens/category_screen.dart
// NutriSense — Kategori tarif listesi
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/accessibility_service.dart';
import '../models/discover_content.dart';
import '../widgets/article_card.dart';
import '../widgets/discover_background.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.category});

  final DiscoverCategory category;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  @override
  void initState() {
    super.initState();
    final articles = articlesForCategory(widget.category.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(accessibilityServiceProvider).speak(
            articles.isEmpty
                ? '${widget.category.title} kategorisinde henüz tarif yok.'
                : '${widget.category.title} kategorisi. '
                    '${articles.length} tarif bulundu.',
            priority: TtsPriority.high,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final articles = articlesForCategory(widget.category.id);

    return DiscoverBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          title: Text(widget.category.title),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent),
      body: articles.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    '${widget.category.title} kategorisinde henüz tarif yok.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : ListView.builder(
              key: const Key('category_list'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount: articles.length,
              itemBuilder: (context, index) =>
                  ArticleCard(article: articles[index]),
            ),
    ));
  }
}
