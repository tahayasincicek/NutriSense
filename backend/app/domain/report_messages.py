"""Deterministic SMS content; no providers, credentials or database access."""

from decimal import Decimal


REPORT_SCHEMA_VERSION = "dietitian-report-v4"
# Below Twilio's 1600-character limit, including supplementary Unicode units.
SMS_BODY_LIMIT = 600


def report_number(value) -> str:
    number = Decimal(str(value))
    if not number.is_finite() or number < 0:
        raise ValueError("Invalid report quantity")
    return format(number.normalize(), "f")


def build_report_sms(report: dict) -> str:
    """Rapor bildirimi; hiçbir şema sürümünde sağlık verisi SMS'e yazılmaz.

    Eski biçimde (v2/v3) kaydedilmiş bir rapor yeniden denendiğinde de yalnız
    bildirim gider. Besin, gram, saat ve kalori diyetisyen panelinde kalır.
    """
    patient = report.get("patient_code") or "Danışan"
    return (
        f"NutriSense: {patient} için yeni bir beslenme raporu hazır. "
        "Sağlık verilerini güvenli diyetisyen panelinden görüntüleyin. "
        "Bu bilgi tıbbi tavsiye değildir."
    )


def build_sms_parts(report: dict) -> list[str]:
    """Keep every character and bound each numbered body in UTF-16 units."""
    text = build_report_sms(report)
    if len(text.encode("utf-16-le")) // 2 <= SMS_BODY_LIMIT:
        return [text]
    # Reserve ample space for the NutriSense and part-number header.
    capacity = SMS_BODY_LIMIT - 64
    chunks = []
    current = ""
    units = 0
    for char in text:
        width = len(char.encode("utf-16-le")) // 2
        if units + width > capacity:
            # Prefer complete lines, without dropping a delimiter or a record.
            boundary = current.rfind("\n") + 1
            if boundary:
                chunks.append(current[:boundary])
                current = current[boundary:]
                units = len(current.encode("utf-16-le")) // 2
            else:
                chunks.append(current)
                current, units = "", 0
        current += char
        units += width
    if current:
        chunks.append(current)
    return [f"NutriSense ({index}/{len(chunks)})\n{chunk}" for index, chunk in enumerate(chunks, 1)]
