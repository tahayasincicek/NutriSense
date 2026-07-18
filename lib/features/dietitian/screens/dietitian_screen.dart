import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/accessibility_utils.dart';
import '../../../shared/models/auth_model.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/accessible_button.dart';
import 'send_report_wizard.dart';

class DietitianScreen extends ConsumerStatefulWidget {
  const DietitianScreen({super.key});

  @override
  ConsumerState<DietitianScreen> createState() => _DietitianScreenState();
}

class _DietitianScreenState extends ConsumerState<DietitianScreen> {
  final _email = TextEditingController();
  DietitianAssignmentInfo? _assignment;
  bool _loading = true;
  String? _error;

  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diyetisyen')),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Semantics(
                  liveRegion: true,
                  label: 'Diyetisyen ataması yükleniyor',
                  child: const CircularProgressIndicator(),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null) _errorCard(_error!),
                    if (_assignment == null)
                      _setupCard()
                    else
                      _assignmentCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _errorCard(String message) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Semantics(liveRegion: true, child: Text(message)),
        ),
      );

  Widget _setupCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Diyetisyen Kurulumu',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Yalnızca sistemde kayıtlı ve e-posta veya telefonu doğrulanmış '
                'bir diyetisyen atanabilir. Atama ayrıca sizin onayınızı gerektirir.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Diyetisyen e-posta adresi',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 20),
              AccessibleButton(
                label: 'Doğrulanmış Diyetisyen Bul',
                icon: Icons.person_search_outlined,
                onPressed: _requestAssignment,
              ),
            ],
          ),
        ),
      );

  Widget _assignmentCard() {
    final assignment = _assignment!;
    final approved = assignment.isApproved;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(assignment.dietitianName,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(approved ? 'Atama onaylandı' : 'Onayınız bekleniyor'),
            const SizedBox(height: 8),
            Text(
              'Doğrulanmış iletişim: '
              '${assignment.emailVerified ? "e-posta ${assignment.emailMasked ?? "***"}" : ""}'
              '${assignment.emailVerified && assignment.phoneVerified ? ", " : ""}'
              '${assignment.phoneVerified ? "telefon ${assignment.phoneMasked ?? "***"}" : ""}',
            ),
            const SizedBox(height: 20),
            if (!approved) ...[
              AccessibleButton(
                label: 'Atamayı Onayla',
                icon: Icons.verified_user_outlined,
                onPressed: _approveAssignment,
              ),
              const SizedBox(height: 12),
            ],
            if (approved) ...[
              AccessibleButton(
                label: 'Raporu Önizle ve Gönder',
                icon: Icons.send_outlined,
                onPressed: _sendReport,
              ),
              const SizedBox(height: 12),
            ],
            AccessibleButton(
              label: approved
                  ? 'Diyetisyen Atamasını İptal Et'
                  : 'İsteği İptal Et',
              type: AccessibleButtonType.outlined,
              icon: Icons.person_remove_outlined,
              onPressed: _cancelAssignment,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAssignment() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showError('Geçerli bir diyetisyen e-posta adresi girin.');
      return;
    }
    final result = await _api.requestDietitianAssignment(email: email);
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _assignment = result.data);
      AccessibilityUtils.announceSuccess(
          'Diyetisyen bulundu. Atama onayınızı bekliyor.');
    } else {
      _showError(result.errorMessage ?? 'Diyetisyen ataması oluşturulamadı.');
    }
  }

  Future<void> _approveAssignment() async {
    final result = await _api.approveDietitianAssignment(
      assignmentId: _assignment!.assignmentId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() => _assignment = result.data);
      AccessibilityUtils.announceSuccess('Diyetisyen ataması onaylandı.');
    } else {
      _showError(result.errorMessage ?? 'Atama onaylanamadı.');
    }
  }

  Future<void> _cancelAssignment() async {
    final result = await _api.cancelDietitianAssignment(
      assignmentId: _assignment!.assignmentId,
    );
    if (!mounted) return;
    if (result.isSuccess) {
      setState(() {
        _assignment = null;
      });
      AccessibilityUtils.announceSuccess('Diyetisyen ataması iptal edildi.');
    } else {
      _showError(result.errorMessage ?? 'Atama iptal edilemedi.');
    }
  }

  Future<void> _sendReport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendReportWizard(assignment: _assignment!),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    AccessibilityUtils.announceError(message);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }
}
