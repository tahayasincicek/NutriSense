"""Privacy-preserving SMTP/Twilio channel adapters.

Provider acceptance is persisted as ``sent``; it is not presented as proof of
human delivery. Provider secrets and unmasked destinations are never logged.
"""

from __future__ import annotations

import inspect
import hashlib
from copy import deepcopy
import json
import logging
import uuid
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import make_msgid
from html import escape
from typing import Awaitable, Callable

import aiosmtplib
from twilio.rest import Client as TwilioClient

from ..config import Settings, get_settings
from ..models.database import utc_now
from ..operations.metrics import runtime_metrics
from ..domain.report_messages import build_report_sms, build_sms_parts, report_number

logger = logging.getLogger(__name__)


class ChannelDeliveryError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


EmailTransport = Callable[[MIMEMultipart, str], Awaitable[dict]]
SmsTransport = Callable[[str, str], dict | Awaitable[dict]]


class NotificationService:
    def __init__(
        self,
        *,
        settings_override: Settings | None = None,
        email_transport: EmailTransport | None = None,
        sms_transport: SmsTransport | None = None,
    ) -> None:
        self.settings = settings_override or get_settings()
        self._email_transport = email_transport or self._smtp_send
        self._sms_transport = sms_transport or self._select_sms_transport()

    async def send_channel(
        self,
        *,
        channel: str,
        destination: str,
        report_data: dict,
        sms_progress: dict | None = None,
        sms_checkpoint: Callable[[dict], None] | None = None,
    ) -> dict:
        self._assert_mode_and_allowlist(channel, destination)
        try:
            if channel == "email":
                message = build_report_email(report_data, self.settings)
                message["To"] = destination
                result = await self._email_transport(message, destination)
            elif channel == "sms":
                result = await self._send_sms_parts(
                    destination, report_data, sms_progress, sms_checkpoint,
                )
            else:
                raise ChannelDeliveryError("UNSUPPORTED_CHANNEL", retryable=False)
        except ChannelDeliveryError:
            runtime_metrics.provider_outcome(
                "smtp" if channel == "email" else "twilio",
                "rejected",
            )
            raise
        except (TimeoutError, ConnectionError):
            runtime_metrics.provider_outcome(
                "smtp" if channel == "email" else "twilio",
                "temporary_failure",
            )
            raise ChannelDeliveryError("PROVIDER_TEMPORARY_FAILURE", retryable=True)
        except Exception:
            runtime_metrics.provider_outcome(
                "smtp" if channel == "email" else "twilio",
                "rejected",
            )
            logger.error("Bildirim sağlayıcısı başarısız oldu; mesaj ve alıcı loglanmadı.")
            raise ChannelDeliveryError("PROVIDER_REJECTED", retryable=False)
        runtime_metrics.provider_outcome(
            "smtp" if channel == "email" else "twilio",
            "success",
        )
        return {
            "provider_message_id": str(result.get("provider_message_id", "")) or None,
            "provider_status": str(result.get("provider_status", "accepted")),
        }

    async def _send_sms_parts(self, destination, report, progress, checkpoint):
        bodies = build_sms_parts(report)
        digest = hashlib.sha256(json.dumps(bodies, ensure_ascii=False).encode("utf-8")).hexdigest()
        state = deepcopy(progress) if progress else {
            "body_hash": digest,
            "parts": [{"status": "queued"} for _ in bodies],
        }
        if state.get("body_hash") != digest or len(state.get("parts", [])) != len(bodies):
            raise ChannelDeliveryError("SMS_CONTENT_CHANGED", retryable=False)
        if len(bodies) > 1 and checkpoint is None:
            raise ChannelDeliveryError("SMS_CHECKPOINT_REQUIRED", retryable=False)
        for body, part in zip(bodies, state["parts"]):
            if part["status"] == "sent":
                continue
            if part["status"] == "sending":
                # A crash/timeout can happen after acceptance. Do not duplicate blindly.
                raise ChannelDeliveryError("SMS_DELIVERY_UNCERTAIN", retryable=False)
            part["status"] = "sending"
            if checkpoint:
                checkpoint(deepcopy(state))
            try:
                result = self._sms_transport(body, destination)
                if inspect.isawaitable(result):
                    result = await result
                if not result or not result.get("provider_message_id"):
                    raise ValueError("Provider acknowledgement missing")
            except ChannelDeliveryError:
                part["status"] = "failed"
                if checkpoint:
                    checkpoint(deepcopy(state))
                raise
            except Exception:
                # State stays 'sending' until a provider reconciliation resolves it.
                raise ChannelDeliveryError("SMS_DELIVERY_UNCERTAIN", retryable=False) from None
            part.update({
                "status": "sent",
                "provider_message_id": result.get("provider_message_id"),
                "provider_status": result.get("provider_status", "accepted"),
            })
            if checkpoint:
                checkpoint(deepcopy(state))
        last = state["parts"][-1]
        return {
            "provider_message_id": last["provider_message_id"],
            "provider_status": last["provider_status"] if len(bodies) == 1 else f"accepted_parts:{len(bodies)}/{len(bodies)}",
        }

    async def send_email_message(
        self,
        message: MIMEMultipart,
        destination: str,
    ) -> dict:
        """Hazır bir e-posta iletisini gönderir (rapor biçimi dışı).

        Parola sıfırlama gibi işlem e-postaları için kullanılır; rapor
        şablonundan geçmez ama aynı mod/allowlist kısıtlarına tabidir.
        """
        self._assert_mode_and_allowlist("email", destination)
        try:
            return await self._email_transport(message, destination)
        except ChannelDeliveryError:
            raise
        except (TimeoutError, ConnectionError):
            raise ChannelDeliveryError(
                "PROVIDER_TEMPORARY_FAILURE", retryable=True
            )
        except Exception:
            logger.exception("İşlem e-postası gönderilemedi.")
            raise ChannelDeliveryError("PROVIDER_REJECTED", retryable=False)

    def _assert_mode_and_allowlist(self, channel: str, destination: str) -> None:
        mode = self.settings.notification_mode.lower()
        if mode not in {"sandbox", "production"}:
            raise ChannelDeliveryError("CHANNEL_DISABLED", retryable=False)
        if mode == "sandbox":
            environment = self.settings.app_environment.lower()
            local_email_sink = (
                channel == "email"
                and environment in {"local", "dev", "test"}
                and self.settings.smtp_host.lower() in {"mailpit", "localhost", "127.0.0.1"}
            )
            local_sms_sink = (
                channel == "sms"
                and environment in {"local", "dev", "test"}
                and self.settings.sms_provider_mode == "local_outbox"
            )
            # Local sinks cannot contact the displayed recipient. The address is
            # retained in the captured message so the end-to-end report can be
            # inspected without weakening allowlists for an external provider.
            if local_email_sink or local_sms_sink:
                return
            allowed = (
                self.settings.sandbox_email_allowlist
                if channel == "email"
                else self.settings.sandbox_phone_allowlist
            )
            candidate = destination.lower() if channel == "email" else destination
            if candidate not in allowed:
                raise ChannelDeliveryError("RECIPIENT_NOT_ALLOWLISTED", retryable=False)

    async def _smtp_send(self, message: MIMEMultipart, destination: str) -> dict:
        if not self.settings.smtp_host or not self.settings.smtp_from_email:
            raise ChannelDeliveryError("EMAIL_NOT_CONFIGURED", retryable=False)
        kwargs = {
            "hostname": self.settings.smtp_host,
            "port": self.settings.smtp_port,
            "use_tls": self.settings.smtp_use_tls,
            "start_tls": self.settings.smtp_start_tls,
        }
        if self.settings.smtp_user:
            kwargs["username"] = self.settings.smtp_user
        if self.settings.smtp_password:
            kwargs["password"] = self.settings.smtp_password
        await aiosmtplib.send(message, **kwargs)
        return {
            "provider_message_id": message["Message-ID"],
            "provider_status": "accepted",
        }

    def _select_sms_transport(self) -> SmsTransport:
        """Yapılandırmaya göre SMS taşıyıcısını seçer."""
        if self.settings.sms_provider_mode == "local_outbox":
            return self._local_outbox_send
        return self._twilio_send

    def _local_outbox_send(self, body: str, destination: str) -> dict:
        """Mesajı yerel kutuya yazar; operatöre çıkmaz.

        E-posta tarafındaki Mailpit'in karşılığıdır: hattın tamamı
        (rıza, rapor, kanal seçimi, teslimat kaydı) gerçekten çalışır, yalnız
        son adımda mesaj gerçek telefona gitmez. Geliştirme ve kanıt üretmek
        içindir; staging/production'da yapılandırma reddedilir.
        """
        path = Path(self.settings.sms_outbox_path)
        message_id = f"local-{uuid.uuid4()}"
        record = {
            "message_id": message_id,
            "to": destination,
            "body": body,
            "queued_at": utc_now().isoformat(),
        }
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(record, ensure_ascii=False) + chr(10))
        except OSError as exc:
            # Container'da /app salt okunurdur; yol yazılabilir bir dizine
            # ayarlanmalıdır. Genel sağlayıcı hatası gibi görünmesin.
            logger.error(
                "SMS yerel kutusuna yazılamadı path=%s hata=%s",
                path,
                type(exc).__name__,
            )
            raise ChannelDeliveryError(
                "SMS_OUTBOX_NOT_WRITABLE", retryable=False
            ) from None
        logger.info(
            "SMS yerel kutuya yazıldı message_id=%s uzunluk=%s",
            message_id,
            len(body),
        )
        return {
            "provider_message_id": message_id,
            "provider_status": "queued_local_outbox",
        }

    def _twilio_send(self, body: str, destination: str) -> dict:
        if not (
            self.settings.twilio_account_sid
            and self.settings.twilio_auth_token
            and self.settings.twilio_phone_number
        ):
            raise ChannelDeliveryError("SMS_NOT_CONFIGURED", retryable=False)
        client = TwilioClient(
            self.settings.twilio_account_sid,
            self.settings.twilio_auth_token,
        )
        message = client.messages.create(
            body=body,
            from_=self.settings.twilio_phone_number,
            to=destination,
        )
        return {
            "provider_message_id": message.sid,
            "provider_status": getattr(message, "status", "accepted"),
        }


def build_report_email(report: dict, settings: Settings) -> MIMEMultipart:
    report_label = {
        "daily": "Günlük", "weekly": "Haftalık", "monthly": "Aylık",
    }.get(report["report_type"], "Beslenme")
    rows = "".join(
        "<tr>"
        f"<td>{escape(record['food_name_tr'])}</td>"
        f"<td>{report_number(record['portion_grams'])} g"
        f"{' (tahmini)' if record['portion_is_estimate'] else ''}</td>"
        f"<td>{report_number(record['total_calories'])} kcal</td>"
        f"<td>{escape(record['logged_at'])}</td>"
        f"<td>{escape(record['recognition_source'])}</td>"
        "</tr>"
        for record in report["records"]
    )
    source_text = ", ".join(report["source_explanations"]) or "belirtilmemiş"
    note = (
        f"<p><strong>Kullanıcı notu:</strong> {escape(report['message'])}</p>"
        if report.get("message") else ""
    )
    html = f"""<!doctype html><html lang="tr"><body>
<main><h1>NutriSense {report_label} Beslenme Raporu</h1>
<p><strong>Dönem:</strong> {report['from_date']} – {report['to_date']}</p>
<p><strong>Onaylı kayıt:</strong> {report['record_count']} | <strong>Toplam:</strong>
{report['total_calories']:.0f} kcal | <strong>Günlük ortalama:</strong>
{report['average_daily_calories']:.0f} kcal</p>
<p><strong>Veri kaynakları:</strong> {escape(source_text)}. Görüntü tanıma güveni ile
beslenme verisinin güvenilirliği aynı ölçü değildir.</p>
<table><caption>Kullanıcı tarafından onaylanan besin kayıtları</caption>
<thead><tr><th>Besin</th><th>Porsiyon</th><th>Kalori</th><th>Zaman</th><th>Tanıma kaynağı</th></tr></thead>
<tbody>{rows}</tbody></table>{note}
<p><strong>Uyarı:</strong> {escape(report['disclaimer'])}
{report['estimated_portion_count']} kayıtta porsiyon tahminidir.</p>
</main></body></html>"""
    plain_records = "\n".join(
        f"- {item['food_name_tr']}; {report_number(item['portion_grams'])} g"
        f"{' (tahmini)' if item['portion_is_estimate'] else ''}; "
        f"{report_number(item['total_calories'])} kcal; {item['logged_at']}; "
        f"kaynak {item['recognition_source']}"
        for item in report["records"]
    )
    plain = (
        f"NutriSense {report_label} Beslenme Raporu\n"
        f"Dönem: {report['from_date']} - {report['to_date']}\n"
        f"Onaylı kayıt: {report['record_count']}\n"
        f"Toplam: {report['total_calories']:.0f} kcal\n"
        f"Günlük ortalama: {report['average_daily_calories']:.0f} kcal\n"
        f"Kaynak açıklaması: {source_text}.\n\nKayıtlar:\n{plain_records}\n\n"
        f"{report['disclaimer']} {report['estimated_portion_count']} kayıtta "
        "porsiyon tahminidir."
    )
    message = MIMEMultipart("alternative")
    message["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    message["Subject"] = f"NutriSense — {report_label} Beslenme Raporu"
    message["Message-ID"] = make_msgid(domain="nutrisense.invalid")
    message.attach(MIMEText(plain, "plain", "utf-8"))
    message.attach(MIMEText(html, "html", "utf-8"))
    return message


def build_safe_sms(report: dict) -> str:
    """Compatibility entry point; v3 reports contain the explicitly approved details."""
    return build_report_sms(report)


def build_password_reset_email(
    *,
    reset_code: str,
    destination: str,
    settings: Settings,
) -> MIMEMultipart:
    """Parola sıfırlama kodunu taşıyan e-postayı hazırlar.

    Kod düz metin olarak gönderilir; ekran okuyucu kullanıcıların kodu
    rahatça dinleyebilmesi için rakamlar arasına boşluk konmaz ve
    biçimlendirme sade tutulur.
    """

    message = MIMEMultipart("alternative")
    message["Subject"] = "NutriSense parola sıfırlama kodu"
    message["From"] = (
        f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    )
    message["To"] = destination
    message["Message-ID"] = make_msgid()

    body = (
        "NutriSense parola sıfırlama talebi aldık.\n\n"
        f"Sıfırlama kodunuz: {reset_code}\n\n"
        "Bu kod 1 saat boyunca ve yalnız bir kez geçerlidir.\n"
        "Bu talebi siz yapmadıysanız bu iletiyi yok sayabilirsiniz; "
        "parolanız değişmez.\n"
    )
    message.attach(MIMEText(body, "plain", "utf-8"))
    return message
