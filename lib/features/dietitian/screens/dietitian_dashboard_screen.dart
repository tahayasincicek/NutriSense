import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../../auth/state/auth_controller.dart';
import '../models/dietitian_dashboard_models.dart';
import 'dietitian_report_detail_screen.dart';

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

  /// İşlem sürerken aynı isteğe ikinci kez basılmasını engeller.
  String? _decidingId;

  /// Danışan listesinde arama; liste büyüdükçe gezinmeyi mümkün kılar.
  String _query = '';

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

  /// Bekleyen bir eşleşme isteğini kabul eder veya reddeder.
  ///
  /// Kabul tek başına bağı kurmaz: hasta da kendi rızasını vermiş olmalıdır.
  /// Ret geri alınamadığı için önce onay sorulur.
  Future<void> _decide(
    DietitianPendingRequest request, {
    required bool accept,
  }) async {
    if (!accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('İsteği reddet'),
          content: Text(
            '${request.patientName} adlı danışanın eşleşme isteği '
            'reddedilecek. Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reddet'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _decidingId = request.assignmentId);
    final api = ref.read(apiServiceProvider);
    final result = accept
        ? await api.acceptAssignmentAsDietitian(
            assignmentId: request.assignmentId,
          )
        : await api.rejectAssignmentAsDietitian(
            assignmentId: request.assignmentId,
          );
    if (!mounted) return;
    setState(() => _decidingId = null);

    if (!result.isSuccess) {
      _announce(result.errorMessage ?? 'İşlem tamamlanamadı.');
      return;
    }
    final info = result.data;
    if (!accept) {
      _announce('${request.patientName} isteği reddedildi.');
    } else if (info != null && info.isApproved) {
      _announce('${request.patientName} artık danışanınız.');
    } else {
      _announce(
        '${request.patientName} kabul edildi; danışanın onayı bekleniyor.',
      );
    }
    await _load();
  }

  /// Kurulu bir eşleşmeyi diyetisyen tarafından sonlandırır.
  ///
  /// Hastanın iptal hakkının simetriğidir. Geri alınamadığı için onay sorulur.
  Future<void> _endAssignment(DietitianPatientSummary patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eşleşmeyi sonlandır'),
        content: Text(
          '${patient.fullName} ile eşleşmeniz sonlandırılacak ve danışanın '
          'verilerine erişiminiz kapanacak. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sonlandır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final assignmentId = patient.assignmentId;
    if (assignmentId == null) {
      _announce('Eşleşme kimliği bulunamadı.');
      return;
    }
    final result = await ref.read(apiServiceProvider).endAssignmentAsDietitian(
          assignmentId: assignmentId,
        );
    if (!mounted) return;
    if (!result.isSuccess) {
      _announce(result.errorMessage ?? 'Eşleşme sonlandırılamadı.');
      return;
    }
    _announce('${patient.fullName} ile eşleşme sonlandırıldı.');
    await _load();
  }

  /// Diyetisyenin kendi profilini düzenlemesi.
  ///
  /// E-posta kimlik doğrulamasına bağlı olduğu için değiştirilemez.
  Future<void> _editProfile() async {
    final dashboard = _dashboard;
    if (dashboard == null) return;
    final nameController = TextEditingController(text: dashboard.fullName);
    final fieldController =
        TextEditingController(text: dashboard.specialization);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Profili düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              textField: true,
              label: 'Ad soyad',
              child: TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              textField: true,
              label: 'Uzmanlık alanı',
              child: TextField(
                controller: fieldController,
                decoration: const InputDecoration(labelText: 'Uzmanlık alanı'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final field = fieldController.text.trim();
    nameController.dispose();
    fieldController.dispose();
    if (saved != true || !mounted) return;
    if (name.length < 2 || field.length < 2) {
      _announce('Ad ve uzmanlık alanı en az iki karakter olmalıdır.');
      return;
    }

    final result = await ref.read(apiServiceProvider).updateDietitianProfile(
          fullName: name,
          specialization: field,
        );
    if (!mounted) return;
    if (!result.isSuccess) {
      _announce(result.errorMessage ?? 'Profil güncellenemedi.');
      return;
    }
    setState(() => _dashboard = result.data);
    _announce('Profiliniz güncellendi.');
  }

  void _announce(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_outlined,
                size: 19,
                color: AppTheme.primaryDark,
              ),
            ),
            const SizedBox(width: 9),
            const Text('NutriSense Pro'),
          ],
        ),
        actions: [
          // Bekleyen istek varsa panel elle yenilenmeden fark edilsin.
          if ((_dashboard?.pendingRequests.length ?? 0) > 0)
            Semantics(
              label: '${_dashboard!.pendingRequests.length} bekleyen '
                  'eşleşme isteği var',
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_dashboard!.pendingRequests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Paneli yenile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _SoftBackground(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _dashboard == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    final dashboard = _dashboard!;
    final firstName = dashboard.fullName.trim().split(RegExp(r'\s+')).first;
    final needle = _query.trim().toLowerCase();
    // Takip gerektirenler önce gelir; diyetisyen önceliğini listede görür.
    final visiblePatients = dashboard.patients
        .where((patient) =>
            needle.isEmpty ||
            patient.fullName.toLowerCase().contains(needle) ||
            patient.email.toLowerCase().contains(needle))
        .toList()
      ..sort((a, b) {
        if (a.needsFollowUp != b.needsFollowUp) {
          return a.needsFollowUp ? -1 : 1;
        }
        return a.fullName.compareTo(b.fullName);
      });
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Merhaba, $firstName',
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Danışanlarının beslenme yolculuğu bugün nasıl gidiyor?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          _ProfileHeader(data: dashboard, onEdit: _editProfile),
          const SizedBox(height: 28),
          const _SectionHeading(
            title: 'Genel görünüm',
            subtitle: 'Güncel panel özeti',
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Aktif danışan',
                  value: '${dashboard.activePatients}',
                  icon: Icons.groups_2_outlined,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Bekleyen eşleşme',
                  value: '${dashboard.pendingAssignments}',
                  icon: Icons.pending_actions_outlined,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WideMetricCard(
            label: 'Alınan beslenme raporu',
            value: '${dashboard.reportsReceived}',
            helper: 'Danışanlardan gelen toplam rapor',
            icon: Icons.summarize_outlined,
            color: AppTheme.secondaryColor,
          ),
          if (dashboard.pendingRequests.isNotEmpty) ...[
            const SizedBox(height: 32),
            _SectionHeading(
              title: 'Bekleyen eşleşme istekleri',
              subtitle:
                  '${dashboard.pendingRequests.length} danışan yanıtınızı bekliyor',
            ),
            const SizedBox(height: 12),
            ...dashboard.pendingRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PendingRequestCard(
                  request: request,
                  busy: _decidingId == request.assignmentId,
                  onAccept: () => _decide(request, accept: true),
                  onReject: () => _decide(request, accept: false),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          _SectionHeading(
            title: 'Gelen beslenme raporları',
            subtitle: dashboard.recentReports.isEmpty
                ? 'Danışan onayıyla gelen raporlar burada listelenir'
                : 'Son ${dashboard.recentReports.length} rapor',
          ),
          const SizedBox(height: 12),
          if (dashboard.recentReports.isEmpty)
            const _EmptyReportsCard()
          else
            ...dashboard.recentReports.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReceivedReportCard(
                  report: report,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DietitianReportDetailScreen(
                        reportId: report.reportId,
                        patientName: report.patientName,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          _SectionHeading(
            title: 'Danışanlarım',
            subtitle: needle.isEmpty
                ? '${dashboard.patients.length} aktif danışan'
                : '${visiblePatients.length} / ${dashboard.patients.length}',
          ),
          const SizedBox(height: 12),
          if (dashboard.patients.length > 3) ...[
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Danışan ara',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
          ],
          if (dashboard.patients.isEmpty)
            const _EmptyPatientsCard()
          else if (visiblePatients.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '"$_query" ile eşleşen danışan yok.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ...visiblePatients.map(
              (patient) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PatientCard(
                  patient: patient,
                  onEnd: () => _endAssignment(patient),
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
    );
  }
}

class _SoftBackground extends StatelessWidget {
  const _SoftBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -170,
          right: -120,
          child: CircleAvatar(
            radius: 210,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.075),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -120,
          child: CircleAvatar(
            radius: 190,
            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.045),
          ),
        ),
        child,
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.data, required this.onEdit});

  final DietitianDashboardData data;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '${data.fullName}, ${data.specialization}, '
          '${data.emailVerified ? 'doğrulanmış diyetisyen' : 'doğrulama bekleniyor'}',
      child: Container(
        padding: const EdgeInsets.all(24),
        // Hasta ekranlarındaki kartlarla aynı yüzey; dolu gradyan blok
        // uygulamanın geri kalanında hiçbir yerde kullanılmıyor.
        decoration: _surfaceDecoration(theme, accent: AppTheme.primaryColor),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.specialization,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (data.emailVerified
                              ? AppTheme.successColor
                              : AppTheme.warningColor)
                          .withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          data.emailVerified
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: data.emailVerified
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            data.emailVerified
                                ? 'Doğrulanmış uzman'
                                : 'Doğrulama bekleniyor',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: data.emailVerified
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Profili düzenle',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              // Hasta ekranlarındaki bölüm başlığı ölçüsü.
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _surfaceDecoration(theme, accent: color),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideMetricCard extends StatelessWidget {
  const _WideMetricCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value. $helper',
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: _surfaceDecoration(theme),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    helper,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bekleyen eşleşme isteği kartı.
///
/// Kart tek bir Semantics düğümü olarak okunur; ekran okuyucu kullanıcısı
/// hasta adını, isteğin ne zaman geldiğini ve hastanın kendi onayını verip
/// vermediğini tek seferde duyar. Eylemler ayrı düğme olarak gezilebilir.
class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final DietitianPendingRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  String get _relativeAge {
    final elapsed = DateTime.now().difference(request.requestedAt);
    if (elapsed.inMinutes < 1) return 'az önce';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} dakika önce';
    if (elapsed.inHours < 24) return '${elapsed.inHours} saat önce';
    return '${elapsed.inDays} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consentLabel = request.patientApproved
        ? 'Danışan onayını verdi'
        : 'Danışan onayı bekleniyor';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.warningColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: '${request.patientName}, $_relativeAge eşleşme isteği '
                'gönderdi. $consentLabel.',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_outlined,
                      color: AppTheme.warningColor,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.patientName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.patientEmailMasked,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_relativeAge · $consentLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: request.patientApproved
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AccessibleButton(
                  label: 'Kabul Et',
                  semanticLabel:
                      '${request.patientName} eşleşme isteğini kabul et',
                  semanticHint: request.patientApproved
                      ? 'Kabul edilince danışan listenize eklenir'
                      : 'Bağ, danışan da onay verdiğinde kurulur',
                  icon: Icons.check_rounded,
                  isLoading: busy,
                  fullWidth: true,
                  onPressed: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccessibleButton(
                  label: 'Reddet',
                  semanticLabel:
                      '${request.patientName} eşleşme isteğini reddet',
                  semanticHint: 'Bu işlem geri alınamaz',
                  icon: Icons.close_rounded,
                  type: AccessibleButtonType.outlined,
                  fullWidth: true,
                  onPressed: busy ? null : onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Danışan onayıyla ulaşmış tek bir beslenme raporu.
///
/// Proje raporunun diyetisyene vaat ettiği alanları gösterir: tarih aralığı,
/// besin kaydı sayısı, öğün sayısı ve toplam kalori.
class _ReceivedReportCard extends StatelessWidget {
  const _ReceivedReportCard({required this.report, this.onTap});

  final DietitianReceivedReport report;
  final VoidCallback? onTap;

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  String _day(DateTime value) => '${value.day} ${_months[value.month - 1]}';

  String get _range => report.fromDate == report.toDate
      ? _day(report.fromDate)
      : '${_day(report.fromDate)} - ${_day(report.toDate)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calories = report.totalCalories.round();

    return Semantics(
      label: '${report.patientName}, ${report.reportTypeLabel.toLowerCase()} '
          'rapor, $_range. ${report.recordCount} besin kaydı, '
          '${report.totalMeals} öğün, toplam $calories kalori. '
          '${report.channelLabel} ile ulaştı.'
          '${report.isPartial ? ' Gönderim kısmen başarısız.' : ''}',
      button: onTap != null,
      child: ExcludeSemantics(
        child: Container(
          decoration:
              _surfaceDecoration(theme, accent: AppTheme.secondaryColor),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.secondaryColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.description_outlined,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.patientName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${report.reportTypeLabel} · $_range',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (report.isPartial)
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warningColor,
                            semanticLabel: 'Kısmi teslimat',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ReportChip(
                          icon: Icons.restaurant_outlined,
                          label: '${report.recordCount} besin kaydı',
                        ),
                        _ReportChip(
                          icon: Icons.schedule_outlined,
                          label: '${report.totalMeals} öğün',
                        ),
                        _ReportChip(
                          icon: Icons.local_fire_department_outlined,
                          label: '$calories kcal',
                        ),
                        _ReportChip(
                          icon: Icons.send_outlined,
                          label: report.channelLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportChip extends StatelessWidget {
  const _ReportChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.hintColor),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 38,
            color: theme.hintColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz rapor ulaşmadı',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Danışan, uygulamadan beslenme özetini onaylayıp gönderdiğinde '
            'rapor burada listelenir.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({
    required this.patient,
    required this.onTap,
    required this.onEnd,
  });

  final DietitianPatientSummary patient;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: '${patient.fullName}, bugün '
          '${patient.todayCalories.toStringAsFixed(0)} kalori, '
          'hedef ${patient.dailyCalorieTarget.toStringAsFixed(0)}, '
          'son yedi günde ${patient.sevenDayMeals} öğün. '
          '${patient.followUpLabel}.',
      child: Container(
        decoration: _surfaceDecoration(theme),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      patient.fullName.isEmpty
                          ? '?'
                          : patient.fullName.characters.first.toUpperCase(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            _PatientStatChip(
                              icon: Icons.local_fire_department_outlined,
                              label:
                                  '${patient.todayCalories.toStringAsFixed(0)} kcal',
                              color: AppTheme.warningColor,
                            ),
                            _PatientStatChip(
                              icon: Icons.restaurant_menu_rounded,
                              label: '${patient.sevenDayMeals} öğün / 7 gün',
                              color: AppTheme.primaryColor,
                            ),
                            // Takip uyarısı: üç gün ve üzeri sessizlik.
                            if (patient.needsFollowUp)
                              _PatientStatChip(
                                icon: Icons.notifications_active_outlined,
                                label: patient.followUpLabel,
                                color: AppTheme.errorColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Bugünkü kalorinin kullanıcının kendi hedefine oranı.
                        Semantics(
                          excludeSemantics: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: patient.targetProgress,
                                  minHeight: 8,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  valueColor: AlwaysStoppedAnimation(
                                    patient.targetProgress >= 1
                                        ? AppTheme.warningColor
                                        : AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Günlük hedef: '
                                '${patient.dailyCalorieTarget.toStringAsFixed(0)} kcal',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    tooltip: '${patient.fullName} için işlemler',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'detail') onTap();
                      if (value == 'end') onEnd();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'detail',
                        child: Text('Kayıtları görüntüle'),
                      ),
                      PopupMenuItem(
                        value: 'end',
                        child: Text('Eşleşmeyi sonlandır'),
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
}

class _PatientStatChip extends StatelessWidget {
  const _PatientStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPatientsCard extends StatelessWidget {
  const _EmptyPatientsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _surfaceDecoration(theme),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_outlined,
              size: 34,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz aktif danışanın yok',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Danışanın, Diyetisyen sekmesinden mesleki e-posta adresini '
            'ekleyip paylaşım onayı verdiğinde burada görünür.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: _surfaceDecoration(theme),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    size: 34,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                AccessibleButton(
                  label: 'Tekrar Dene',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
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

  /// Diyetisyen "geçen hafta ne yaptı" sorusunu sorabilmelidir; backend gün
  /// sayısını zaten parametre olarak kabul ediyor.
  static const _ranges = <int, String>{
    7: 'Son 7 gün',
    30: 'Son 30 gün',
    90: 'Son 90 gün'
  };
  int _days = 30;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _selectRange(int days) async {
    if (days == _days) return;
    setState(() {
      _days = days;
      _loading = true;
    });
    await _load();
  }

  Future<void> _load() async {
    final result =
        await ref.read(apiServiceProvider).getDietitianPatientHistory(
              patientId: widget.patient.userId,
              days: _days,
            );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _history = result.data;
      _error = result.isSuccess
          ? null
          : result.errorMessage ?? 'Danışan kayıtları alınamadı.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Danışan Detayı'),
      ),
      body: _SoftBackground(
        child: _history == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _history == null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _buildHistory(context),
      ),
    );
  }

  Widget _rangeSelector() => Semantics(
        label: 'Gösterilecek dönem',
        child: Wrap(
          spacing: 8,
          children: [
            for (final entry in _ranges.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _days == entry.key,
                onSelected: _loading ? null : (_) => _selectRange(entry.key),
              ),
          ],
        ),
      );

  Widget _buildHistory(BuildContext context) {
    final theme = Theme.of(context);
    final history = _history!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          _rangeSelector(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
                _surfaceDecoration(theme, accent: AppTheme.primaryColor),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.patient.fullName.isEmpty
                        ? '?'
                        : widget.patient.fullName.characters.first
                            .toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          widget.patient.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Son 30 günlük beslenme özeti',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryDark.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailMetric(
                  label: 'Toplam kalori',
                  value: history.totalCalories.toStringAsFixed(0),
                  unit: 'kcal',
                  icon: Icons.local_fire_department_outlined,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailMetric(
                  label: 'Toplam öğün',
                  value: '${history.totalMeals}',
                  unit: 'kayıt',
                  icon: Icons.restaurant_menu_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _SectionHeading(
            title: 'Son öğünler',
            subtitle: '${history.logs.length} kayıt',
          ),
          const SizedBox(height: 12),
          if (history.logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: _surfaceDecoration(theme),
              child: Text(
                'Seçilen dönemde kayıtlı öğün bulunmuyor.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...history.logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MealCard(log: log),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _surfaceDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.log});

  final DietitianPatientLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _surfaceDecoration(theme),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.restaurant_outlined,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.foodName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_mealLabel(log.mealType)}  •  '
                  '${log.portionGrams.toStringAsFixed(0)} g  •  '
                  '${_dateLabel(log.loggedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${log.totalCalories.toStringAsFixed(0)}\nkcal',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.warningColor,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hasta ekranlarındaki kart yüzeyiyle birebir aynı görünüm.
///
/// Aynı kenarlık opaklığı, aynı köşe yarıçapı ve aynı yumuşak gölge; böylece
/// diyetisyen paneli uygulamanın geri kalanından kopuk durmaz.
BoxDecoration _surfaceDecoration(ThemeData theme, {Color? accent}) =>
    BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      border: Border.all(
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
      ),
      boxShadow: [
        BoxShadow(
          color: (accent ?? AppTheme.secondaryColor).withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );

String _mealLabel(String value) => switch (value) {
      'kahvalti' => 'Kahvaltı',
      'ogle' => 'Öğle',
      'aksam' => 'Akşam',
      _ => 'Atıştırmalık',
    };

String _dateLabel(DateTime value) => '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';
