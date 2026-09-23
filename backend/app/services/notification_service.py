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
from ..domain.report_messages import build_report_sms, build_sms_parts

logger = logging.getLogger(__name__)


class ChannelDeliveryError(RuntimeError):
    def __init__(self, code: str, *, retryable: bool):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


EmailTransport = Callable[[MIMEMultipart, str], Awaitable[dict]]
SmsTransport = Callable[[str, str], dict | Awaitable[dict]]


def email_transport_ready(settings: Settings) -> bool:
    """Return whether the configured SMTP transport can accept a message.

    Local development sinks intentionally work without credentials. External
    SMTP servers require authentication and encrypted transport in every mode,
    including sandbox, so readiness cannot report a half-configured Gmail
    account as usable.
    """
    host = settings.smtp_host.strip().lower()
    if not host or not settings.smtp_from_email.strip():
        return False
    local_sink = (
        settings.app_environment.lower() in {"local", "dev", "test"}
        and host in {"mailpit", "localhost", "127.0.0.1"}
    )
    if local_sink:
        return True
    return bool(
        settings.smtp_user.strip()
        and settings.smtp_password
        and (settings.smtp_use_tls or settings.smtp_start_tls)
    )


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
        if not email_transport_ready(self.settings):
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
    """Rapor bildirimi; hiçbir şema sürümünde sağlık verisi e-postaya yazılmaz.

    Eski biçimde kaydedilmiş raporlar yeniden denendiğinde de yalnız bildirim
    gider; ayrıntılar diyetisyen panelinde kalır.
    """
    patient_code = report.get("patient_code") or "Belirtilmedi"
    report_reference = report.get("report_reference") or "paneldeki en yeni rapor"
    html = f"""<!doctype html><html lang="tr"><body><main>
<h1>NutriSense — Yeni beslenme raporu</h1>
<p><strong>Danışan kodu:</strong> {escape(patient_code)}</p>
<p><strong>Rapor referansı:</strong> {escape(str(report_reference))}</p>
<p>Besin adı, miktar, tarih-saat ve kalori bilgilerini güvenli diyetisyen paneline giriş yapıp Raporlar bölümünden görüntüleyin.</p>
<p>Bu e-posta sağlık verisi içermez ve tıbbi tavsiye değildir.</p>
</main></body></html>"""
    plain = (
        "NutriSense — Yeni beslenme raporu\n"
        f"Danışan kodu: {patient_code}\n"
        f"Rapor referansı: {report_reference}\n"
        "Besin adı, miktar, tarih-saat ve kalori bilgilerini güvenli "
        "diyetisyen paneline giriş yapıp Raporlar bölümünden "
        "görüntüleyin.\nBu e-posta sağlık verisi içermez ve "
        "tıbbi tavsiye değildir."
    )
    message = MIMEMultipart("alternative")
    message["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    message["Subject"] = "NutriSense — Yeni beslenme raporu"
    message["Message-ID"] = make_msgid(domain="nutrisense.invalid")
    message.attach(MIMEText(plain, "plain", "utf-8"))
    message.attach(MIMEText(html, "html", "utf-8"))
    return message


def build_safe_sms(report: dict) -> str:
    """Compatibility entry point; every schema version sends a notification only."""
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


def _transactional_message(subject: str, destination: str, settings: Settings) -> MIMEMultipart:
    message = MIMEMultipart("alternative")
    message["Subject"] = subject
    message["From"] = f"{settings.smtp_from_name} <{settings.smtp_from_email}>"
    message["To"] = destination
    message["Message-ID"] = make_msgid()
    return message


def build_registration_code_email(
    *,
    code: str,
    destination: str,
    settings: Settings,
) -> MIMEMultipart:
    """Kayıt doğrulama kodunu taşıyan e-posta; sade düz metin, ekran okuyucu dostu."""
    message = _transactional_message("NutriSense kayıt doğrulama kodu", destination, settings)
    body = (
        "NutriSense hesabınızı oluşturmak için e-posta adresinizi doğrulayın.\n\n"
        f"Doğrulama kodunuz: {code}\n\n"
        "Bu kod 30 dakika boyunca geçerlidir.\n"
        "Bu kaydı siz başlatmadıysanız bu iletiyi yok sayabilirsiniz; "
        "hesap açılmaz.\n"
    )
    message.attach(MIMEText(body, "plain", "utf-8"))
    return message


def build_registration_exists_email(*, destination: str, settings: Settings) -> MIMEMultipart:
    """Kayıtlı bir adresle yeniden kayıt denendiğinde gönderilen bilgi e-postası.

    Kayıt ekranı hesabın varlığını söylemez; bilgi yalnız adresin sahibine gider.
    """
    message = _transactional_message("NutriSense hesabınız zaten var", destination, settings)
    body = (
        "Bu e-posta adresiyle NutriSense'te yeni hesap oluşturma isteği aldık.\n\n"
        "Bu adresle zaten bir hesabınız var. Giriş yapabilir ya da "
        "\"Parolamı unuttum\" ile parolanızı sıfırlayabilirsiniz.\n\n"
        "Bu isteği siz yapmadıysanız bu iletiyi yok sayabilirsiniz; "
        "hesabınızda değişiklik yapılmadı.\n"
    )
    message.attach(MIMEText(body, "plain", "utf-8"))
    return message


def build_email_change_code_email(
    *, code: str, destination: str, settings: Settings,
) -> MIMEMultipart:
    """Send the ownership code only to the requested new address."""
    message = _transactional_message(
        "NutriSense e-posta değişikliği doğrulama kodu", destination, settings,
    )
    body = (
        "NutriSense hesabınızın e-posta adresini değiştirme isteği aldık.\n\n"
        f"Doğrulama kodunuz: {code}\n\n"
        "Bu kod 30 dakika boyunca ve yalnız bu hesap için geçerlidir.\n"
        "Bu isteği siz yapmadıysanız iletiyi yok sayabilirsiniz; hesabın "
        "e-posta adresi değişmez.\n"
    )
    message.attach(MIMEText(body, "plain", "utf-8"))
    return message


def build_email_change_unavailable_email(
    *, destination: str, settings: Settings,
) -> MIMEMultipart:
    """Notify the address owner without revealing account existence in-app."""
    message = _transactional_message(
        "NutriSense e-posta değişikliği isteği", destination, settings,
    )
    body = (
        "Bu adresi bir NutriSense hesabına bağlama isteği aldık.\n\n"
        "Adres zaten kullanımda olduğu için hiçbir hesap değiştirilmedi. "
        "Bu isteği siz yapmadıysanız başka bir işlem yapmanız gerekmez.\n"
    )
    message.attach(MIMEText(body, "plain", "utf-8"))
    return message
