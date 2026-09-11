import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import '../state/auth_controller.dart';

/// Aydınlatma metni ve ondan ayrı, amaç bazlı açık rıza ekranı.
///
/// KVKK aydınlatma yükümlülüğü ile açık rızayı ayrı tutar: metin önce
/// okunur/dinlenir, rıza ise her amaç için ayrı bir anahtarla verilir. Tek
/// kutucukta birleştirmek rızayı sakatlar.
///
/// Fotoğrafın yurt dışındaki sağlayıcıya gönderilmesi isteğe bağlıdır;
/// reddedilirse besin elle girilebilir, uygulama kullanılmaya devam eder.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key, this.requiredForEntry = false});

  final bool requiredForEntry;

  @override
  ConsumerState<PrivacyConsentScreen> createState() =>
      _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool _noticeAcknowledged = false;
  bool _healthData = false;
  bool _imageTransfer = false;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref.read(apiServiceProvider).getConsents();
    if (!mounted) return;
    setState(() {
      _loading = false;
      final data = result.data;
      if (data != null) {
        _noticeAcknowledged =
            data['privacy_notice_acknowledgement'] as bool? ?? false;
        _healthData = data['health_data_processing'] as bool? ?? false;
        _imageTransfer = data['image_cross_border_transfer'] as bool? ?? false;
      }
    });
  }

  Future<void> _save() async {
    if (!_noticeAcknowledged) {
      const message =
          'Devam etmek için aydınlatma metnini okuyup gördüğünüzü onaylayın.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(message)));
      ref.read(accessibilityServiceProvider).speak(
            message,
            priority: TtsPriority.high,
          );
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiServiceProvider);
    final notice = await api.updateConsent(
      consentType: 'privacy_notice_acknowledgement',
      granted: true,
    );
    final health = await api.updateConsent(
      consentType: 'health_data_processing',
      granted: _healthData,
    );
    final image = await api.updateConsent(
      consentType: 'image_cross_border_transfer',
      granted: _imageTransfer,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final failed = !notice.isSuccess || !health.isSuccess || !image.isSuccess;
    final message = failed
        ? 'Tercihleriniz kaydedilemedi. Lütfen tekrar deneyin.'
        : 'Tercihleriniz kaydedildi.';
    ref.read(accessibilityServiceProvider).speak(
          message,
          priority: TtsPriority.high,
        );
    if (failed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (widget.requiredForEntry) {
      final opened = await ref
          .read(authControllerProvider.notifier)
          .completePrivacyNoticeGate();
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aydınlatma teyidi doğrulanamadı. Tekrar deneyin.'),
          ),
        );
      }
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !widget.requiredForEntry,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.requiredForEntry,
          backgroundColor: Colors.transparent,
          title: const Text('Kişisel Verileriniz'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                children: [
                  _NoticeCard(),
                  const SizedBox(height: 12),
                  Semantics(
                    label: 'Aydınlatma metnini okuduğumu onayla',
                    checked: _noticeAcknowledged,
                    child: ExcludeSemantics(
                      child: CheckboxListTile(
                        key: const Key('privacy_notice_acknowledgement'),
                        value: _noticeAcknowledged,
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                  () => _noticeAcknowledged = value ?? false,
                                ),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          'Aydınlatma metnini okudum ve kişisel verilerimin nasıl '
                          'işlendiği hakkında bilgilendirildiğimi onaylıyorum.',
                        ),
                        subtitle: const Text(
                          'Bu onay açık rıza veya haklardan feragat anlamına gelmez.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    header: true,
                    child: Text(
                      'İzinleriniz',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Her izni ayrı ayrı verebilir, sonradan Ayarlar’dan geri '
                    'alabilirsiniz.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ConsentSwitch(
                    title: 'Sağlık verilerimin işlenmesi',
                    description:
                        'Besin kayıtları, kalori, kilo, uyku, su ve ruh hâli '
                        'bilgileri hesabınıza bağlı olarak saklanır. Bu izin '
                        'olmadan takip özellikleri çalışmaz.',
                    value: _healthData,
                    enabled: !_saving,
                    onChanged: (value) => setState(() => _healthData = value),
                  ),
                  const SizedBox(height: 12),
                  _ConsentSwitch(
                    title: 'Fotoğrafımın analiz için yurt dışına gönderilmesi',
                    description:
                        'Besin tanıma, fotoğrafı yurt dışındaki bir yapay zekâ '
                        'sağlayıcısına gönderir. İzin vermezseniz fotoğraf '
                        'gönderilmez; besinleri elle girerek uygulamayı '
                        'kullanmaya devam edebilirsiniz.',
                    value: _imageTransfer,
                    enabled: !_saving,
                    onChanged: (value) =>
                        setState(() => _imageTransfer = value),
                  ),
                  const SizedBox(height: 28),
                AccessibleButton(
                  label: 'Tercihlerimi Kaydet',
                    semanticLabel: 'Seçtiğiniz izinleri kaydeder',
                    icon: Icons.check_rounded,
                    isLoading: _saving,
                  onPressed: _save,
                ),
                if (widget.requiredForEntry) ...[
                  const SizedBox(height: 12),
                  AccessibleButton(
                    key: const Key('privacy_decline_logout'),
                    label: 'Kabul Etmeden Çıkış Yap',
                    semanticLabel:
                        'Aydınlatma teyidi vermeden güvenli biçimde çıkış yapar',
                    icon: Icons.logout_rounded,
                    type: AccessibleButtonType.outlined,
                    onPressed: _saving
                        ? null
                        : () => ref
                            .read(authControllerProvider.notifier)
                            .logout(),
                  ),
                ],
              ],
              ),
      ),
    );
  }
}

/// Aydınlatma metni. Rıza anahtarlarından ayrı bir bloktur.
class _NoticeCard extends StatelessWidget {
  static const _body =
      'NutriSense; hesabınız için e-posta, ad ve tercihlerinizi; hizmet için '
      'onayladığınız besin adı, porsiyon, kalori ve zaman bilgisini işler. '
      'Kilo, uyku, su ve ruh hâli gibi takip verileri de hesabınıza bağlı '
      'olarak saklanır.\n\n'
      'Besin tanıma sırasında fotoğraf geçici olarak işlenir ve '
      'yapılandırılmışsa yurt dışındaki bir sağlayıcıya gönderilebilir; '
      'fotoğraf cihazda veya sunucuda saklanmaz.\n\n'
      'Beslenme raporunuz yalnız siz her gönderim için ayrıca onay '
      'verdiğinizde, seçtiğiniz diyetisyene e-posta veya SMS ile iletilir.\n\n'
      'Verilerinizi görüntüleyebilir, düzeltebilir, dışa aktarabilir ve '
      'hesabınızı silerek tamamen kaldırabilirsiniz.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Aydınlatma metni. $_body',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Aydınlatma Metni',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_body, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              // Kurum alanları doldurulmadan bu metin nihai sayılmaz; eksik
              // olduğunu kullanıcıdan gizlemek yerine açıkça yazıyoruz.
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Bu sürüm taslaktır. Veri sorumlusu, saklama süreleri, '
                  'başvuru kanalı ve yurt dışı aktarım mekanizması kurum '
                  'tarafından tamamlanmadan yayına alınmamalıdır.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentSwitch extends StatelessWidget {
  const _ConsentSwitch({
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      toggled: value,
      label: '$title. $description',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
