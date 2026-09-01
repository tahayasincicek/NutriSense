"""Eşleşme iki taraflı onayla kurulur: hasta rızası + diyetisyen kabulü."""

from app.models.database import DietitianAssignment, SessionLocal, User

PASSWORD = "Guvenli123"


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _register_patient(client, email: str) -> dict:
    response = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": PASSWORD,
        "full_name": "Sentetik Hasta",
    })
    assert response.status_code == 201
    return response.json()


def _register_dietitian(client, email: str) -> dict:
    response = client.post("/api/v1/auth/register-dietitian", json={
        "email": email,
        "password": PASSWORD,
        "full_name": "Sentetik Diyetisyen",
        "specialization": "Beslenme ve Diyet",
    })
    assert response.status_code in {200, 201}
    return response.json()


def _request_link(client, patient_headers, dietitian_email: str) -> str:
    response = client.post(
        "/api/v1/dietitians/assignment",
        headers=patient_headers,
        json={"dietitian_email": dietitian_email},
    )
    assert response.status_code == 201, response.text
    assert response.json()["awaiting"] == "both"
    return response.json()["assignment_id"]


def _linked_dietitian_id(user_email: str) -> str | None:
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == user_email).first()
        return user.dietitian_id
    finally:
        db.close()


def test_patient_approval_alone_does_not_link(client):
    patient = _register_patient(client, "solo-approve@example.com")
    _register_dietitian(client, "solo-diyetisyen@example.com")
    headers = _auth(patient)
    assignment_id = _request_link(
        client, headers, "solo-diyetisyen@example.com"
    )

    response = client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve", headers=headers
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "pending"
    assert body["patient_approved"] is True
    assert body["dietitian_accepted"] is False
    assert body["awaiting"] == "dietitian"
    assert _linked_dietitian_id("solo-approve@example.com") is None


def test_dietitian_sees_and_accepts_pending_request(client):
    patient = _register_patient(client, "kabul-hasta@example.com")
    dietitian = _register_dietitian(client, "kabul-diyetisyen@example.com")
    patient_headers = _auth(patient)
    dietitian_headers = _auth(dietitian)
    assignment_id = _request_link(
        client, patient_headers, "kabul-diyetisyen@example.com"
    )
    client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=patient_headers,
    )

    listing = client.get(
        "/api/v1/dietitian/assignments/pending", headers=dietitian_headers
    )
    assert listing.status_code == 200, listing.text
    requests = listing.json()["requests"]
    assert len(requests) == 1
    assert requests[0]["assignment_id"] == assignment_id
    assert requests[0]["patient_approved"] is True
    # Hasta kimliği panelde maskeli görünür.
    assert "kabul-hasta@example.com" not in requests[0]["patient_email_masked"]

    accepted = client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=dietitian_headers,
    )
    assert accepted.status_code == 200, accepted.text
    assert accepted.json()["status"] == "approved"
    assert accepted.json()["awaiting"] is None
    assert _linked_dietitian_id("kabul-hasta@example.com") is not None

    # Kabul edilen istek listeden düşer.
    after = client.get(
        "/api/v1/dietitian/assignments/pending", headers=dietitian_headers
    )
    assert after.json()["requests"] == []


def test_dietitian_acceptance_alone_does_not_link(client):
    patient = _register_patient(client, "tek-kabul@example.com")
    dietitian = _register_dietitian(client, "tek-kabul-diyet@example.com")
    assignment_id = _request_link(
        client, _auth(patient), "tek-kabul-diyet@example.com"
    )

    accepted = client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=_auth(dietitian),
    )
    assert accepted.status_code == 200, accepted.text
    body = accepted.json()
    assert body["status"] == "pending"
    assert body["awaiting"] == "patient"
    assert _linked_dietitian_id("tek-kabul@example.com") is None


def test_dietitian_can_reject_request(client):
    patient = _register_patient(client, "ret-hasta@example.com")
    dietitian = _register_dietitian(client, "ret-diyetisyen@example.com")
    assignment_id = _request_link(
        client, _auth(patient), "ret-diyetisyen@example.com"
    )

    rejected = client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/reject",
        headers=_auth(dietitian),
    )
    assert rejected.status_code == 200, rejected.text
    assert rejected.json()["status"] == "rejected"
    assert _linked_dietitian_id("ret-hasta@example.com") is None

    db = SessionLocal()
    try:
        row = db.query(DietitianAssignment).filter(
            DietitianAssignment.id == assignment_id
        ).first()
        assert row.rejected_at is not None
    finally:
        db.close()


def test_dietitian_cannot_act_on_another_dietitians_request(client):
    patient = _register_patient(client, "yabanci-hasta@example.com")
    _register_dietitian(client, "sahip-diyetisyen@example.com")
    outsider = _register_dietitian(client, "yabanci-diyetisyen@example.com")
    assignment_id = _request_link(
        client, _auth(patient), "sahip-diyetisyen@example.com"
    )

    response = client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=_auth(outsider),
    )
    assert response.status_code == 404


def test_dashboard_exposes_pending_requests(client):
    patient = _register_patient(client, "panel-hasta@example.com")
    dietitian = _register_dietitian(client, "panel-diyetisyen@example.com")
    _request_link(client, _auth(patient), "panel-diyetisyen@example.com")

    dashboard = client.get("/api/v1/dietitian/dashboard", headers=_auth(dietitian))
    assert dashboard.status_code == 200, dashboard.text
    body = dashboard.json()
    assert body["pending_assignments"] == 1
    assert len(body["pending_requests"]) == 1
    assert body["pending_requests"][0]["patient_name"] == "Sentetik Hasta"


def test_dietitian_sees_only_own_received_reports(client):
    """Panel yalnız bu diyetisyene ulaşmış raporları gösterir."""
    from datetime import date

    from app.models.database import Dietitian, DietitianReport

    patient = _register_patient(client, "rapor-hasta@example.com")
    dietitian = _register_dietitian(client, "rapor-diyetisyen@example.com")

    db = SessionLocal()
    try:
        profile = db.query(Dietitian).filter(
            Dietitian.email == "rapor-diyetisyen@example.com"
        ).first()
        other = Dietitian(
            id="dddddddd-dddd-4ddd-8ddd-dddddddddddd",
            email="baska-diyetisyen@example.com",
            full_name="Başka Diyetisyen",
            email_verified=True,
        )
        db.add(other)
        db.add_all([
            DietitianReport(
                id="11111111-1111-4111-8111-111111111111",
                user_id=patient["user_id"],
                dietitian_id=profile.id,
                idempotency_key="key-sent",
                consent_context_hash="a" * 64,
                channels_json=["email"],
                recipient_snapshot_json={},
                payload_json={},
                report_type="weekly",
                date_from=date(2026, 8, 24),
                date_to=date(2026, 8, 30),
                total_calories=1850.0,
                total_meals=12,
                record_count=12,
                status="sent",
                sent_via_email=True,
            ),
            # Henüz gönderilmemiş rapor panelde görünmemelidir.
            DietitianReport(
                id="22222222-2222-4222-8222-222222222222",
                user_id=patient["user_id"],
                dietitian_id=profile.id,
                idempotency_key="key-queued",
                consent_context_hash="b" * 64,
                channels_json=["email"],
                recipient_snapshot_json={},
                payload_json={},
                report_type="daily",
                date_from=date(2026, 8, 30),
                date_to=date(2026, 8, 30),
                status="queued",
            ),
            # Başka diyetisyenin raporu sızmamalıdır.
            DietitianReport(
                id="33333333-3333-4333-8333-333333333333",
                user_id=patient["user_id"],
                dietitian_id=other.id,
                idempotency_key="key-other",
                consent_context_hash="c" * 64,
                channels_json=["email"],
                recipient_snapshot_json={},
                payload_json={},
                report_type="weekly",
                date_from=date(2026, 8, 24),
                date_to=date(2026, 8, 30),
                status="sent",
                sent_via_email=True,
            ),
        ])
        db.commit()
    finally:
        db.close()

    listing = client.get("/api/v1/dietitian/reports", headers=_auth(dietitian))
    assert listing.status_code == 200, listing.text
    reports = listing.json()["reports"]
    assert len(reports) == 1
    assert reports[0]["report_id"] == "11111111-1111-4111-8111-111111111111"
    assert reports[0]["patient_name"] == "Sentetik Hasta"
    assert reports[0]["total_calories"] == 1850.0
    assert reports[0]["record_count"] == 12
    assert reports[0]["delivered_via_email"] is True

    dashboard = client.get("/api/v1/dietitian/dashboard", headers=_auth(dietitian))
    assert len(dashboard.json()["recent_reports"]) == 1


def test_patient_cannot_read_dietitian_report_feed(client):
    patient = _register_patient(client, "yetkisiz-hasta@example.com")
    response = client.get("/api/v1/dietitian/reports", headers=_auth(patient))
    assert response.status_code == 403


def _seed_sent_report(patient_id: str, dietitian_id: str, report_id: str):
    """Gönderilmiş bir rapor ve içindeki besin kayıtlarını oluşturur."""
    from datetime import date

    from app.models.database import DietitianReport

    db = SessionLocal()
    try:
        db.add(DietitianReport(
            id=report_id,
            user_id=patient_id,
            dietitian_id=dietitian_id,
            idempotency_key=f"key-{report_id}",
            consent_context_hash="a" * 64,
            channels_json=["email"],
            recipient_snapshot_json={},
            payload_json={
                "patient_name": "Sentetik Hasta",
                "message": "Akşamları çok acıkıyorum, ne önerirsiniz?",
                "average_daily_calories": 925.0,
                "estimated_portion_count": 1,
                "disclaimer": "Bu rapor tahmini beslenme bilgisi içerir.",
                "records": [
                    {
                        "food_name_tr": "Elma",
                        "portion_grams": 150.0,
                        "portion_is_estimate": True,
                        "total_calories": 78.0,
                        "protein": 0.4,
                        "carbs": 20.7,
                        "fat": 0.3,
                        "meal_type": "atistirmalik",
                        "logged_at": "2026-08-24T09:15:00+00:00",
                        "is_corrected": False,
                    },
                ],
                "daily_breakdown": [
                    {"date": "2026-08-24", "calories": 78.0, "record_count": 1},
                ],
            },
            report_type="weekly",
            date_from=date(2026, 8, 24),
            date_to=date(2026, 8, 30),
            total_calories=78.0,
            total_meals=1,
            record_count=1,
            status="sent",
            sent_via_email=True,
        ))
        db.commit()
    finally:
        db.close()


def test_report_detail_exposes_food_records(client):
    """Rapor ayrıntısı besin adı, miktar, saat ve kaloriyi döndürür."""
    patient = _register_patient(client, "detay-hasta@example.com")
    dietitian = _register_dietitian(client, "detay-diyetisyen@example.com")

    from app.models.database import Dietitian

    db = SessionLocal()
    try:
        profile_id = db.query(Dietitian).filter(
            Dietitian.email == "detay-diyetisyen@example.com"
        ).first().id
    finally:
        db.close()

    report_id = "44444444-4444-4444-8444-444444444444"
    _seed_sent_report(patient["user_id"], profile_id, report_id)

    response = client.get(
        f"/api/v1/dietitian/reports/{report_id}", headers=_auth(dietitian)
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["patient_name"] == "Sentetik Hasta"
    assert len(body["records"]) == 1
    record = body["records"][0]
    assert record["food_name_tr"] == "Elma"
    assert record["portion_grams"] == 150.0
    assert record["total_calories"] == 78.0
    assert record["meal_type"] == "atistirmalik"
    assert record["logged_at"].startswith("2026-08-24")
    assert body["daily_breakdown"][0]["record_count"] == 1
    # Danışanın gönderim sırasında yazdığı soru diyetisyene ulaşmalıdır.
    assert body["patient_note"] == "Akşamları çok acıkıyorum, ne önerirsiniz?"
    assert "tıbbi tavsiye" in body["disclaimer"] or body["disclaimer"]


def test_report_detail_is_scoped_to_owning_dietitian(client):
    patient = _register_patient(client, "sizinti-hasta@example.com")
    owner = _register_dietitian(client, "sizinti-sahip@example.com")
    outsider = _register_dietitian(client, "sizinti-yabanci@example.com")

    from app.models.database import Dietitian

    db = SessionLocal()
    try:
        owner_id = db.query(Dietitian).filter(
            Dietitian.email == "sizinti-sahip@example.com"
        ).first().id
    finally:
        db.close()

    report_id = "55555555-5555-4555-8555-555555555555"
    _seed_sent_report(patient["user_id"], owner_id, report_id)

    assert client.get(
        f"/api/v1/dietitian/reports/{report_id}", headers=_auth(owner)
    ).status_code == 200
    assert client.get(
        f"/api/v1/dietitian/reports/{report_id}", headers=_auth(outsider)
    ).status_code == 404


def test_dietitian_can_end_an_approved_assignment(client):
    patient = _register_patient(client, "bitir-hasta@example.com")
    dietitian = _register_dietitian(client, "bitir-diyetisyen@example.com")
    patient_headers = _auth(patient)
    dietitian_headers = _auth(dietitian)
    assignment_id = _request_link(
        client, patient_headers, "bitir-diyetisyen@example.com"
    )
    client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=patient_headers,
    )
    client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=dietitian_headers,
    )
    assert _linked_dietitian_id("bitir-hasta@example.com") is not None

    ended = client.delete(
        f"/api/v1/dietitian/assignments/{assignment_id}",
        headers=dietitian_headers,
    )
    assert ended.status_code == 204, ended.text
    # Bağ koptuğunda hastanın verisi diyetisyene kapanır.
    assert _linked_dietitian_id("bitir-hasta@example.com") is None

    # Bekleyen istek olmadığı için ikinci sonlandırma 404 döner.
    again = client.delete(
        f"/api/v1/dietitian/assignments/{assignment_id}",
        headers=dietitian_headers,
    )
    assert again.status_code == 404


def test_dashboard_patient_carries_daily_target(client):
    patient = _register_patient(client, "hedef-hasta@example.com")
    dietitian = _register_dietitian(client, "hedef-diyetisyen@example.com")
    patient_headers = _auth(patient)
    dietitian_headers = _auth(dietitian)
    assignment_id = _request_link(
        client, patient_headers, "hedef-diyetisyen@example.com"
    )
    client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=patient_headers,
    )
    client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=dietitian_headers,
    )

    dashboard = client.get(
        "/api/v1/dietitian/dashboard", headers=dietitian_headers
    )
    assert dashboard.status_code == 200, dashboard.text
    patients = dashboard.json()["patients"]
    assert len(patients) == 1
    assert patients[0]["daily_calorie_target"] == 2000.0


def test_dietitian_reply_reaches_the_patient(client):
    """Diyetisyenin cevabı hastanın rapor geçmişinde görünür."""
    from app.models.database import Dietitian

    patient = _register_patient(client, "cevap-hasta@example.com")
    dietitian = _register_dietitian(client, "cevap-diyetisyen@example.com")

    db = SessionLocal()
    try:
        profile_id = db.query(Dietitian).filter(
            Dietitian.email == "cevap-diyetisyen@example.com"
        ).first().id
    finally:
        db.close()

    report_id = "66666666-6666-4666-8666-666666666666"
    _seed_sent_report(patient["user_id"], profile_id, report_id)

    reply = client.post(
        f"/api/v1/dietitian/reports/{report_id}/reply",
        headers=_auth(dietitian),
        json={"reply": "Akşam öğününe protein ekleyin."},
    )
    assert reply.status_code == 200, reply.text
    assert reply.json()["dietitian_reply"] == "Akşam öğününe protein ekleyin."
    assert reply.json()["dietitian_replied_at"] is not None

    history = client.get("/api/v1/dietitian-reports", headers=_auth(patient))
    assert history.status_code == 200, history.text
    assert history.json()[0]["dietitian_reply"] == "Akşam öğününe protein ekleyin."


def test_reply_is_scoped_to_owning_dietitian(client):
    from app.models.database import Dietitian

    patient = _register_patient(client, "cevap-sizinti@example.com")
    owner = _register_dietitian(client, "cevap-sahip@example.com")
    outsider = _register_dietitian(client, "cevap-yabanci@example.com")

    db = SessionLocal()
    try:
        owner_id = db.query(Dietitian).filter(
            Dietitian.email == "cevap-sahip@example.com"
        ).first().id
    finally:
        db.close()

    report_id = "77777777-7777-4777-8777-777777777777"
    _seed_sent_report(patient["user_id"], owner_id, report_id)

    blocked = client.post(
        f"/api/v1/dietitian/reports/{report_id}/reply",
        headers=_auth(outsider),
        json={"reply": "Yetkisiz cevap"},
    )
    assert blocked.status_code == 404

    # Boş cevap kabul edilmez.
    empty = client.post(
        f"/api/v1/dietitian/reports/{report_id}/reply",
        headers=_auth(owner),
        json={"reply": "a"},
    )
    assert empty.status_code == 422


def test_dietitian_can_update_own_profile(client):
    dietitian = _register_dietitian(client, "profil-diyetisyen@example.com")

    updated = client.patch(
        "/api/v1/dietitian/profile",
        headers=_auth(dietitian),
        json={"specialization": "Sporcu Beslenmesi", "phone": "+905551112233"},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["specialization"] == "Sporcu Beslenmesi"

    # Numara değişince önceki doğrulama düşer.
    from app.models.database import Dietitian

    db = SessionLocal()
    try:
        profile = db.query(Dietitian).filter(
            Dietitian.email == "profil-diyetisyen@example.com"
        ).first()
        assert profile.phone == "+905551112233"
        assert profile.phone_verified is False
    finally:
        db.close()


def test_patient_cannot_update_dietitian_profile(client):
    patient = _register_patient(client, "profil-hasta@example.com")
    response = client.patch(
        "/api/v1/dietitian/profile",
        headers=_auth(patient),
        json={"specialization": "Sızıntı"},
    )
    assert response.status_code == 403
