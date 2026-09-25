# Akşam teslim tamamlama rehberi

Bu rehber proje tesliminden sonra ayrıca toplanabilecek gerçek saha, fiziksel
iPhone ve yayın kanıtları içindir. Danışman onaylı proje teslimi bu kayıtlara
bağlı değildir. Harici kanıtların durumunu görüntülemek için:

```powershell
.\scripts\verify_tubitak_delivery.ps1 ExternalEvidence
```

## 1. Gerçek saha çalışması

Katılımcı çağırmadan önce kurum/danışman tarafından verilen gerçek etik onay
referansı, protokol sürümü ve onam sürümü `backend/.env` içinde tanımlanmalıdır.
Hazırlık kontrolü değerleri ekrana yazmadan yalnız varlıklarını doğrular:

```powershell
docker compose -f backend/docker-compose.yml up -d --build --wait
.\scripts\check_research_readiness.ps1
```

Kontrol `PASS` olduktan sonra
`docs/research/researcher_session_script.md` uygulanır. Uygulamadaki anket ve
kullanılabilirlik ekranlarıyla onamlı kayıtlar oluşturulur. Katılımcı verisi
ve geri çekilme kodları GitHub'a eklenmez.

Oturumlar tamamlanınca export tokenini güvenli istemle alın ve analizi çalıştırın:

```powershell
$env:RESEARCH_EXPORT_TOKEN = Read-Host -MaskInput "Araştırma export tokeni"
.\scripts\run_real_field_analysis.ps1
Remove-Item Env:RESEARCH_EXPORT_TOKEN
```

Bu komut boş veya gerçek veriyle sonuç üretmez. Gerçek veri uygunsa tablo,
grafik ve istatistiksel sonuç manifestini otomatik oluşturur.

## 2. Fiziksel iPhone ve VoiceOver

Test Mac ve gerçek iPhone üzerinde yapılır. Uygulamayı test edilen commit'ten
kurun, VoiceOver'ı açın ve `docs/erisebilirlik_cihaz_kabul_kaydi.md` içindeki
dokuz senaryoyu uygulayın. Oturum notunu veya ekran kaydını bilgisayara alın:

```powershell
.\scripts\record_voiceover_acceptance.ps1
```

Betik cihaz ve iOS sürümünü sorar, her senaryoyu ayrı ayrı `pass/fail` olarak
kaydeder, git revision'ını otomatik ekler ve kanıt dosyasını Git tarafından
yok sayılan yerel klasöre kopyalar.

## 3. Yaygınlaştırma

Hazır metin `docs/yayginlastirma_paketi.md` içindedir. Sunum veya yayın gerçekten
gerçekleştikten sonra herkese açık bağlantıyı ya da katılım/sunum belgesini
kaydedin:

```powershell
.\scripts\record_dissemination_evidence.ps1
```

Planlanan etkinlik tamamlandı sayılmaz; doğrulama yalnız `presented` veya
`published` durumunu ve gerçek kanıtı kabul eder.

## 4. Son doğrulama

```powershell
.\scripts\verify_tubitak_delivery.ps1 ExternalEvidence
```

Üç satırın da `PASS` olması SMS dışındaki dış teslim kanıtlarının tamamlandığını
gösterir. Kanıt dosyaları kişisel veri riski nedeniyle GitHub'a gönderilmez;
depo yalnız boş şablonları ve doğrulama kodunu içerir.

