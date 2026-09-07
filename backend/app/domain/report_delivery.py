"""Pure privacy and consent rules for dietitian report delivery."""

from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from datetime import date, timedelta
from typing import Iterable

from .report_messages import REPORT_SCHEMA_VERSION, build_sms_parts


class ReportDeliveryError(ValueError):
    """A user-correctable report preview or delivery error."""


def mask_email(value: str) -> str:
    local, separator, domain = value.partition("@")
    if not separator or not local or not domain:
        return "***"
    visible = local[0]
    return f"{visible}{'*' * max(len(local) - 1, 3)}@{domain}"


def mask_phone(value: str) -> str:
    digits = "".join(character for character in value if character.isdigit())
    if len(digits) < 4:
        return "***"
    return f"+{'*' * max(len(digits) - 4, 6)}{digits[-4:]}"


def resolve_report_dates(
    report_type: str,
    from_date: date | None,
    to_date: date | None,
    *,
    today: date,
) -> tuple[date, date]:
    end = to_date or today
    default_days = {"daily": 1, "weekly": 7, "monthly": 30}[report_type]
    start = from_date or (end - timedelta(days=default_days - 1))
    if start > end:
        raise ReportDeliveryError("Başlangıç tarihi bitiş tarihinden sonra olamaz.")
    if (end - start).days > 30:
        raise ReportDeliveryError("Rapor tarih aralığı en fazla 31 gün olabilir.")
    if end > today:
        raise ReportDeliveryError("Gelecekteki kayıtlar rapora eklenemez.")
    return start, end


def verified_recipients(dietitian, channels: Iterable[str]) -> dict[str, str]:
    selected = list(channels)
    recipients: dict[str, str] = {}
    if "email" in selected:
        if not dietitian.email_verified or not dietitian.email:
            raise ReportDeliveryError("Diyetisyen e-posta adresi doğrulanmamış.")
        recipients["email"] = mask_email(dietitian.email)
    if "sms" in selected:
        if not dietitian.phone_verified or not dietitian.phone:
            raise ReportDeliveryError("Diyetisyen telefon numarası doğrulanmamış.")
        recipients["sms"] = mask_phone(dietitian.phone)
    if not recipients:
        raise ReportDeliveryError("En az bir doğrulanmış kanal seçilmelidir.")
    return recipients


def build_report_payload(
    *,
    user,
    dietitian,
    assignment,
    report_type: str,
    from_date: date,
    to_date: date,
    channels: list[str],
    logs: list,
    message: str | None = None,
) -> dict:
    if not logs:
        raise ReportDeliveryError("Seçilen dönemde gönderilecek onaylı kayıt yok.")
    recipients = verified_recipients(dietitian, channels)
    total_days = (to_date - from_date).days + 1
    total_calories = sum(float(log.total_calories) for log in logs)
    daily: dict[date, list] = defaultdict(list)
    records = []
    estimated_count = 0
    source_labels: set[str] = set()
    for log in logs:
        daily[log.log_date].append(log)
        if log.portion_is_estimate:
            estimated_count += 1
        source_labels.add(log.recognition_source)
        records.append({
            "log_id": str(log.id),
            "food_name_tr": log.food_name_tr,
            "portion_grams": float(log.estimated_portion_g),
            "portion_is_estimate": bool(log.portion_is_estimate),
            "total_calories": float(log.total_calories),
            "protein": float(log.protein),
            "carbs": float(log.carbs),
            "fat": float(log.fat),
            "meal_type": log.meal_type,
            "logged_at": log.logged_at.isoformat(),
            "recognition_source": log.recognition_source,
            "is_corrected": bool(log.is_corrected),
            "updated_at": log.updated_at.isoformat(),
        })
    daily_breakdown = []
    for day in sorted(daily):
        day_logs = daily[day]
        daily_breakdown.append({
            "date": day.isoformat(),
            "calories": sum(float(item.total_calories) for item in day_logs),
            "protein": sum(float(item.protein) for item in day_logs),
            "carbs": sum(float(item.carbs) for item in day_logs),
            "fat": sum(float(item.fat) for item in day_logs),
            "record_count": len(day_logs),
        })
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "user_id": str(user.id),
        "patient_name": user.full_name,
        "dietitian_id": str(dietitian.id),
        "dietitian_name": dietitian.full_name,
        "assignment_id": str(assignment.id),
        "report_type": report_type,
        "from_date": from_date.isoformat(),
        "to_date": to_date.isoformat(),
        "total_days": total_days,
        "record_count": len(logs),
        "total_calories": total_calories,
        "average_daily_calories": total_calories / total_days,
        "estimated_portion_count": estimated_count,
        "channels": sorted(channels),
        "recipients": recipients,
        "source_explanations": sorted(source_labels),
        "records": records,
        "daily_breakdown": daily_breakdown,
        "message": message,
        "disclaimer": (
            "Bu rapor tahmini beslenme bilgisi içerir; tıbbi tavsiye değildir."
        ),
    }


def consent_context_hash(payload: dict) -> str:
    consent_fields = {
        key: payload[key]
        for key in (
            "schema_version", "user_id", "dietitian_id", "assignment_id",
            "report_type", "from_date", "to_date", "record_count",
            "channels", "recipients", "records", "message",
        )
    }
    encoded = json.dumps(
        consent_fields, ensure_ascii=False, sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def accessibility_summary(payload: dict) -> str:
    channel_labels = [
        f"{'e-posta' if channel == 'email' else 'SMS'} {payload['recipients'][channel]}"
        for channel in payload["channels"]
    ]
    estimate_note = (
        f" {payload['estimated_portion_count']} kayıtta porsiyon tahminidir."
        if payload["estimated_portion_count"]
        else " Tüm porsiyonlar kullanıcı tarafından kesinleştirilmiştir."
    )
    sms_note = (
        f" SMS içinde besin adı, gram miktarı, tarih-saat ve kalori paylaşılacak. "
        f"{len(build_sms_parts(payload))} SMS mesajı hazırlanacak; "
        "operatör bunları ücretlendirilen ek parçalara bölebilir."
        if "sms" in payload["channels"] else ""
    )
    return (
        f"{payload['from_date']} ile {payload['to_date']} arasındaki "
        f"{payload['record_count']} onaylı kayıt, {payload['dietitian_name']} adlı "
        f"diyetisyene {', '.join(channel_labels)} kanallarıyla gönderilecek."
        f"{estimate_note}{sms_note} Bu rapor tıbbi tavsiye değildir."
    )
