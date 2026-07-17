# ==============================================================================
# backend/app/services/notification_service.py
# NutriSense — Bildirim Servisi (E-posta + SMS)
#
# Diyetisyene rapor gönderme:
#   - HTML e-posta şablonu (Jinja2)
#   - Twilio SMS
#   - Aiosmtplib async e-posta
# ==============================================================================

import logging
from typing import Optional

import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from jinja2 import Template
from twilio.rest import Client as TwilioClient

from ..config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


# ═══════════════════════════════════════════════════════════════════════════════
# HTML E-POSTA ŞABLONU
# ═══════════════════════════════════════════════════════════════════════════════

REPORT_EMAIL_TEMPLATE = Template("""
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #f5f5f5;
               margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: white;
                     border-radius: 12px; overflow: hidden;
                     box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #1B5E20, #2E7D32);
                  color: white; padding: 24px; text-align: center; }
        .header h1 { margin: 0; font-size: 24px; }
        .header p { margin: 8px 0 0; opacity: 0.9; }
        .content { padding: 24px; }
        .summary-card { background: #E8F5E9; border-radius: 8px;
                       padding: 16px; margin-bottom: 16px; }
        .summary-card h3 { margin: 0 0 8px; color: #1B5E20; }
        .stat { display: inline-block; width: 45%; margin: 8px 0; }
        .stat-value { font-size: 28px; font-weight: 700; color: #1B5E20; }
        .stat-label { font-size: 12px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin: 16px 0; }
        th { background: #1B5E20; color: white; padding: 10px; text-align: left;
             font-size: 13px; }
        td { padding: 10px; border-bottom: 1px solid #eee; font-size: 13px; }
        tr:nth-child(even) { background: #f9f9f9; }
        .footer { text-align: center; padding: 16px; color: #999;
                  font-size: 12px; border-top: 1px solid #eee; }
        .note { background: #FFF3E0; border-left: 4px solid #FF9800;
                padding: 12px; margin: 16px 0; border-radius: 4px; }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>🍽️ NutriSense Beslenme Raporu</h1>
        <p>{{ patient_name }} — {{ report_type_tr }} Rapor</p>
        <p>{{ from_date }} — {{ to_date }}</p>
    </div>
    <div class="content">
        <div class="summary-card">
            <h3>📊 Özet</h3>
            <div class="stat">
                <div class="stat-value">{{ total_calories|round|int }}</div>
                <div class="stat-label">Toplam Kalori (kcal)</div>
            </div>
            <div class="stat">
                <div class="stat-value">{{ avg_daily_calories|round|int }}</div>
                <div class="stat-label">Günlük Ortalama</div>
            </div>
            <div class="stat">
                <div class="stat-value">{{ total_meals }}</div>
                <div class="stat-label">Toplam Öğün</div>
            </div>
            <div class="stat">
                <div class="stat-value">{{ total_days }}</div>
                <div class="stat-label">Gün Sayısı</div>
            </div>
        </div>

        {% if daily_breakdown %}
        <h3>📅 Günlük Dağılım</h3>
        <table>
            <thead>
                <tr>
                    <th>Tarih</th>
                    <th>Kalori</th>
                    <th>Protein</th>
                    <th>Karb.</th>
                    <th>Yağ</th>
                    <th>Öğün</th>
                </tr>
            </thead>
            <tbody>
                {% for day in daily_breakdown %}
                <tr>
                    <td>{{ day.date }}</td>
                    <td>{{ day.calories|round|int }} kcal</td>
                    <td>{{ day.protein|round(1) }}g</td>
                    <td>{{ day.carbs|round(1) }}g</td>
                    <td>{{ day.fat|round(1) }}g</td>
                    <td>{{ day.meal_count }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% endif %}

        {% if patient_message %}
        <div class="note">
            <strong>💬 Hasta Notu:</strong><br>
            {{ patient_message }}
        </div>
        {% endif %}
    </div>
    <div class="footer">
        NutriSense — Görme Engelliler İçin Akıllı Besin Takibi<br>
        Bu rapor otomatik olarak oluşturulmuştur.
    </div>
</div>
</body>
</html>
""")


class NotificationService:
    """E-posta ve SMS bildirim servisi."""

    def __init__(self):
        # Twilio
        if settings.twilio_account_sid and settings.twilio_auth_token:
            self._twilio = TwilioClient(
                settings.twilio_account_sid,
                settings.twilio_auth_token,
            )
            self._sms_available = True
        else:
            self._twilio = None
            self._sms_available = False
            logger.warning("Twilio yapılandırılmamış — SMS devre dışı")

        # SMTP
        self._email_available = bool(
            settings.smtp_user and settings.smtp_password
        )
        if not self._email_available:
            logger.warning("SMTP yapılandırılmamış — e-posta devre dışı")

    async def send_dietitian_report(
        self,
        dietitian_email: Optional[str],
        dietitian_phone: Optional[str],
        dietitian_name: str,
        patient_name: str,
        report_data: dict,
    ) -> dict:
        """
        Diyetisyene beslenme raporu gönderir.

        Returns:
            {"email_sent": bool, "sms_sent": bool, "errors": [...]}
        """
        result = {"email_sent": False, "sms_sent": False, "errors": []}

        # ── E-posta ──
        if self._email_available and dietitian_email:
            try:
                await self._send_email_report(
                    to_email=dietitian_email,
                    dietitian_name=dietitian_name,
                    patient_name=patient_name,
                    report_data=report_data,
                )
                result["email_sent"] = True
                logger.info(f"Rapor e-postası gönderildi: {dietitian_email}")
            except Exception as e:
                error_msg = f"E-posta gönderilemedi: {str(e)}"
                result["errors"].append(error_msg)
                logger.error(error_msg)

        # ── SMS ──
        if self._sms_available and dietitian_phone:
            try:
                self._send_sms(
                    to_phone=dietitian_phone,
                    patient_name=patient_name,
                    report_data=report_data,
                )
                result["sms_sent"] = True
                logger.info(f"Rapor SMS'i gönderildi: {dietitian_phone}")
            except Exception as e:
                error_msg = f"SMS gönderilemedi: {str(e)}"
                result["errors"].append(error_msg)
                logger.error(error_msg)

        return result

    async def _send_email_report(
        self,
        to_email: str,
        dietitian_name: str,
        patient_name: str,
        report_data: dict,
    ):
        """HTML e-posta raporunu gönderir."""
        # Rapor türü Türkçe
        report_type_map = {
            "daily": "Günlük", "weekly": "Haftalık", "monthly": "Aylık"
        }

        html = REPORT_EMAIL_TEMPLATE.render(
            patient_name=patient_name,
            report_type_tr=report_type_map.get(
                report_data.get("report_type", "weekly"), "Haftalık"
            ),
            from_date=report_data.get("from_date", ""),
            to_date=report_data.get("to_date", ""),
            total_calories=report_data.get("total_calories", 0),
            avg_daily_calories=report_data.get("avg_daily_calories", 0),
            total_meals=report_data.get("total_meals", 0),
            total_days=report_data.get("total_days", 0),
            daily_breakdown=report_data.get("daily_breakdown", []),
            patient_message=report_data.get("message"),
        )

        msg = MIMEMultipart("alternative")
        msg["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
        msg["To"] = to_email
        msg["Subject"] = (
            f"NutriSense — {patient_name} Beslenme Raporu "
            f"({report_data.get('from_date', '')})"
        )
        msg.attach(MIMEText(html, "html", "utf-8"))

        await aiosmtplib.send(
            msg,
            hostname=settings.smtp_host,
            port=settings.smtp_port,
            username=settings.smtp_user,
            password=settings.smtp_password,
            use_tls=False,
            start_tls=True,
        )

    def _send_sms(
        self,
        to_phone: str,
        patient_name: str,
        report_data: dict,
    ):
        """Twilio ile SMS gönderir."""
        total_cal = report_data.get("total_calories", 0)
        days = report_data.get("total_days", 0)
        avg_cal = total_cal / max(days, 1)

        body = (
            f"NutriSense Rapor: {patient_name}\n"
            f"Dönem: {report_data.get('from_date')} - {report_data.get('to_date')}\n"
            f"Toplam: {total_cal:.0f} kcal ({days} gün)\n"
            f"Günlük ort: {avg_cal:.0f} kcal\n"
            f"Detay için e-postanızı kontrol edin."
        )

        self._twilio.messages.create(
            body=body,
            from_=settings.twilio_phone_number,
            to=to_phone,
        )
