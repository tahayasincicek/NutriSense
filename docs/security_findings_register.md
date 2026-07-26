# Güvenlik bulguları kaydı

Durum tarihi: 2026-07-26

Terminler teknik hedef tarihlerdir; kurumun production veya gerçek katılımcı
başlangıcı daha erkense ilgili madde başlangıçtan **önce** kapanmalıdır.

| ID | Seviye | Bulgu | Durum | Sahip | Termin | Kanıt / Definition of Done |
|---|---|---|---|---|---|---|
| SEC-001 | P0 | Env/signing/dump/raw research ignore kapsamı yetersiz | Kapalı | Repo sahibi | 2026-07-26 | `8ee5da2`; tree+history scanner PASS |
| SEC-002 | P0 | Production default secret/debug/HTTP/CORS/docs fail-closed değildi | Kapalı | Backend | 2026-07-26 | `621e075`; production settings testleri |
| SEC-003 | P0 | JWT kütüphanesi zincirinde düzeltmesiz HIGH CVE | Kapalı | Backend | 2026-07-26 | `df09efb`; PyJWT geçişi; pip-audit PASS |
| SEC-004 | P1 | TLS termination/cipher/certificate kanıtı yok | Açık | DevOps | 2026-08-02 veya production öncesi | TLS scan, redirect, HSTS ve proxy config artefaktı |
| SEC-005 | P1 | DB disk/yedek şifreleme ve restore-sonrası-silme kanıtı yok | Açık | DevOps + veri sorumlusu | 2026-08-09 veya gerçek veri öncesi | Sağlayıcı config, anahtar sahipliği, restore ve silme testi |
| SEC-006 | P1 | Dış sağlayıcı DPA/yurtdışı aktarım/hukuki sebep kararı yok | Açık | Üniversite veri sorumlusu + hukuk | 2026-08-09 veya production/katılımcı öncesi | İmzalı/onarılmış kayıt ve güncel aydınlatma |
| SEC-007 | P1 | Gerçek cihaz secure storage/network/log sızıntı testi yok | Açık | Mobil QA | 2026-08-09 | Android cihaz kanıtı; iOS platformu yoksa blocker |
| SEC-008 | P1 | Diyetisyen kimlik doğrulama otoritesi tanımlı değil | Açık | Ürün + kurum | 2026-08-09 veya gerçek rapor öncesi | Yetkili kayıt/doğrulama prosedürü ve kötüye kullanım testi |
| SEC-009 | P2 | Rate limit süreç belleğinde; çok instance'ta aşılabilir | Açık | Backend/DevOps | 2026-08-16 | Redis/API gateway limiti, concurrency ve 429 testi |
| SEC-010 | P2 | Genel yönetici/diyetisyen kimlik sistemi yok; tam RBAC iddiası yapılamaz | Açık | Backend + ürün | 2026-08-23 | Rol matrisi, authn/authz, deny-by-default testleri |
| SEC-011 | P2 | Profil e-posta değişimi ve reverification akışı yok | Açık | Backend + mobil | 2026-08-23 | Sahiplik, generic mesaj, token revocation ve test |
| SEC-012 | P2 | Crashlytics kapalı; etkinleştirme için privacy/consent yok | Kabul edilmiş | Ürün + veri sorumlusu | Etkinleştirme talebinden önce | Kapalı kalır veya DPIA/onam/redaksiyon/retention kanıtı |
| SEC-013 | P1 | Backup/provider kopyalarında hesap/araştırma silme prosedürü kanıtsız | Açık | Veri sorumlusu + DevOps | 2026-08-09 veya gerçek veri öncesi | Uçtan uca silme bileti, backup expiry ve provider sonucu |

P0 açık bulgu şu an yoktur. Bu ifade yalnız yukarıdaki depo içi kontroller
içindir; P1 deployment/hukuk/gerçek cihaz kapıları kapanmadan production veya
gerçek katılımcı çalışması güvenli/uygun ilan edilemez.
