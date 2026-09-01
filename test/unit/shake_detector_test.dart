import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/shake_detector.dart';

/// Durgun telefonun okuduğu yerçekimi.
const _restingZ = 9.8;

void main() {
  late DateTime now;

  setUp(() => now = DateTime(2026, 9, 1, 12));

  DateTime at(int millis) => now.add(Duration(milliseconds: millis));

  test('durgun telefon tetiklemez', () {
    final analyzer = ShakeAnalyzer();
    for (var i = 0; i < 50; i++) {
      expect(analyzer.addSample(0.1, 0.2, _restingZ, at(i * 20)), isFalse);
    }
  });

  test('tek sarsıntı yeterli değildir', () {
    final analyzer = ShakeAnalyzer();
    // Cebe koyarken ya da masaya bırakırken oluşan tek darbe.
    expect(analyzer.addSample(30, 0, 0, at(0)), isFalse);
  });

  test('pencere içinde iki sarsıntı tetikler', () {
    final analyzer = ShakeAnalyzer();
    expect(analyzer.addSample(30, 0, 0, at(0)), isFalse);
    expect(analyzer.addSample(0, 30, 0, at(400)), isTrue);
  });

  test('sarsıntılar birbirinden uzaksa tetiklemez', () {
    final analyzer = ShakeAnalyzer();
    expect(analyzer.addSample(30, 0, 0, at(0)), isFalse);
    // Pencere 900 ms; yürürken seyrek gelen darbeler birikmemeli.
    expect(analyzer.addSample(30, 0, 0, at(1500)), isFalse);
    expect(analyzer.addSample(30, 0, 0, at(3000)), isFalse);
  });

  test('aynı sarsıntının ardışık örnekleri iki kez sayılmaz', () {
    final analyzer = ShakeAnalyzer();
    // Tek bir sarsıntı sensörde birkaç örnek üretir; 150 ms altındakiler
    // tek hareket sayılır.
    expect(analyzer.addSample(30, 0, 0, at(0)), isFalse);
    expect(analyzer.addSample(31, 0, 0, at(20)), isFalse);
    expect(analyzer.addSample(29, 0, 0, at(40)), isFalse);
  });

  test('tetiklemeden sonra bekleme süresi uygulanır', () {
    final analyzer = ShakeAnalyzer();
    analyzer.addSample(30, 0, 0, at(0));
    expect(analyzer.addSample(0, 30, 0, at(400)), isTrue);

    // Sallamaya devam etmek üst üste komut başlatmamalı.
    expect(analyzer.addSample(30, 0, 0, at(600)), isFalse);
    expect(analyzer.addSample(30, 0, 0, at(1000)), isFalse);

    // Bekleme dolunca yeniden tetiklenebilir.
    expect(analyzer.addSample(30, 0, 0, at(2500)), isFalse);
    expect(analyzer.addSample(0, 30, 0, at(2900)), isTrue);
  });

  test('eşik altındaki hareketler yok sayılır', () {
    final analyzer = ShakeAnalyzer(threshold: 22);
    // Telefonu eğmek veya yürümek bu aralıkta kalır.
    expect(analyzer.addSample(5, 5, _restingZ, at(0)), isFalse);
    expect(analyzer.addSample(8, 8, _restingZ, at(300)), isFalse);
  });

  test('reset biriken sarsıntıları siler', () {
    final analyzer = ShakeAnalyzer();
    analyzer.addSample(30, 0, 0, at(0));
    analyzer.reset();
    // Önceki sarsıntı sayılmadığı için tek başına tetiklemez.
    expect(analyzer.addSample(30, 0, 0, at(200)), isFalse);
  });
}
