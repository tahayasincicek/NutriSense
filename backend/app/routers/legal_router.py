"""Uygulama dışından erişilebilen hesap silme ve KVKK başvuru sayfaları.

Google Play, hesap açılan uygulamalardan uygulamayı kaldırmış kullanıcının da
ulaşabileceği bir hesap silme yolu ister. KVKK m.11 başvurusu için de veri
sorumlusu ve iletişim kanalı uygulama dışında bulunabilmelidir. Sayfalar form
içermez ve kişisel veri toplamaz. Production CSP inline stili engellediği için
yalnız anlamsal HTML kullanılır; ekran okuyucuyla da böyle daha iyi okunur.
"""

from html import escape

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

from ..config import get_settings

router = APIRouter(include_in_schema=False)


def _contact_section() -> str:
    settings = get_settings()
    name = settings.data_controller_name.strip()
    email = settings.data_controller_contact_email.strip()
    address = settings.data_controller_postal_address.strip()
    if not (name and email):
        return (
            "<p>Veri sorumlusunun adı ve başvuru adresi yayın öncesinde bu "
            "sayfaya eklenecektir.</p>"
        )
    items = [
        f"<dt>Veri sorumlusu</dt><dd>{escape(name)}</dd>",
        f'<dt>E-posta</dt><dd><a href="mailto:{escape(email, quote=True)}">'
        f"{escape(email)}</a></dd>",
    ]
    if address:
        items.append(f"<dt>Posta adresi</dt><dd>{escape(address)}</dd>")
    return "<dl>" + "".join(items) + "</dl>"


def _page(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        '<!doctype html><html lang="tr"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{escape(title)} - NutriSense</title></head>"
        f"<body><main><h1>{escape(title)}</h1>{body}</main></body></html>"
    )


@router.get("/gizlilik", response_class=HTMLResponse)
@router.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy_page():
    """Public, stable HTML privacy policy required by both app stores."""
    settings = get_settings()
    version = escape(settings.privacy_notice_version)
    return _page(
        "NutriSense gizlilik ve KVKK aydınlatma metni",
        f"<p><strong>Metin sürümü:</strong> {version}</p>"
        f"{_contact_section()}"
        "<h2>İşlenen veriler ve amaçlar</h2>"
        "<ul>"
        "<li>Ad, e-posta, telefon ve parola özeti: hesap, oturum ve güvenlik.</li>"
        "<li>Besin, porsiyon, kalori, zaman, kilo, su, uyku, ruh hâli ve adım "
        "verileri: kullanıcının beslenme ve yaşam takibi.</li>"
        "<li>Diyetisyen bağlantısı, rapor ve cevapları: kullanıcının her "
        "gönderimde verdiği onayla beslenme danışmanlığı.</li>"
        "<li>Kamera ve mikrofon: yalnız kullanıcının başlattığı besin tanıma "
        "ve sesli komut işlevleri.</li>"
        "</ul>"
        "<h2>Fotoğraf, ses ve cihaz içi işleme</h2>"
        "<p>Besin fotoğrafı uygulamayla gelen modelle cihazda işlenir; "
        "sunucuya gönderilmez ve NutriSense tarafından saklanmaz. Sesli komut "
        "kaydedilmez. İşletim sisteminin konuşma tanıma hizmeti, cihaz ve dil "
        "paketi durumuna göre Google veya Apple sunucularını kullanabilir. "
        "Sesli komut zorunlu değildir.</p>"
        "<h2>Paylaşım ve yurt dışı aktarım</h2>"
        "<p>Sağlık ayrıntıları yalnız kullanıcının onayladığı atanmış "
        "diyetisyenin giriş yaptığı panelde gösterilir. E-posta yalnız takma "
        "danışan kodu ve rapor referansı; SMS yalnız yeni rapor bildirimi "
        "taşır. Etkin sağlayıcıların ülkesi, alt işleyenleri ve KVKK m.9 "
        "aktarım mekanizması yayın öncesinde veri sorumlusu tarafından "
        "belirlenir ve bu metne eklenir.</p>"
        "<h2>Saklama ve silme</h2>"
        "<p>Hesap verileri hesap etkin olduğu sürece veya kullanıcı silene "
        "kadar tutulur. Bekleyen kayıtlar 30 dakika, IP güvenlik kayıtları "
        "en fazla 90 gün, diğer güvenlik olayları en fazla 365 gün tutulur. "
        "Hesap silindiğinde hesaba bağlı ürün verileri silinir; güvenlik "
        "kayıtlarının kullanıcı bağlantısı kaldırılır. Yedekler onaylı yedek "
        "saklama süresi sonunda imha edilir.</p>"
        "<h2>Haklar ve seçimler</h2>"
        "<p>Kullanıcı verisini uygulamadan düzeltebilir, dışa aktarabilir, "
        "amaç bazlı rızasını geri alabilir ve hesabını silebilir. KVKK m.11 "
        "hakları ve başvuru yöntemi için <a href=\"/kvkk-basvuru\">başvuru "
        "sayfasına</a>; hesap silme için <a href=\"/hesap-silme\">hesap "
        "silme sayfasına</a> bakın.</p>"
        "<h2>Sağlık hizmeti sınırı</h2>"
        "<p>NutriSense tıbbi teşhis veya tedavi sunmaz. Besin tanıma ve "
        "porsiyon sonuçları tahmindir; kullanıcı kaydetmeden önce sonucu "
        "kontrol eder.</p>",
    )


@router.get("/hesap-silme", response_class=HTMLResponse)
@router.get("/account-deletion", response_class=HTMLResponse)
async def account_deletion_page():
    return _page(
        "NutriSense hesabınızı silme",
        "<p>NutriSense hesabınızı ve hesabınıza bağlı verileri istediğiniz "
        "zaman silebilirsiniz.</p>"
        "<h2>Uygulamadan silme</h2>"
        "<ol>"
        "<li>Uygulamada Ayarlar sekmesini açın.</li>"
        "<li>Hesap Yönetimi bölümünde Hesabı Sil düğmesine basın.</li>"
        "<li>Parolanızı girip silmeyi onaylayın.</li>"
        "</ol>"
        "<h2>Uygulamaya erişemiyorsanız</h2>"
        "<p>NutriSense'e kayıtlı e-posta adresinizden aşağıdaki adrese "
        "“Hesap silme talebi” konulu bir e-posta gönderin. Yanıt yalnız kayıtlı "
        "adresinize verilir; parolanız hiçbir zaman istenmez. Talebiniz en geç "
        "30 gün içinde sonuçlandırılır.</p>"
        f"{_contact_section()}"
        "<h2>Silinen veriler</h2>"
        "<ul>"
        "<li>Ad, e-posta, telefon, parola özeti ve uygulama tercihleri</li>"
        "<li>Besin kayıtları ve tanıma denemeleri</li>"
        "<li>Su, adım, uyku, ruh hâli ve kilo ölçümleri</li>"
        "<li>Diyetisyen bağlantıları, gönderilen raporlar, diyetisyen notları ve "
        "rıza kayıtları</li>"
        "<li>Oturum anahtarları ve parola sıfırlama kodları</li>"
        "</ul>"
        "<h2>Hemen silinmeyen kayıtlar</h2>"
        "<ul>"
        "<li>Güvenlik kayıtları, sizinle bağlantısı kaldırılarak saklama süresi "
        "sonuna kadar tutulur.</li>"
        "<li>Veritabanı yedeklerindeki kopyalar, yedek saklama süresi dolduğunda "
        "silinir.</li>"
        "<li>Diyetisyene daha önce gönderilen e-posta veya SMS bildirimleri "
        "alıcıda ve ileti sağlayıcısında kalabilir. Bu bildirimler sağlık "
        "bilgisi içermez.</li>"
        "<li>Araştırmaya katıldıysanız araştırma verisi hesabınızdan ayrı, "
        "takma kimlikle tutulur. Silinmesi için size verilen çekilme kodunu "
        "kullanın.</li>"
        "</ul>"
        '<p><a href="/kvkk-basvuru">KVKK kapsamındaki haklarınız ve başvuru '
        "yolu</a></p>",
    )


@router.get("/kvkk-basvuru", response_class=HTMLResponse)
async def data_subject_request_page():
    return _page(
        "KVKK kapsamındaki haklarınız ve başvuru",
        "<p>6698 sayılı Kişisel Verilerin Korunması Kanunu'nun 11. maddesi "
        "uyarınca veri sorumlusuna başvurarak şunları isteyebilirsiniz:</p>"
        "<ul>"
        "<li>Kişisel verinizin işlenip işlenmediğini öğrenme, işlenmişse bilgi "
        "isteme</li>"
        "<li>İşleme amacını ve verinin amacına uygun kullanılıp "
        "kullanılmadığını öğrenme</li>"
        "<li>Verinizin yurt içinde veya yurt dışında aktarıldığı üçüncü "
        "kişileri bilme</li>"
        "<li>Eksik veya yanlış işlenmiş verinin düzeltilmesini ve bunun "
        "aktarılan kişilere bildirilmesini isteme</li>"
        "<li>İşleme şartları ortadan kalkmışsa verinin silinmesini veya yok "
        "edilmesini ve bunun aktarılan kişilere bildirilmesini isteme</li>"
        "<li>Yalnız otomatik sistemlerle yapılan analiz sonucunda aleyhinize "
        "bir sonuç çıkmasına itiraz etme</li>"
        "<li>Kanuna aykırı işleme nedeniyle zarara uğrarsanız zararın "
        "giderilmesini isteme</li>"
        "</ul>"
        "<p>Uygulamada verdiğiniz açık rızaları Ayarlar içindeki Kişisel "
        "Verilerim ve İzinler bölümünden istediğiniz zaman geri alabilirsiniz.</p>"
        "<h2>Başvuru yolu</h2>"
        "<p>Başvurunuzu yazılı olarak ya da NutriSense'e kayıtlı e-posta "
        "adresinizden aşağıdaki kanala iletebilirsiniz. Adınızı soyadınızı, "
        "kayıtlı e-posta adresinizi, talebinizi ve yanıtın hangi yolla "
        "verilmesini istediğinizi yazın. Kimliğinizi doğrulamak için ek bilgi "
        "istenebilir; parolanız hiçbir zaman istenmez.</p>"
        f"{_contact_section()}"
        "<p>Başvurunuz en geç 30 gün içinde ücretsiz sonuçlandırılır. İşlem "
        "ayrıca bir maliyet gerektirirse Kişisel Verileri Koruma Kurulunun "
        "belirlediği tarife uygulanabilir.</p>"
        "<p>Başvurunuz reddedilir, yanıtı yetersiz bulunur ya da süresinde "
        "yanıtlanmazsa yanıtı öğrendiğiniz tarihten itibaren 30 gün, her hâlde "
        "başvuru tarihinden itibaren 60 gün içinde Kişisel Verileri Koruma "
        "Kuruluna şikâyette bulunabilirsiniz.</p>"
        '<p><a href="/hesap-silme">Hesabınızı silme</a></p>',
    )
