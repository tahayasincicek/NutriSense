"""Deterministic SMS content; no providers, credentials or database access."""

from decimal import Decimal


REPORT_SCHEMA_VERSION = "dietitian-report-v3"
# Below Twilio's 1600-character limit, including supplementary Unicode units.
SMS_BODY_LIMIT = 600


def report_number(value) -> str:
    number = Decimal(str(value))
    if not number.is_finite() or number < 0:
        raise ValueError("Invalid report quantity")
    return format(number.normalize(), "f")


def build_report_sms(report: dict) -> str:
    # A stored v2 report was authorized for summary-only SMS. Never expand it on retry.
    if report.get("schema_version") == "dietitian-report-v2":
        return (
            f"NutriSense: {report['from_date']} - {report['to_date']} dönemine ait "
            f"{report['record_count']} onaylı kayıt için paylaşım özeti hazırlandı. "
            "Ayrıntılı beslenme günlüğü SMS içinde paylaşılmadı. "
            "Bu bilgi tıbbi tavsiye değildir."
        )
    records = report["records"]
    if not records or len(records) != report["record_count"]:
        raise ValueError("Report records are incomplete")
    lines = [
        f"NutriSense: {report['from_date']} - {report['to_date']}",
        f"{len(records)} onaylı besin kaydı:",
    ]
    for index, record in enumerate(records, 1):
        name = " ".join(record["food_name_tr"].split())
        if not name or not record["logged_at"]:
            raise ValueError("Report food name/time missing")
        estimate = " (tahmini)" if record["portion_is_estimate"] else ""
        lines.append(
            f"{index}. {name}; {report_number(record['portion_grams'])} g{estimate}; "
            f"{report_number(record['total_calories'])} kcal; {record['logged_at']}"
        )
    lines.append("Bu bilgi tıbbi tavsiye değildir.")
    return "\n".join(lines)


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
