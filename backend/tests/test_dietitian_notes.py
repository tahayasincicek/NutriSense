"""Diyetisyen notları birikir: yeni kayıt öncekinin üzerine yazmaz."""

PASSWORD = "Guvenli123"


def _auth(tokens: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def _linked_pair(client, slug: str) -> tuple[dict, dict, str]:
    """Onaylı bir hasta-diyetisyen çifti kurar; not yazımı buna bağlı."""
    patient = client.post("/api/v1/auth/register", json={
        "email": f"{slug}-hasta@example.com",
        "password": PASSWORD,
        "full_name": "Sentetik Hasta",
    }).json()
    dietitian = client.post("/api/v1/auth/register-dietitian", json={
        "email": f"{slug}-diyetisyen@example.com",
        "password": PASSWORD,
        "full_name": "Sentetik Diyetisyen",
        "specialization": "Beslenme ve Diyet",
    }).json()
    patient_headers = _auth(patient)
    dietitian_headers = _auth(dietitian)

    assignment = client.post(
        "/api/v1/dietitians/assignment",
        headers=patient_headers,
        json={"dietitian_email": f"{slug}-diyetisyen@example.com"},
    ).json()
    assignment_id = assignment["assignment_id"]
    client.post(
        f"/api/v1/dietitians/assignment/{assignment_id}/approve",
        headers=patient_headers,
    )
    accepted = client.post(
        f"/api/v1/dietitian/assignments/{assignment_id}/accept",
        headers=dietitian_headers,
    )
    assert accepted.status_code == 200, accepted.text

    patients = client.get(
        "/api/v1/dietitian/dashboard", headers=dietitian_headers
    ).json()["patients"]
    return patient_headers, dietitian_headers, patients[0]["user_id"]


def test_notes_accumulate_newest_first(client):
    _, dietitian_headers, user_id = _linked_pair(client, "birikim")
    base = f"/api/v1/dietitian/patients/{user_id}/notes"

    assert client.get(base, headers=dietitian_headers).json()["items"] == []

    first = client.post(
        base, headers=dietitian_headers, json={"body": "Laktoz intoleransı."}
    )
    assert first.status_code == 201, first.text

    second = client.post(
        base, headers=dietitian_headers, json={"body": "Akşam sporu yapıyor."}
    )
    assert second.status_code == 201, second.text

    # İkinci not birincinin üzerine yazmaz; liste yeniden eskiye gelir.
    items = client.get(base, headers=dietitian_headers).json()["items"]
    assert [item["body"] for item in items] == [
        "Akşam sporu yapıyor.",
        "Laktoz intoleransı.",
    ]


def test_note_can_be_deleted_without_touching_others(client):
    _, dietitian_headers, user_id = _linked_pair(client, "silme")
    base = f"/api/v1/dietitian/patients/{user_id}/notes"

    client.post(base, headers=dietitian_headers, json={"body": "Kalacak not."})
    client.post(base, headers=dietitian_headers, json={"body": "Silinecek."})
    items = client.get(base, headers=dietitian_headers).json()["items"]
    target = next(item for item in items if item["body"] == "Silinecek.")

    deleted = client.delete(
        f"{base}/{target['id']}", headers=dietitian_headers
    )
    assert deleted.status_code == 200, deleted.text
    assert [item["body"] for item in deleted.json()["items"]] == [
        "Kalacak not."
    ]


def test_notes_are_closed_to_unassigned_dietitian(client):
    _, _, user_id = _linked_pair(client, "yabanci-hedef")
    stranger = client.post("/api/v1/auth/register-dietitian", json={
        "email": "yabanci-diyetisyen@example.com",
        "password": PASSWORD,
        "full_name": "Yabancı Diyetisyen",
        "specialization": "Beslenme ve Diyet",
    }).json()
    base = f"/api/v1/dietitian/patients/{user_id}/notes"

    # Sağlık verisi: eşleşmesi olmayan diyetisyen ne okuyabilir ne yazabilir.
    assert client.get(base, headers=_auth(stranger)).status_code == 404
    written = client.post(
        base, headers=_auth(stranger), json={"body": "Görmemeli."}
    )
    assert written.status_code == 404
