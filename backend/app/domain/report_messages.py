"""Deterministic report content; no providers, credentials or database access."""

from datetime import datetime
from decimal import Decimal


REPORT_SCHEMA_VERSION = "dietitian-report-v5"
# Below Twilio's 1600-character limit, including supplementary Unicode units.
SMS_BODY_LIMIT = 600


def report_number(value) -> str:
    number = Decimal(str(value))
    if not number.is_finite() or number < 0:
        raise ValueError("Invalid report quantity")
    return format(number.normalize(), "f")


def report_record_lines(report: dict) -> list[str]:
    """Render the user-approved fields required by the project proposal."""
    # Legacy reports were approved under a notification-only disclosure. They
    # must be previewed and approved again before health details leave the app.
    if report.get("schema_version") != REPORT_SCHEMA_VERSION:
        return []
    lines = []
    for record in report.get("records") or []:
        logged_at = str(record.get("logged_at") or "Belirtilmedi")
        try:
            moment = datetime.fromisoformat(logged_at.replace("Z", "+00:00"))
            date_text = moment.strftime("%d.%m.%Y")
            time_text = moment.strftime("%H:%M")
        except ValueError:
            date_text, time_text = logged_at, "Belirtilmedi"
        lines.append(
            f"{record.get('food_name_tr') or 'Belirtilmedi'} | "
            f"{report_number(record.get('portion_grams', 0))} g | "
            f"{date_text} | {time_text} | "
            f"{report_number(record.get('total_calories', 0))} kcal"
        )
    return lines


def build_report_sms(report: dict) -> str:
    """Send approved food, amount, date, time and calorie data by SMS."""
    if report.get("schema_version") != REPORT_SCHEMA_VERSION:
        return "NutriSense: Yeni rapor hazır. Uygulamayı açın."
    lines = report_record_lines(report)
    header = "NutriSense beslenme raporu"
    if not lines:
        return f"{header}\nGönderilecek onaylı besin kaydı bulunamadı."
    return "\n".join([header, *lines])


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
