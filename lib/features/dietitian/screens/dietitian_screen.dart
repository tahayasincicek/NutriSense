import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/models/auth_model.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import 'send_report_wizard.dart';
import 'dietitian_access_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/shared_report_history.dart';

class DietitianScreen extends ConsumerStatefulWidget {
  const DietitianScreen({super.key});

  @override
  ConsumerState<DietitianScreen> createState() => _DietitianScreenState();
}

class _DietitianScreenState extends ConsumerState<DietitianScreen> {
  final _email = TextEditingController();
  late final AccessibilityService _accessibility;
  DietitianAssignmentInfo? _assignment;
  List<SharedReportHistoryItem> _history = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    _accessibility = ref.read(accessibilityServiceProvider);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _accessibility.speak(
        'Diyetisyen paneli. Beslenme raporlarınızı bir uzmanla '
        'paylaşabilirsiniz.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getDietitianAssignment();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _assignment = result.data;
      _error = result.isSuccess ? null : result.errorMessage;
    });
    if (result.data != null) await _loadHistory();
  }

  /// İşlem sonucunu hem ekranda hem sesli bildirir.
  ///
  /// Önceden bu işlemler sessizce başarısız oluyordu: hata durumunda hiçbir
  /// geri bildirim yoktu, ekran okuyucu kullanıcısı ne olduğunu anlayamazdı.
  void _report({required bool success, required String message}) {
    if (!mounted) return;
    setState(() => _error = success ? null : message);
    if (success) {
      _accessibility.speak(message, priority: TtsPriority.high);
      AccessibilityUtils.successHaptic();
    } else {
      _accessibility.speakError(message);
      AccessibilityUtils.errorHaptic();
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Diyetisyen Paneli'),
        actions: [
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Diyetisyen portalına giriş',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DietitianAccessScreen(),
              ),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) _buildErrorCard(_error!),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  if (_assignment == null)
                    _buildSetupCard()
                  else
                    _buildAssignmentCard(),
                  if (_assignment != null) ...[
                    const SizedBox(height: 32),
                    _buildHistorySection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      container: true,
      excludeSemantics: true,
      label: 'Uzman desteği. Beslenme programını bir uzmanla paylaşarak '
          'daha hızlı sonuç alabilirsin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uzman Desteği',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Beslenme programını bir uzmanla paylaşarak daha hızlı sonuç alabilirsin.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) => Semantics(
        liveRegion: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
          ),
          child:
              Text(message, style: const TextStyle(color: AppTheme.errorColor)),
        ),
      );

  Widget _buildSetupCard() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      // Kart görünümü diğer sekmelerdeki kartlarla aynı: aynı yüzey rengi,
      // aynı köşe yarıçapı, aynı ince kenarlık. Farklı bir kenarlık ve gölge
      // kullanmak paneli uygulamanın dışında bir yer gibi gösteriyordu.
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ana eylemin simgesi, uygulamanın diğer birincil kartlarındaki
          // gibi yeşil gradyanlı yuvarlak bir alan içinde durur.
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person_search_rounded,
                  size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text('Diyetisyen Atama',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            'Diyetisyeninin e-posta adresini yazarak bağlantı isteği gönderebilirsin.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Semantics(
            label: 'Diyetisyen e-posta adresi giriş alanı',
            textField: true,
            child: TextField(
              key: const Key('dietitian_email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _requestAssignment(),
              decoration: const InputDecoration(
                labelText: 'Diyetisyen e-postası',
                hintText: 'diyetisyen@email.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AccessibleButton(
            key: const Key('dietitian_request'),
            label: _busy ? 'Gönderiliyor...' : 'İstek Gönder',
            semanticLabel:
                'Diyetisyeninize bağlantı isteği göndermek için basın',
            isLoading: _busy,
            onPressed: _busy ? null : _requestAssignment,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard() {
    final theme = Theme.of(context);
    final assignment = _assignment!;
    final isApproved = assignment.isApproved;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        // Bağlantı aktifken yeşil vurgulu kenarlık, beklerken diğer
        // kartlarla aynı nötr kenarlık kullanılır.
        border: Border.all(
            color: isApproved
                ? AppTheme.primaryColor.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Ad ve durum tek duyuru olarak okunur; baş harf avatarı
          // ekran okuyucu için anlamsız olduğundan dışlanır.
          Semantics(
            container: true,
            excludeSemantics: true,
            label: 'Diyetisyeniniz ${assignment.dietitianName}. '
                '${isApproved ? "Bağlantı aktif." : "Onay bekleniyor."}',
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(assignment.dietitianName[0],
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ),
                const SizedBox(height: 16),
                Text(assignment.dietitianName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isApproved ? 'Bağlantı Aktif' : 'Onay Bekleniyor',
                    style: TextStyle(
                        color: isApproved
                            ? theme.colorScheme.primary
                            : Colors.amber[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!isApproved)
            AccessibleButton(
              key: const Key('dietitian_approve'),
              label: 'Bağlantıyı Onayla',
              semanticLabel:
                  '${assignment.dietitianName} ile bağlantıyı onaylamak için basın',
              isLoading: _busy,
              onPressed: _busy ? null : _approveAssignment,
            )
          else
            AccessibleButton(
              key: const Key('dietitian_send_report'),
              label: 'Haftalık Rapor Gönder',
              semanticLabel: 'Haftalık beslenme raporunuzu '
                  '${assignment.dietitianName} adlı diyetisyene göndermek için basın',
              icon: Icons.send_rounded,
              onPressed: _busy ? null : _sendReport,
            ),
          const SizedBox(height: 12),
          AccessibleButton(
            key: const Key('dietitian_cancel'),
            label: isApproved ? 'Atamayı Kaldır' : 'İsteği İptal Et',
            semanticLabel: isApproved
                ? 'Diyetisyen bağlantısını kaldırmak için basın. Onay istenir.'
                : 'Bağlantı isteğini iptal etmek için basın. Onay istenir.',
            type: AccessibleButtonType.text,
            foregroundColor: AppTheme.errorColor,
            onPressed: _busy ? null : _cancelAssignment,
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistory() async {
    final result = await _api.getSharedReportHistory();
    if (!mounted) return;
    setState(() => _history = result.data ?? const []);
  }

  /// Gönderilen raporların geçmişi ve diyetisyenin cevabı.
  ///
  /// Kullanıcı daha önce neyi paylaştığını göremiyordu; bu, paylaşımın
  /// denetlenebilir olması için gerekli.
  Widget _buildHistorySection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Gönderdiğim Raporlar',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border:
                  Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Text(
              'Henüz rapor göndermediniz. Hazır olduğunuzda haftalık '
              'raporunuzu paylaşabilirsiniz.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          ..._history.map(_buildHistoryCard),
      ],
    );
  }

  Widget _buildHistoryCard(SharedReportHistoryItem item) {
    final theme = Theme.of(context);
    final channels = item.channels
        .map((c) => '${c.channelLabel}: ${c.statusLabel}')
        .join(', ');

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: item.spokenSummary,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.periodLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.status == 'completed'
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : AppTheme.warningColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: item.status == 'completed'
                          ? AppTheme.primaryColor
                          : AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                '${item.recordCount} kayıt${channels.isEmpty ? '' : ' - $channels'}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (item.hasReply) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diyetisyeninizin cevabı',
                        style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor)),
                    const SizedBox(height: 4),
                    Text(item.dietitianReply!,
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestAssignment() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _report(success: false, message: 'Geçerli bir e-posta adresi girin.');
      return;
    }
    setState(() => _busy = true);
    final result = await _api.requestDietitianAssignment(email: email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) _assignment = result.data;
    });
    _report(
      success: result.isSuccess,
      message: result.isSuccess
          ? 'Bağlantı isteği gönderildi. Diyetisyeninizin onayı bekleniyor.'
          : result.errorMessage ?? 'İstek gönderilemedi.',
    );
  }

  Future<void> _approveAssignment() async {
    setState(() => _busy = true);
    final result = await _api.approveDietitianAssignment(
        assignmentId: _assignment!.assignmentId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) _assignment = result.data;
    });
    _report(
      success: result.isSuccess,
      message: result.isSuccess
          ? 'Bağlantı onaylandı. Artık rapor gönderebilirsiniz.'
          : result.errorMessage ?? 'Onaylama başarısız oldu.',
    );
  }

  /// Atamayı kaldırma geri alınamaz; önce onay istenir.
  Future<void> _cancelAssignment() async {
    final isApproved = _assignment?.isApproved ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproved ? 'Atamayı Kaldır' : 'İsteği İptal Et'),
        content: Text(
          isApproved
              ? 'Diyetisyeninizle bağlantınız kaldırılacak. '
                  'Rapor gönderemezsiniz. Emin misiniz?'
              : 'Gönderdiğiniz bağlantı isteği iptal edilecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const Key('dietitian_cancel_confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await _api.cancelDietitianAssignment(
        assignmentId: _assignment!.assignmentId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) _assignment = null;
    });
    _report(
      success: result.isSuccess,
      message: result.isSuccess
          ? 'Diyetisyen bağlantısı kaldırıldı.'
          : result.errorMessage ?? 'İşlem başarısız oldu.',
    );
  }

  Future<void> _sendReport() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SendReportWizard(assignment: _assignment!)));
  }
}
