import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/accessibility_service.dart';
import '../../../shared/services/voice_command_service.dart';
import '../../discover/widgets/discover_background.dart';
import '../state/history_controller.dart';

class FoodShortcutsScreen extends ConsumerStatefulWidget {
  const FoodShortcutsScreen(
      {super.key, this.openUndo = false, this.breakfast = false});
  final bool openUndo;
  final bool breakfast;
  @override
  ConsumerState<FoodShortcutsScreen> createState() => _FoodShortcutsState();
}

class _FoodShortcutsState extends ConsumerState<FoodShortcutsScreen> {
  List<Map<String, dynamic>> _meals = [];
  Map<String, dynamic>? _undo;
  bool _loading = true;
  bool _busy = false;
  bool _confirming = false;
  String? _error;
  BuildContext? _confirmationContext;
  late final VoiceCommandService _voice;
  late final OnCommandRecognized _handler;
  OnCommandRecognized? _previous;
  final Map<String, String> _requestIds = {};
  AccessibilityService get _tts => ref.read(accessibilityServiceProvider);
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceCommandServiceProvider);
    _previous = _voice.onCommandRecognized;
    _handler = _command;
    _voice.onCommandRecognized = _handler;
    _load(initial: true);
  }

  @override
  void dispose() {
    if (identical(_voice.onCommandRecognized, _handler)) {
      _voice.onCommandRecognized = _previous;
    }
    super.dispose();
  }

  String _mealName(Map<String, dynamic> meal) => switch (meal['meal_type']) {
        'kahvalti' => 'Kahvaltı',
        'ogle' => 'Öğle yemeği',
        'aksam' => 'Akşam yemeği',
        _ => 'Ara öğün',
      };
  String _contents(Map<String, dynamic> meal) =>
      (meal['items'] as List).map((raw) {
        final item = raw as Map;
        return '${item['name']}, ${item['grams']} gram${item['estimated'] == true ? ' (tahmini porsiyon)' : ''}, ${item['calories']} kalori';
      }).join('. ');

  Future<void> _load({bool initial = false}) async {
    final result = await _api.getFoodShortcuts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.isSuccess ? null : result.errorMessage;
      if (result.isSuccess) {
        _meals = (result.data!['meals'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        _undo = result.data!['undo'] == null
            ? null
            : Map<String, dynamic>.from(result.data!['undo'] as Map);
      }
    });
    if (!result.isSuccess) {
      await _tts.speakError(_error ?? 'Kayıtlar yüklenemedi.');
      return;
    }
    if (initial && widget.openUndo) {
      await _undoLast();
      return;
    }
    if (initial && widget.breakfast) {
      final meals = _meals.where((m) => m['meal_type'] == 'kahvalti');
      if (meals.isNotEmpty) {
        await _repeat(meals.first);
        return;
      }
      await _tts.speak('Geçmişinizde tekrar eklenebilecek kahvaltı yok.');
    } else if (initial) {
      await _readOptions();
    }
  }

  Future<void> _readOptions() {
    final options = List.generate(
            _meals.length,
            (i) =>
                '${i + 1}. ${_mealName(_meals[i])}. ${_contents(_meals[i])}.')
        .join(' ');
    final instruction = _meals.isEmpty
        ? 'Henüz önerilecek öğün yok.'
        : 'Seçmek için birinci öğün, ikinci öğün gibi sıra numarasını söyleyin. $options';
    return _tts.speak(
        'Besin kısayolları. Son işlemi geri al diyebilirsiniz. $instruction',
        priority: TtsPriority.high);
  }

  void _command(CommandResult result) {
    if (!mounted || _busy) return;
    final text = result.rawText
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .trim();
    final dialog = _confirmationContext;
    if (dialog != null) {
      if (['evet', 'onayliyorum', 'hayir', 'iptal', 'vazgec'].contains(text)) {
        _confirmationContext = null;
        Navigator.pop(dialog, ['evet', 'onayliyorum'].contains(text));
      } else {
        unawaited(
            _tts.speak('Onaylamak için evet, vazgeçmek için hayır deyin.'));
      }
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (text == 'son islemi geri al') {
      unawaited(_undoLast());
      return;
    }
    if (text == 'geri' || text == 'iptal') {
      Navigator.pop(context);
      return;
    }
    const numbers = [
      'birinci',
      'ikinci',
      'ucuncu',
      'dorduncu',
      'besinci',
      'altinci',
      'yedinci',
      'sekizinci'
    ];
    for (var i = 0; i < _meals.length; i++) {
      if (text == '${numbers[i]} ogun' ||
          text == '${i + 1}. ogun' ||
          text == '${i + 1} ogun') {
        unawaited(_repeat(_meals[i]));
        return;
      }
    }
    unawaited(_readOptions());
  }

  Future<bool> _confirm(String title, String content) async {
    _confirming = true;
    unawaited(_tts.speak(
        '$title. $content Onaylamak için evet, vazgeçmek için hayır deyin.',
        priority: TtsPriority.high));
    final answer = await showDialog<bool>(
        context: context,
        builder: (dialog) {
          _confirmationContext = dialog;
          return AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: Text(content)),
              actions: [
                IconButton(
                    tooltip: 'Sesli onayı dinle',
                    onPressed: _voice.toggleListening,
                    icon: const Icon(Icons.mic_none)),
                TextButton(
                    onPressed: () {
                      _confirmationContext = null;
                      Navigator.pop(dialog, false);
                    },
                    child: const Text('Vazgeç')),
                FilledButton(
                    onPressed: () {
                      _confirmationContext = null;
                      Navigator.pop(dialog, true);
                    },
                    child: const Text('Onayla')),
              ]);
        });
    _confirmationContext = null;
    _confirming = false;
    return answer == true;
  }

  Future<void> _repeat(Map<String, dynamic> meal) async {
    if (_busy || _confirming) return;
    final approved = await _confirm(
        '${_mealName(meal)} tekrar eklensin mi?',
        '${_contents(meal)}. Önceki kaydın miktarları ve besin değerleriyle bugün eklenecek. '
            'Otomatik paylaşım açıksa yeni kayıtlar paylaşılır.');
    if (!approved || !mounted || _busy) return;
    final hash = meal['context_hash'] as String;
    await _apply('repeat', {
      'request_id': _requestIds.putIfAbsent(hash, () => const Uuid().v4()),
      'log_ids': meal['log_ids'],
      'context_hash': hash,
      'confirmed': true
    });
  }

  Future<void> _undoLast() async {
    if (_busy || _confirming) return;
    final undo = _undo;
    if (undo == null) {
      await _tts.speak('Geri alınabilecek son besin işlemi yok.');
      return;
    }
    final approved = await _confirm(
        'Son besin işlemi geri alınsın mı?',
        '${undo['label']}: ${undo['summary']}. Yalnız bu besin işlemi geri alınır. '
            'Daha önce gönderilmiş e-posta ve SMS raporları geri çekilmez.');
    if (!approved || !mounted || _busy) return;
    await _apply('undo', {
      'action_id': undo['action_id'],
      'context_hash': undo['context_hash'],
      'confirmed': true
    });
  }

  Future<void> _apply(String action, Map<String, dynamic> data) async {
    setState(() => _busy = true);
    final result = await _api.applyFoodShortcut(action, data);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.isSuccess ? null : result.errorMessage;
    });
    final message = result.isSuccess
        ? result.data!['message'] as String
        : result.errorMessage ?? 'İşlem tamamlanamadı.';
    await _tts.speak(message, priority: TtsPriority.high);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    if (result.isSuccess) {
      if (action == 'repeat') _requestIds.remove(data['context_hash']);
      unawaited(ref.read(historyControllerProvider.notifier).refresh());
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => DiscoverBackground(
          child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
            title: const Text('Besin kısayolları'),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                  tooltip: 'Sesli komut',
                  onPressed: _busy ? null : _voice.toggleListening,
                  icon: const Icon(Icons.mic_none_rounded))
            ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                    20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (_busy) const LinearProgressIndicator(),
                  if (_error != null)
                    Text(_error!, semanticsLabel: 'Hata: $_error'),
                  OutlinedButton.icon(
                      onPressed: _busy || _undo == null ? null : _undoLast,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Son besin işlemini geri al')),
                  Text(_undo == null
                      ? 'Geri alınabilecek işlem yok.'
                      : '${_undo!['label']}: ${_undo!['summary']}'),
                  const SizedBox(height: 24),
                  Text('Sık tüketilen öğünler',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Son 90 günlük kayıtlarınızdan önerilir. Aynı günün aynı öğünündeki besinler birlikte gösterilir.'),
                  if (_meals.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                            'Onaylı besin kayıtlarınız oluştukça öğünleriniz burada görünecek.')),
                  for (var i = 0; i < _meals.length; i++)
                    Card(
                        margin: const EdgeInsets.only(top: 16),
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${i + 1}. ${_mealName(_meals[i])}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                      '${_meals[i]['frequency']} kez kaydedildi'),
                                  const SizedBox(height: 10),
                                  Text(_contents(_meals[i])),
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                      onPressed: _busy
                                          ? null
                                          : () => _repeat(_meals[i]),
                                      icon: const Icon(Icons.add_rounded),
                                      label:
                                          const Text('Önizle ve tekrar ekle')),
                                ]))),
                ],
              ),
      ));
}
