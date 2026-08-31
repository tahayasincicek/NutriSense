import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/api_service.dart';
import '../../auth/state/auth_controller.dart';
import '../models/dietitian_dashboard_models.dart';

class DietitianDashboardScreen extends ConsumerStatefulWidget {
  const DietitianDashboardScreen({super.key});

  @override
  ConsumerState<DietitianDashboardScreen> createState() =>
      _DietitianDashboardScreenState();
}

class _DietitianDashboardScreenState
    extends ConsumerState<DietitianDashboardScreen> {
  DietitianDashboardData? _dashboard;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final result = await ref.read(apiServiceProvider).getDietitianDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _dashboard = result.data;
      _error = result.isSuccess
          ? null
          : result.errorMessage ?? 'Panel verileri alınamadı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diyetisyen Paneli'),
        actions: [
          IconButton(
            tooltip: 'Paneli yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading && _dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _dashboard == null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _ProfileHeader(data: _dashboard!),
                      const SizedBox(height: 20),
                      Semantics(
                        header: true,
                        child: Text(
                          'Genel görünüm',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetricCard(
                            label: 'Aktif danışan',
                            value: '${_dashboard!.activePatients}',
                            icon: Icons.groups_2_outlined,
                            color: AppTheme.primaryColor,
                          ),
                          _MetricCard(
                            label: 'Bekleyen eşleşme',
                            value: '${_dashboard!.pendingAssignments}',
                            icon: Icons.pending_actions_outlined,
                            color: Colors.orange.shade700,
                          ),
                          _MetricCard(
                            label: 'Alınan rapor',
                            value: '${_dashboard!.reportsReceived}',
                            icon: Icons.summarize_outlined,
                            color: Colors.indigo.shade600,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Danışanlarım',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          Text('${_dashboard!.patients.length} kişi'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_dashboard!.patients.isEmpty)
                        const _EmptyPatientsCard()
                      else
                        ..._dashboard!.patients.map(
                          (patient) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PatientCard(
                              patient: patient,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DietitianPatientDetailScreen(
                                    patient: patient,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.data});

  final DietitianDashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.medical_services, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.specialization,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      data.emailVerified
                          ? Icons.verified_outlined
                          : Icons.info_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.emailVerified
                          ? 'Doğrulanmış diyetisyen'
                          : 'Doğrulama bekleniyor',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Container(
        width: 155,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final DietitianPatientSummary patient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label:
            '${patient.fullName}, bugün ${patient.todayCalories.toStringAsFixed(0)} kalori, son yedi günde ${patient.sevenDayMeals} öğün',
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
            child: Text(
              patient.fullName.isEmpty
                  ? '?'
                  : patient.fullName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            patient.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${patient.todayCalories.toStringAsFixed(0)} kcal bugün • '
              '${patient.sevenDayMeals} öğün / 7 gün',
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _EmptyPatientsCard extends StatelessWidget {
  const _EmptyPatientsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz aktif danışanınız yok',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hasta, uygulamadaki Diyetisyen sekmesinden mesleki e-posta '
              'adresinizi ekleyip paylaşım onayı verdiğinde burada görünür.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class DietitianPatientDetailScreen extends ConsumerStatefulWidget {
  const DietitianPatientDetailScreen({required this.patient, super.key});

  final DietitianPatientSummary patient;

  @override
  ConsumerState<DietitianPatientDetailScreen> createState() =>
      _DietitianPatientDetailScreenState();
}

class _DietitianPatientDetailScreenState
    extends ConsumerState<DietitianPatientDetailScreen> {
  DietitianPatientHistoryData? _history;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(apiServiceProvider).getDietitianPatientHistory(
              patientId: widget.patient.userId,
            );
    if (!mounted) return;
    setState(() {
      _history = result.data;
      _error = result.isSuccess
          ? null
          : result.errorMessage ?? 'Danışan kayıtları alınamadı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.fullName)),
      body: _history == null && _error == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _history == null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DetailMetric(
                              label: '30 günlük kalori',
                              value:
                                  '${_history!.totalCalories.toStringAsFixed(0)} kcal',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DetailMetric(
                              label: 'Toplam öğün',
                              value: '${_history!.totalMeals}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Son öğünler',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_history!.logs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Seçilen dönemde kayıtlı öğün bulunmuyor.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._history!.logs.map(
                          (log) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.restaurant_outlined),
                              title: Text(log.foodName),
                              subtitle: Text(
                                '${_mealLabel(log.mealType)} • '
                                '${log.portionGrams.toStringAsFixed(0)} g • '
                                '${_dateLabel(log.loggedAt)}',
                              ),
                              trailing: Text(
                                '${log.totalCalories.toStringAsFixed(0)} kcal',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

String _mealLabel(String value) => switch (value) {
      'kahvalti' => 'Kahvaltı',
      'ogle' => 'Öğle',
      'aksam' => 'Akşam',
      _ => 'Atıştırmalık',
    };

String _dateLabel(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';
