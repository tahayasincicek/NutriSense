// =============================================================================
// lib/features/discover/widgets/article_card.dart
// NutriSense — Keşfet içerik kartı
//
// Kart gerçek bir butondur: InkWell ile dokunma alanı ve Semantics'te onTap
// tanımlıdır. Ekran okuyucuya "buton" diye tanıtılıp hiçbir şey yapmaması,
// kullanıcının en çok kafasını karıştıran durumlardan biri olurdu.
// =============================================================================

import 'package:flutter/material.dart';

import '../models/discover_content.dart';
import '../screens/article_detail_screen.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article});

  final DiscoverArticle article;

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        container: true,
        excludeSemantics: true,
        label: article.semanticLabel,
        hint: 'Açmak için çift dokunun',
        onTap: () => _open(context),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _open(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(article.icon, color: article.color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(article.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(article.summary, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
