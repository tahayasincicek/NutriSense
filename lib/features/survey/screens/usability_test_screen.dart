// =============================================================================
// lib/features/survey/screens/usability_test_screen.dart
// NutriSense — Kullanılabilirlik Testi Kayıt Ekranı
//
// Araştırmacılar için: görev zamanlama, başarı işaretleme, not girişi.
// Oturumu JSON olarak dışa aktarma.
// =============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../models/survey_model.dart';
import '../services/survey_service.dart';

class UsabilityTestScreen extends ConsumerStatefulWidget {
  const UsabilityTestScreen({super.key});

  @override
  ConsumerState<UsabilityTestScreen> createState() =>
      _UsabilityTestScreenState();
}

class _UsabilityTestScreenState extends ConsumerState<UsabilityTestScreen> {
  late SurveyService _surveyService;
  late UsabilitySession _session;

  final _participantController = TextEditingController();
  final _generalNoteController = TextEditingController();
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    _surveyService = ref.read(surveyServiceProvider);
    _initSession();
  }

  void _initSession() {
    _session = UsabilitySession(
      id: const Uuid().v4(),
      participantId: '',
      tasks: defaultUsabilityTasks(),
    );
  }

  @override
  void dispose() {
    _participantController.dispose();
    _generalNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanılabilirlik Testi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportSession,
            tooltip: 'JSON Dışa Aktar',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSession,
            tooltip: 'Paylaş',
          ),
        ],
      ),
      body: _sessionStarted ? _buildTaskList(theme) : _buildSetupScreen(theme),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KURULUM EKRANI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSetupScreen(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Text(
            'Kullanılabilirlik Testi',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Araştırmacı arayüzü — katılımcı görev performansını kaydedin.',
            style: theme.textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),

          // Katılımcı ID
          Semantics(
            label: 'Katılımcı kimliği giriş alanı',
            textField: true,
            child: TextField(
              key: const Key('usability_participant_id'),
              controller: _participantController,
              decoration: InputDecoration(
                labelText: 'Katılımcı ID',
                hintText: 'Örn: P001',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Görev listesi özeti
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Görevler (${_session.tasks.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._session.tasks.map((t) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.circle,
                              size: 8,
                              color: Theme.of(context).colorScheme.outline),
                          const SizedBox(width: 8),
                          Text(t.title, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          const Spacer(),

          // Başlat butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_participantController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Katılımcı ID zorunludur')),
                  );
                  return;
                }
                setState(() {
                  _session = UsabilitySession(
                    id: _session.id,
                    participantId: _participantController.text,
                    tasks: _session.tasks,
                  );
                  _sessionStarted = true;
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Testi Başlat', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÖREV LİSTESİ
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTaskList(ThemeData theme) {
    return Column(
      children: [
        // Katılımcı bilgisi + başarı oranı
        _buildSessionHeader(theme),

        // Görev kartları
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _session.tasks.length + 1, // +1 genel not
            itemBuilder: (context, index) {
              if (index == _session.tasks.length) {
                return _buildGeneralNote(theme);
              }
              return _buildTaskCard(_session.tasks[index], index, theme);
            },
          ),
        ),

        // Oturumu kaydet
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSession,
              icon: const Icon(Icons.save),
              label:
                  const Text('Oturumu Kaydet', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      // Oturum özeti tek duyuru olarak okunur; başarı oranı araştırmacının
      // anlık olarak izlediği ölçüttür.
      child: Semantics(
        container: true,
        liveRegion: true,
        excludeSemantics: true,
        label: 'Katılımcı ${_session.participantId}. '
            'Başarı oranı yüzde '
            '${_session.successRate.toStringAsFixed(0)}.',
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Katılımcı: ${_session.participantId}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Başarı: %${_session.successRate.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÖREV KARTI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTaskCard(UsabilityTask task, int index, ThemeData theme) {
    final statusColors = {
      TaskStatus.notStarted: Theme.of(context).colorScheme.outline,
      TaskStatus.inProgress: Colors.blue,
      TaskStatus.completed: Colors.green,
      TaskStatus.failed: Colors.red,
    };

    final statusLabels = {
      TaskStatus.notStarted: 'Başlamadı',
      TaskStatus.inProgress: 'Devam Ediyor',
      TaskStatus.completed: 'Başarılı',
      TaskStatus.failed: 'Başarısız',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Görev başlığı ve durumu tek duyuru olarak okunur; parça parça
            // gezmek yerine "1. görev: Besin tarama. Durum: Başlamadı."
            Semantics(
              container: true,
              excludeSemantics: true,
              label: '${index + 1}. görev: ${task.title}. '
                  '${task.description}. '
                  'Durum: ${statusLabels[task.status] ?? ""}.',
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColors[task.status]?.withOpacity(0.15),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: statusColors[task.status],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(task.description,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  // Durum etiketi
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColors[task.status]?.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    child: Text(
                      statusLabels[task.status] ?? '',
                      style: TextStyle(
                        color: statusColors[task.status],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Süre bilgisi
            if (task.durationSeconds != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  label: 'Tamamlanma süresi '
                      '${task.durationSeconds!.toStringAsFixed(1)} saniye',
                  excludeSemantics: true,
                  child: Text(
                    '⏱ Süre: ${task.durationSeconds!.toStringAsFixed(1)} saniye',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            // Kontrol butonları
            Row(
              children: [
                // Başla / Durdur
                if (task.status == TaskStatus.notStarted)
                  _actionButton(
                    label: 'Başlat',
                    semanticLabel: '${task.title} görevini başlat',
                    icon: Icons.play_arrow,
                    color: Colors.blue,
                    onPressed: () => _startTask(task),
                  )
                else if (task.status == TaskStatus.inProgress) ...[
                  _actionButton(
                    label: 'Başarılı',
                    semanticLabel:
                        '${task.title} görevini başarılı olarak işaretle',
                    icon: Icons.check,
                    color: Colors.green,
                    onPressed: () => _completeTask(task, TaskStatus.completed),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    label: 'Başarısız',
                    semanticLabel:
                        '${task.title} görevini başarısız olarak işaretle',
                    icon: Icons.close,
                    color: Colors.red,
                    onPressed: () => _completeTask(task, TaskStatus.failed),
                  ),
                ] else
                  _actionButton(
                    label: 'Sıfırla',
                    semanticLabel: '${task.title} görevini sıfırla',
                    icon: Icons.refresh,
                    color: Colors.grey,
                    onPressed: () => _resetTask(task),
                  ),

                const Spacer(),

                // Not ekle
                IconButton(
                  icon: Icon(
                    task.researcherNote != null
                        ? Icons.note
                        : Icons.note_add_outlined,
                    color: task.researcherNote != null
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                  onPressed: () => _addTaskNote(task),
                  tooltip: task.researcherNote != null
                      ? '${task.title} görevindeki notu düzenle'
                      : '${task.title} görevine not ekle',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? semanticLabel,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: color),
      // Aynı ekranda birden çok "Başlat" bulunur; ekran okuyucunun hangi
      // göreve ait olduğunu söyleyebilmesi için etiket göreve özgüdür.
      label: Semantics(
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: Text(label, style: TextStyle(color: color, fontSize: 13)),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENEL NOT ALANI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGeneralNote(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📝 Genel Araştırmacı Notu',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _generalNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Oturumla ilgili genel gözlemlerinizi yazın...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (text) {
                _session.generalNote = text;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GÖREV KONTROL FONKSİYONLARI
  // ═══════════════════════════════════════════════════════════════════════════

  void _startTask(UsabilityTask task) {
    setState(() {
      task.status = TaskStatus.inProgress;
      task.startTime = DateTime.now();
    });
  }

  void _completeTask(UsabilityTask task, TaskStatus status) {
    setState(() {
      task.status = status;
      task.endTime = DateTime.now();
    });
  }

  void _resetTask(UsabilityTask task) {
    setState(() {
      task.status = TaskStatus.notStarted;
      task.startTime = null;
      task.endTime = null;
      task.researcherNote = null;
    });
  }

  void _addTaskNote(UsabilityTask task) {
    final controller = TextEditingController(text: task.researcherNote ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Not: ${task.title}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Araştırmacı notu...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => task.researcherNote = controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KAYDETME VE DIŞA AKTARMA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveSession() async {
    _session.generalNote = _generalNoteController.text;
    await _surveyService.saveUsabilitySession(_session);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oturum kaydedildi. Başarı oranı: %${_session.successRate.toStringAsFixed(0)}',
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _exportSession() async {
    _session.generalNote = _generalNoteController.text;
    final json = await _surveyService.exportAllSessions();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/usability_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(json);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarıldı: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dışa aktarma hatası: $e')),
      );
    }
  }

  Future<void> _shareSession() async {
    _session.generalNote = _generalNoteController.text;
    final json = await _surveyService.exportAllSessions();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nutrisense_usability.json');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'NutriSense Kullanılabilirlik Test Sonuçları',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşma hatası: $e')),
      );
    }
  }
}
