// =============================================================================
// lib/features/history/screens/food_history_screen.dart
// NutriSense — Besin Geçmişi Ekranı
//
// Günlük/haftalık/aylık görünüm.
// Erişilebilirlik: Semantics + TTS okuma + swipe-to-delete.
// Boş durum mesajı, günlük özet kartı, makro dağılımı.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/food_history_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/navigation_announcer.dart';

/// Zaman aralığı filtresi
enum HistoryPeriod {
  daily('Günlük', 1),
  weekly('Haftalık', 7),
  monthly('Aylık', 30);

  const HistoryPeriod(this.label, this.days);
  final String label;
  final int days;
}

class FoodHistoryScreen extends ConsumerStatefulWidget {
  const FoodHistoryScreen({super.key});

  @override
  ConsumerState<FoodHistoryScreen> createState() => _FoodHistoryScreenState();
}

class _FoodHistoryScreenState extends ConsumerState<FoodHistoryScreen> {
  late AccessibilityService _accessibility;
  late ApiService _apiService;
  late NavigationAnnouncer _announcer;

  HistoryPeriod _period = HistoryPeriod.weekly;
  List<DailyNutrition> _dailyLogs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _apiService = ref.read(apiServiceProvider);
    _announcer = ref.read(navigationAnnouncerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcer.announceScreen(AppScreen.history);
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final fromDate = now.subtract(Duration(days: _period.days));

    final result = await _apiService.getFoodHistory(
      fromDate: fromDate,
      toDate: now,
    );

    if (result.isSuccess && result.data != null) {
      final history = result.data!;
      setState(() {
        _dailyLogs = history.dailyLogs
            .map((d) => DailyNutrition.fromJson({
                  'date': d.date.toIso8601String(),
                  'total_calories': d.totalCalories,
                  'calorie_target': d.calorieTarget,
                  'total_protein': d.totalProtein,
                  'total_carbs': d.totalCarbs,
                  'total_fat': d.totalFat,
                  'foods': d.foods
                      .map((f) => {
                            'id': f.id,
                            'food_name': f.foodName,
                            'food_name_tr': f.foodNameTr,
                            'calories': f.calories,
                            'portion_g': f.portionG,
                            'meal_type': f.mealType,
                            'confidence': f.confidence,
                            'logged_at': f.loggedAt.toIso8601String(),
                            'nutrients': {
                              'protein': f.nutrients.protein,
                              'carb': f.nutrients.carbs,
                              'fat': f.nutrients.fat,
                            },
                          })
                      .toList(),
                }))
            .toList();
        _isLoading = false;
      });

      // Boş durum sesli bildirimi
      if (_dailyLogs.isEmpty) {
        _accessibility.speak(
          AppStrings.noFoodToday,
          priority: TtsPriority.normal,
        );
      }
    } else {
      setState(() {
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Besin Geçmişi'),
        actions: [
          // Sesli özet butonu
          Semantics(
            label: 'Geçmişi sesli oku',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.record_voice_over),
              onPressed: _speakSummary,
              tooltip: 'Sesli Özet',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Dönem seçici ──
          _buildPeriodSelector(theme),

          // ── İçerik ──
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage != null
                    ? _buildErrorState(theme)
                    : _dailyLogs.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildHistoryList(theme),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DÖNEM SEÇİCİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPeriodSelector(ThemeData theme) {
    return Semantics(
      label: 'Zaman aralığı seçici. Şu an ${_period.label} seçili.',
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: HistoryPeriod.values.map((period) {
            final isActive = _period == period;
            return Expanded(
              child: Semantics(
                label: '${period.label}${isActive ? ", seçili" : ""}',
                button: true,
                selected: isActive,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _period = period);
                    _loadHistory();
                    _accessibility.speak(
                      '${period.label} görünüme geçildi.',
                      priority: TtsPriority.normal,
                    );
                    _accessibility.lightHaptic();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          isActive ? AppTheme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YÜKLEME / HATA / BOŞ DURUMLAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          SizedBox(height: 16),
          Text('Geçmiş yükleniyor...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Semantics(
        label: 'Hata: $_errorMessage. Tekrar denemek için butona basın.',
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Bir hata oluştu',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Semantics(
        label: AppStrings.noFoodToday,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'Henüz besin kaydı yok',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Besin taramak için ana sayfaya dönün.',
              style:
                  theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GEÇMİŞ LİSTESİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHistoryList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _dailyLogs.length,
        itemBuilder: (context, index) {
          final day = _dailyLogs[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Günlük özet kartı
              _buildDailySummaryCard(day, theme),

              // Yemek listesi
              ...day.entries.map((entry) => _buildFoodEntryTile(entry, theme)),

              if (index < _dailyLogs.length - 1)
                const Divider(height: 32, thickness: 2),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÜNLÜK ÖZET KARTI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDailySummaryCard(DailyNutrition day, ThemeData theme) {
    final pct = day.targetPercent.clamp(0, 150).toDouble();
    final progressColor = pct > 100
        ? Colors.red[400]!
        : pct > 80
            ? Colors.orange[400]!
            : AppTheme.primaryColor;

    return Semantics(
      label: day.ttsText,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih başlığı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.dateTr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => _accessibility.speak(
                    day.ttsText,
                    priority: TtsPriority.high,
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kalori ilerleme çubuğu
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.totalCalories.toStringAsFixed(0)} / ${day.targetCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.5),
                          minHeight: 10,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(progressColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Yüzde göstergesi
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  child: Center(
                    child: Text(
                      '%${pct.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Makro dağılımı
            Row(
              children: [
                _buildMacroChip(
                    'P', day.macroBreakdown.protein, Colors.blue[200]!),
                const SizedBox(width: 8),
                _buildMacroChip(
                    'K', day.macroBreakdown.carb, Colors.amber[200]!),
                const SizedBox(width: 8),
                _buildMacroChip('Y', day.macroBreakdown.fat, Colors.red[200]!),
                const Spacer(),
                Text(
                  '${day.mealCount} öğün',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(0)}g',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YEMEK KAYDI SATIRI (SWİPE-TO-DELETE)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFoodEntryTile(FoodEntry entry, ThemeData theme) {
    return Semantics(
      label: entry.ttsText,
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Sil'): () {
          _confirmDelete(entry);
        },
      },
      child: Dismissible(
        key: Key(entry.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          color: Colors.red[400],
          child: Semantics(
            label: '${entry.foodNameTr} kaydını sil',
            child: const Icon(Icons.delete, color: Colors.white, size: 28),
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(entry),
        child: InkWell(
          onTap: () {
            // Dokunulduğunda sesli oku
            _accessibility.speak(entry.ttsText, priority: TtsPriority.normal);
            _accessibility.lightHaptic();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                // Öğün ikonu
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _mealColor(entry.mealType).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _mealIcon(entry.mealType),
                    color: _mealColor(entry.mealType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Besin bilgisi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.foodNameTr,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.portionGrams.toStringAsFixed(0)}g • '
                        '${entry.mealType.displayName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Kalori + saat
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${entry.totalCalories.toStringAsFixed(0)} kcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.timeText,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // YARDIMCILAR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> _confirmDelete(FoodEntry entry) async {
    _accessibility.speak(
      '${entry.foodNameTr} kaydını silmek istediğinizden emin misiniz? '
      'Onaylamak için sağa kaydırmaya devam edin.',
      priority: TtsPriority.high,
    );
    _accessibility.mediumHaptic();
    return true; // Gerçek uygulamada dialog gösterilebilir
  }

  void _speakSummary() {
    if (_dailyLogs.isEmpty) {
      _accessibility.speak(AppStrings.noFoodToday,
          priority: TtsPriority.normal);
      return;
    }

    final today = _dailyLogs.isNotEmpty ? _dailyLogs.first : null;
    if (today != null) {
      _accessibility.speak(today.ttsText, priority: TtsPriority.high);
    }
  }

  IconData _mealIcon(MealType meal) => switch (meal) {
        MealType.kahvalti => Icons.free_breakfast,
        MealType.ogle => Icons.lunch_dining,
        MealType.aksam => Icons.dinner_dining,
        MealType.atistirmalik => Icons.cookie,
      };

  Color _mealColor(MealType meal) => switch (meal) {
        MealType.kahvalti => Colors.orange,
        MealType.ogle => Colors.green,
        MealType.aksam => Colors.indigo,
        MealType.atistirmalik => Colors.pink,
      };
}
