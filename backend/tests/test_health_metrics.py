"""Su, adım, uyku, ruh hâli ve kilo ölçümleri hesaba bağlı saklanır."""

PASSWORD = "Guvenli123"


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _register(client, email: str) -> dict:
    response = client.post("/api/v1/auth/register", json={
        "email": email,
        "password": PASSWORD,
        "full_name": "Sentetik Kullanıcı",
    })
    assert response.status_code == 201, response.text
    return response.json()


def test_today_metrics_start_empty(client):
    user = _register(client, "olcum-bos@example.com")
    response = client.get("/api/v1/health-metrics/today", headers=_auth(user))
    assert response.status_code == 200, response.text
    body = response.json()
    # Uydurma başlangıç değeri olmamalıdır.
    assert body["water_ml"] == 0
    assert body["steps"] == 0
    assert body["sleep_hours"] == 0
    assert body["mood"] is None


def test_partial_update_keeps_other_fields(client):
    user = _register(client, "olcum-kismi@example.com")
    headers = _auth(user)

    first = client.put(
        "/api/v1/health-metrics/today",
        headers=headers,
        json={"water_ml": 750, "steps": 3200},
    )
    assert first.status_code == 200, first.text
    assert first.json()["water_ml"] == 750

    # Yalnız uyku gönderilir; su ve adım korunmalıdır.
    second = client.put(
        "/api/v1/health-metrics/today",
        headers=headers,
        json={"sleep_hours": 7.5},
    )
    assert second.status_code == 200, second.text
    body = second.json()
    assert body["sleep_hours"] == 7.5
    assert body["water_ml"] == 750
    assert body["steps"] == 3200


def test_metrics_are_scoped_to_the_owner(client):
    first = _register(client, "olcum-sahip@example.com")
    second = _register(client, "olcum-baskasi@example.com")

    client.put(
        "/api/v1/health-metrics/today",
        headers=_auth(first),
        json={"water_ml": 1500},
    )
    other = client.get("/api/v1/health-metrics/today", headers=_auth(second))
    assert other.status_code == 200
    assert other.json()["water_ml"] == 0


def test_invalid_measurements_are_rejected(client):
    user = _register(client, "olcum-gecersiz@example.com")
    headers = _auth(user)

    assert client.put(
        "/api/v1/health-metrics/today", headers=headers,
        json={"sleep_hours": 25},
    ).status_code == 422
    assert client.put(
        "/api/v1/health-metrics/today", headers=headers,
        json={"water_ml": -1},
    ).status_code == 422
    assert client.post(
        "/api/v1/health-metrics/weight", headers=headers,
        json={"weight_kg": 0},
    ).status_code == 422


def test_weight_history_is_ordered_oldest_first(client):
    user = _register(client, "kilo-gecmis@example.com")
    headers = _auth(user)

    for weight in (80.0, 79.4, 78.9):
        created = client.post(
            "/api/v1/health-metrics/weight",
            headers=headers,
            json={"weight_kg": weight},
        )
        assert created.status_code == 201, created.text

    history = client.get("/api/v1/health-metrics/weight", headers=headers)
    assert history.status_code == 200, history.text
    body = history.json()
    values = [item["weight_kg"] for item in body["measurements"]]
    assert values == [80.0, 79.4, 78.9]
    # Güncel kilo son ölçümdür.
    assert body["current_weight"] == 78.9


def test_weight_history_is_empty_for_new_user(client):
    user = _register(client, "kilo-bos@example.com")
    history = client.get("/api/v1/health-metrics/weight", headers=_auth(user))
    assert history.status_code == 200
    assert history.json()["measurements"] == []
    assert history.json()["current_weight"] is None


def test_metrics_require_authentication(client):
    assert client.get("/api/v1/health-metrics/today").status_code == 401
    assert client.get("/api/v1/health-metrics/weight").status_code == 401


def test_account_deletion_erases_health_measurements(client):
    """Silme hakkı: hesap silinince sağlık ölçümleri de gider."""
    from app.models.database import HealthMetric, SessionLocal, WeightMeasurement

    user = _register(client, "silme-saglik@example.com")
    headers = _auth(user)
    user_id = user["user_id"]

    client.put("/api/v1/health-metrics/today", headers=headers,
               json={"water_ml": 500, "mood": "mutlu"})
    client.post("/api/v1/health-metrics/weight", headers=headers,
                json={"weight_kg": 70.5})

    deleted = client.request(
        "DELETE", "/api/v1/users/me", headers=headers,
        json={"password": PASSWORD, "confirmation": "HESABIMI SIL"},
    )
    assert deleted.status_code in (200, 204), deleted.text

    db = SessionLocal()
    try:
        assert db.query(HealthMetric).filter(
            HealthMetric.user_id == user_id).count() == 0
        assert db.query(WeightMeasurement).filter(
            WeightMeasurement.user_id == user_id).count() == 0
    finally:
        db.close()


def test_export_includes_health_measurements(client):
    """Taşınabilirlik hakkı: dışa aktarım sağlık ölçümlerini de içerir."""
    user = _register(client, "export-saglik@example.com")
    headers = _auth(user)

    client.put("/api/v1/health-metrics/today", headers=headers,
               json={"water_ml": 900, "steps": 4200, "mood": "yorgun"})
    client.post("/api/v1/health-metrics/weight", headers=headers,
                json={"weight_kg": 68.2})

    export = client.get("/api/v1/users/me/export", headers=headers)
    assert export.status_code == 200, export.text
    body = export.json()
    assert body["health_metrics"][0]["water_ml"] == 900
    assert body["health_metrics"][0]["mood"] == "yorgun"
    assert body["weight_measurements"][0]["weight_kg"] == 68.2
