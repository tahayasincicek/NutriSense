import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/discover_content.dart';
import '../widgets/article_card.dart';
import 'article_detail_screen.dart';
import 'category_screen.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  void _openArticle(BuildContext context, DiscoverArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  void _openCategory(BuildContext context, DiscoverCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryScreen(category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Keşfet'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
        children: [
          _buildFeaturedRecipe(context, theme),
          const SizedBox(height: 32),
          Semantics(
            header: true,
            child: Text('Kategoriler',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          _buildCategoryGrid(context, theme),
          const SizedBox(height: 32),
          Semantics(
            header: true,
            child: Text('Günün İpuçları',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          ...dailyTips.map((tip) => ArticleCard(article: tip)),
        ],
      ),
    );
  }

  Widget _buildFeaturedRecipe(BuildContext context, ThemeData theme) {
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: 'Haftanın tarifi: ${featuredRecipe.semanticLabel}',
      hint: 'Tarifi açmak için çift dokunun',
      onTap: () => _openArticle(context, featuredRecipe),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          onTap: () => _openArticle(context, featuredRecipe),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 220),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryDark,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('HAFTANIN TARİFİ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    featuredRecipe.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(featuredRecipe.summary,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  // Büyük fontta yan yana sığmayınca alt satıra kayar.
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text('${featuredRecipe.prepMinutes} dk',
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text('${featuredRecipe.calories} kcal',
                              style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, ThemeData theme) {
    // Sabit en-boy oranı büyük fontta içeriği kesiyordu; metin ölçeğiyle
    // birlikte kutucuk da uzasın diye oranı ölçekle küçültüyoruz.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6 / scale.clamp(1.0, 2.0),
      children: discoverCategories
          .map((category) => _buildCategoryTile(context, theme, category))
          .toList(),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ThemeData theme,
    DiscoverCategory category,
  ) {
    final count = articlesForCategory(category.id).length;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${category.title} kategorisi, $count tarif',
      hint: 'Açmak için çift dokunun',
      onTap: () => _openCategory(context, category),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openCategory(context, category),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, color: category.color, size: 28),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    category.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
