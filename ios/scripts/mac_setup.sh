#!/bin/bash
# NutriSense — Mac üzerinde iOS doğrulama betiği.
#
# Tek komutla: ön koşulları denetler, bağımlılıkları kurar, iOS kaynağını
# imzasız derler ve bağlı bir cihaz/simülatör varsa P0 yolculuk testini koşar.
#
# Kullanım (depo kökünde):
#   bash ios/scripts/mac_setup.sh
#
# Bu betik imzalama, Archive veya TestFlight adımlarını YAPMAZ; onlar kurum
# kararı gerektirir ve docs/ios_release_runbook.md içinde anlatılır.

set -u

BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; OFF=$'\033[0m'
fail=0

step() { printf "\n${BOLD}==> %s${OFF}\n" "$1"; }
ok()   { printf "${GREEN}  ✓ %s${OFF}\n" "$1"; }
warn() { printf "${YELLOW}  ! %s${OFF}\n" "$1"; }
bad()  { printf "${RED}  ✗ %s${OFF}\n" "$1"; fail=1; }

if [ ! -f "pubspec.yaml" ] || [ ! -d "ios" ]; then
  bad "Bu betiği depo kökünde çalıştırın (pubspec.yaml ve ios/ görünmüyor)."
  exit 1
fi

step "1/6  Ön koşullar"
[ "$(uname)" = "Darwin" ] || bad "Bu betik macOS gerektirir."
if command -v xcodebuild >/dev/null 2>&1; then
  ok "Xcode: $(xcodebuild -version | head -1)"
else
  bad "Xcode bulunamadı. App Store'dan kurun, sonra: sudo xcode-select --switch /Applications/Xcode.app"
fi
if command -v flutter >/dev/null 2>&1; then
  ok "Flutter: $(flutter --version 2>/dev/null | head -1)"
else
  bad "Flutter bulunamadı: https://docs.flutter.dev/get-started/install/macos"
fi
if command -v pod >/dev/null 2>&1; then
  ok "CocoaPods: $(pod --version)"
else
  bad "CocoaPods bulunamadı. Kurulum: sudo gem install cocoapods"
fi
[ $fail -eq 1 ] && { printf "\n${RED}Ön koşullar eksik; yukarıdakileri tamamlayın.${OFF}\n"; exit 1; }

step "2/6  Flutter bağımlılıkları"
flutter pub get || bad "flutter pub get başarısız"

step "3/6  CocoaPods bağımlılıkları"
( cd ios && pod install --repo-update ) || bad "pod install başarısız"

step "4/6  Kaynak doğrulama kapısı"
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/qa/ios_release_checks.py | tail -3 || bad "iOS kaynak kapısı düştü"
else
  warn "python3 yok; kaynak kapısı atlandı"
fi

step "5/6  İmzasız derleme"
# iOS tarafinda flavor semasi tanimli degil (yalniz Runner semasi vardir);
# --flavor kullanmak "custom scheme yok" hatasi verir. Android'de flavor
# kullanilir, iOS'ta yalnizca APP_ENV tanimi gecilir.
if flutter build ios --no-codesign --dart-define=APP_ENV=dev; then
  ok "iOS kaynağı derlendi (imzasız)"
else
  bad "flutter build ios başarısız — çıktıdaki ilk hatayı runbook ile karşılaştırın"
fi

step "6/6  Cihaz/simülatör testi"
if flutter devices 2>/dev/null | grep -qiE "ios|iphone|ipad"; then
  ok "iOS cihazı bulundu; P0 yolculuk testi koşuluyor"
  flutter test integration_test/p0_fixture_journey_test.dart \
    --dart-define=APP_ENV=dev || bad "P0 yolculuk testi düştü"
else
  warn "Bağlı iOS cihazı/simülatörü yok; P0 testi atlandı."
  warn "Simülatör açmak için: open -a Simulator"
fi

printf "\n${BOLD}=== SONUÇ ===${OFF}\n"
if [ $fail -eq 0 ]; then
  printf "${GREEN}Kaynak doğrulaması tamam.${OFF}\n"
else
  printf "${RED}Bazı adımlar düştü; yukarıya bakın.${OFF}\n"
fi

cat <<'NOTE'

Bu betiğin YAPMADIĞI, insan kararı gereken adımlar:
  - Kurum bundle ID'si ve Apple Team seçimi
    (ios/Config/Project.xcconfig içindeki NUTRISENSE_BUNDLE_ID hâlâ
     com.example.nutrisense; Archive bu değerle bilerek engellenir)
  - İmzalı Archive / TestFlight yüklemesi
  - Gerçek iPhone'da VoiceOver ile elle erişilebilirlik testi
  - Kamera/ses kesintisi, bellek ve gecikme ölçümleri

Ayrıntılı adımlar: docs/ios_release_runbook.md
NOTE
exit $fail
