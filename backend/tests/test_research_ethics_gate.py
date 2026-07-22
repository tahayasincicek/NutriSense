"""Ethics gate tests use synthetic fixtures only; no participant data."""

from uuid import uuid4

from app.models.database import (
    AuditEvent,
    ResearchConsent,
    SurveySubmission,
    UsabilitySession,
)
from app.models.database import SessionLocal
from app.routers import survey_router


def _approved_test_configuration(monkeypatch):
    monkeypatch.setattr(survey_router.settings, "research_mode", "approved")
    monkeypatch.setattr(
        survey_router.settings, "research_protocol_version", "SYNTHETIC-TEST-PROTOCOL-V1"
    )
    monkeypatch.setattr(
        survey_router.settings, "research_consent_version", "SYNTHETIC-TEST-CONSENT-V1"
    )
    monkeypatch.setattr(
        survey_router.settings,
        "research_approval_reference",
        "SYNTHETIC-TEST-APPROVAL-REFERENCE",
    )


def test_real_collection_is_blocked_without_external_approval(client, monkeypatch):
    monkeypatch.setattr(survey_router.settings, "research_mode", "synthetic")
    response = client.post(
        "/api/v1/research/consents",
        json={
            "data_origin": "participant",
            "protocol_version": "not-approved",
            "consent_version": "not-approved",
            "consent_method": "signed",
        },
    )
    assert response.status_code == 451
    db = SessionLocal()
    try:
        assert db.query(ResearchConsent).count() == 0
    finally:
        db.close()


def test_consent_idempotency_tidy_export_and_withdrawal(client, monkeypatch):
    _approved_test_configuration(monkeypatch)
    monkeypatch.setattr(survey_router.settings, "research_export_token", "synthetic-test-export")

    consent_response = client.post(
        "/api/v1/research/consents",
        json={
            "data_origin": "participant",
            "protocol_version": "SYNTHETIC-TEST-PROTOCOL-V1",
            "consent_version": "SYNTHETIC-TEST-CONSENT-V1",
            "consent_method": "witnessed_verbal",
            "witness_reference": "synthetic-witness-fixture",
        },
    )
    assert consent_response.status_code == 200
    consent = consent_response.json()
    participant_id = consent["participant_id"]
    withdrawal_code = consent["withdrawal_code"]

    survey_payload = {
        "participant_id": participant_id,
        "protocol_version": "SYNTHETIC-TEST-PROTOCOL-V1",
        "data_origin": "participant",
        "survey_version": "1.0",
        "answers": [{"question_id": "q2", "answer": 4}],
        "completion_seconds": 12,
    }
    headers = {"Idempotency-Key": "synthetic-survey-request-1"}
    first = client.post("/api/v1/survey", json=survey_payload, headers=headers)
    duplicate = client.post("/api/v1/survey", json=survey_payload, headers=headers)
    assert first.status_code == 200
    assert duplicate.status_code == 200
    assert duplicate.json()["duplicate"] is True

    usability_payload = {
        "participant_id": participant_id,
        "protocol_version": "SYNTHETIC-TEST-PROTOCOL-V1",
        "data_origin": "participant",
        "schema_version": "1.0",
        "counterbalance_sequence": "AB",
        "tasks": [{
            "id": "t1",
            "condition": "nutrisense",
            "title": "Synthetic fixture task",
            "description": "No human participant",
            "status": "completed",
            "duration_seconds": 3.25,
            "is_success": True,
            "error_count": 1,
            "assistance_level": "prompt",
            "timing_source": "monotonic",
        }],
    }
    usability = client.post(
        "/api/v1/usability",
        json=usability_payload,
        headers={"Idempotency-Key": "synthetic-usability-request-1"},
    )
    assert usability.status_code == 200

    export_headers = {"X-Research-Export-Token": "synthetic-test-export"}
    survey_tidy = client.get("/api/v1/survey/export/tidy", headers=export_headers)
    usability_tidy = client.get("/api/v1/usability/export/tidy", headers=export_headers)
    assert survey_tidy.status_code == 200
    assert survey_tidy.json()["rows"][0]["question_id"] == "q2"
    assert usability_tidy.status_code == 200
    assert usability_tidy.json()["rows"][0]["assistance_level"] == "prompt"
    assert usability_tidy.json()["rows"][0]["counterbalance_sequence"] == "AB"
    assert usability_tidy.json()["rows"][0]["condition"] == "nutrisense"

    withdrawal = client.post(
        "/api/v1/research/withdraw",
        json={"participant_id": participant_id, "withdrawal_code": withdrawal_code},
    )
    assert withdrawal.status_code == 200
    assert withdrawal.json()["deleted_survey_submissions"] == 1
    assert withdrawal.json()["deleted_usability_sessions"] == 1

    db = SessionLocal()
    try:
        assert db.query(SurveySubmission).count() == 0
        assert db.query(UsabilitySession).count() == 0
        stored_consent = db.query(ResearchConsent).one()
        assert stored_consent.withdrawn_at is not None
        assert stored_consent.evidence_reference is None
        assert db.query(AuditEvent).filter(
            AuditEvent.event == "research_participation_withdrawn"
        ).count() == 1
    finally:
        db.close()


def test_audio_consent_requires_separate_approval(client, monkeypatch):
    _approved_test_configuration(monkeypatch)
    monkeypatch.setattr(survey_router.settings, "research_audio_consent_approved", False)
    response = client.post(
        "/api/v1/research/consents",
        json={
            "data_origin": "participant",
            "protocol_version": "SYNTHETIC-TEST-PROTOCOL-V1",
            "consent_version": "SYNTHETIC-TEST-CONSENT-V1",
            "consent_method": "recorded_verbal",
            "evidence_reference": str(uuid4()),
        },
    )
    assert response.status_code == 451
