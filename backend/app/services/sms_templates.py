# ==============================================================================
# backend/app/services/sms_templates.py
# NutriSense — Twilio SMS Şablonları
#
# Diyetisyene gönderilecek kısa ve bilgilendirici SMS metinleri.
# SMS karakter sınırı: 160 karakter (Türkçe karakterler 70 char/segment)
# ==============================================================================

def build_report_sms(
    patient_name: str,
    from_date: str,
    to_date: str,
    avg_daily_calories: float,
    total_days: int,
    total_meals: int,
    alert_count: int = 0,
) -> str:
    """
    Beslenme raporu SMS metni oluşturur.

    Format:
        NutriSense: [Hasta]
        [Tarih]: [kalori] kcal/gün
        [Gün sayısı] gün, [Öğün] öğün
        Detay: e-posta
        [Uyarı varsa]

    Args:
        patient_name: Hasta adı
        from_date: Başlangıç tarihi (gg.aa.yyyy)
        to_date: Bitiş tarihi (gg.aa.yyyy)
        avg_daily_calories: Günlük ortalama kalori
        total_days: Toplam gün
        total_meals: Toplam öğün
        alert_count: Dikkat çeken değer sayısı

    Returns:
        SMS metni (max ~160 karakter)
    """
    # Temel metin
    sms = (
        f"NutriSense: {patient_name}\n"
        f"{from_date}-{to_date}: "
        f"{avg_daily_calories:.0f} kcal/gun\n"
        f"{total_days} gun, {total_meals} ogun"
    )

    # Uyarı varsa ekle
    if alert_count > 0:
        sms += f"\n⚠ {alert_count} dikkat gerektiren deger"

    # E-posta yönlendirmesi
    sms += "\nDetay icin e-postanizi kontrol edin."

    return sms


def build_daily_reminder_sms(
    patient_name: str,
    today_calories: float,
    target_calories: float,
    meal_count: int,
) -> str:
    """
    Günlük özet hatırlatma SMS'i (opsiyonel).

    Args:
        patient_name: Hasta adı
        today_calories: Bugünkü toplam kalori
        target_calories: Günlük hedef
        meal_count: Öğün sayısı

    Returns:
        SMS metni
    """
    remaining = target_calories - today_calories
    pct = (today_calories / max(target_calories, 1)) * 100

    if remaining > 0:
        status = f"{remaining:.0f} kcal kaldi"
    else:
        status = f"Hedef %{pct:.0f} asildi"

    return (
        f"NutriSense: {patient_name}\n"
        f"Bugun: {today_calories:.0f}/{target_calories:.0f} kcal\n"
        f"{meal_count} ogun | {status}"
    )


def build_alert_sms(
    patient_name: str,
    alert_message: str,
) -> str:
    """
    Acil uyarı SMS'i (hedef çok aşıldığında).

    Args:
        patient_name: Hasta adı
        alert_message: Uyarı mesajı

    Returns:
        SMS metni
    """
    return (
        f"⚠ NutriSense Uyari\n"
        f"Hasta: {patient_name}\n"
        f"{alert_message}\n"
        f"Detay icin e-posta/uygulamaya bakin."
    )
