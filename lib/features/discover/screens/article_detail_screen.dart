// =============================================================================
// lib/features/discover/screens/article_detail_screen.dart
// NutriSense — Tarif / ipucu detay ekranı
//
// İçerik hem görsel olarak okunabilir hem de tek dokunuşla baştan sona
// dinlenebilir. Malzemeler ve adımlar ekran okuyucuya numaralandırılmış
// biçimde sunulur.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/accessibility_service.dart';
import '../models/discover_content.dart';
import '../widgets/discover_background.dart';

class ArticleDetailScreen extends ConsumerStatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final DiscoverArticle article;

  @override
  ConsumerState<ArticleDetailScreen> createState() =>
      _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends ConsumerState<ArticleDetailScreen> {
  late final AccessibilityService _accessibility;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        '${widget.article.title} açıldı. Tamamını dinlemek için '
        'tamamını dinle deyin ya da dinle seçeneğini kullanın.',
        priority: TtsPriority.high,
      );
    });
  }

  void _speakAll() {
    _accessibility.speak(
      widget.article.spokenArticle,
      priority: TtsPriority.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = widget.article;

    return DiscoverBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(article.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('article_listen'),
            icon: const Icon(Icons.volume_up_rounded),
            tooltip: 'Yazının tamamını dinle',
            onPressed: _speakAll,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(children: [
              Icon(article.icon, color: theme.colorScheme.primary, size: 26),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(
                      article.isRecipe
                          ? 'NUTRISENSE MUTFAK'
                          : 'İYİ YAŞAM REHBERİ',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4))),
            ]),
          ),
          Semantics(
            header: true,
            child: Text(article.title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
          ),
          const SizedBox(height: 8),
          Text(article.summary, style: theme.textTheme.titleMedium),
          if (article.prepMinutes != null || article.calories != null) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              excludeSemantics: true,
              label: [
                if (article.prepMinutes != null)
                  'Hazırlık ${article.prepMinutes} dakika',
                if (article.calories != null)
                  'Porsiyon başına ${article.calories} kalori',
              ].join('. '),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (article.prepMinutes != null)
                    _Chip(
                      icon: Icons.schedule_rounded,
                      label: '${article.prepMinutes} dk',
                    ),
                  if (article.calories != null)
                    _Chip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${article.calories} kcal',
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(article.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.65, color: theme.colorScheme.onSurfaceVariant)),
          if (article.ingredients.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ContentSheet(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Semantics(
                    header: true,
                    child:
                        Text('Malzemeler', style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: 12),
                  ...article.ingredients.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                            child: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Icon(Icons.check_rounded,
                                    size: 18,
                                    color: theme.colorScheme.primary)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item, style: theme.textTheme.bodyLarge),
                          ),
                        ],
                      ),
                    ),
                  ),
                ])),
          ],
          if (article.steps.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ContentSheet(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Semantics(
                    header: true,
                    child: Text('Yapılışı', style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(article.steps.length, (index) {
                    final step = article.steps[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        container: true,
                        excludeSemantics: true,
                        label: '${index + 1}. adım. $step',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${index + 1}'.padLeft(2, '0'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(step,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(height: 1.6)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ])),
          ],
        ],
      ),
    ));
  }
}

class _ContentSheet extends StatelessWidget {
  const _ContentSheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: child,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
