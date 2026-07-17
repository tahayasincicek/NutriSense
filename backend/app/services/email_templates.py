# ==============================================================================
# backend/app/services/email_templates.py
# NutriSense — Gelişmiş HTML + Plain-Text E-posta Şablonları
#
# Jinja2 ile render edilen diyetisyen rapor e-postası:
#   - Kullanıcı adı, tarih aralığı
#   - Günlük kalori tablosu
#   - En çok tüketilen 5 besin
#   - Makro dağılım özeti
#   - Dikkat çeken değerler (kırmızı/yeşil vurgulama)
# ==============================================================================

from jinja2 import Template
from collections import Counter

# ═══════════════════════════════════════════════════════════════════════════════
# HTML E-POSTA ŞABLONU
# ═══════════════════════════════════════════════════════════════════════════════

REPORT_HTML_TEMPLATE = Template("""
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        /* ── Global ── */
        body {
            font-family: 'Segoe UI', -apple-system, Arial, sans-serif;
            background: #f0f2f5; margin: 0; padding: 24px;
            color: #1a1a1a; line-height: 1.6;
        }
        .container {
            max-width: 640px; margin: 0 auto; background: #ffffff;
            border-radius: 16px; overflow: hidden;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
        }

        /* ── Header ── */
        .header {
            background: linear-gradient(135deg, #1B5E20 0%, #2E7D32 50%, #43A047 100%);
            color: white; padding: 32px; text-align: center;
        }
        .header h1 { margin: 0; font-size: 26px; font-weight: 800; letter-spacing: -0.5px; }
        .header .subtitle { margin: 8px 0 0; opacity: 0.9; font-size: 15px; }
        .header .date-range {
            margin-top: 12px; display: inline-block;
            background: rgba(255,255,255,0.2); padding: 6px 16px;
            border-radius: 20px; font-size: 14px;
        }

        /* ── Content ── */
        .content { padding: 28px; }

        /* ── Özet Kartları ── */
        .stats-grid {
            display: grid; grid-template-columns: 1fr 1fr;
            gap: 12px; margin-bottom: 24px;
        }
        .stat-card {
            background: #f8f9fa; border-radius: 12px;
            padding: 16px; text-align: center;
            border: 1px solid #e9ecef;
        }
        .stat-value {
            font-size: 32px; font-weight: 800;
            color: #1B5E20; line-height: 1.2;
        }
        .stat-label { font-size: 12px; color: #666; margin-top: 4px; text-transform: uppercase; }

        /* ── Makro Dağılımı ── */
        .macro-bar { display: flex; height: 24px; border-radius: 12px; overflow: hidden; margin: 8px 0; }
        .macro-protein { background: #2196F3; }
        .macro-carb { background: #FF9800; }
        .macro-fat { background: #F44336; }
        .macro-legend { display: flex; gap: 16px; margin: 8px 0 20px; font-size: 13px; }
        .macro-dot { width: 10px; height: 10px; border-radius: 50%; display: inline-block; margin-right: 4px; }

        /* ── Tablo ── */
        table { width: 100%%; border-collapse: collapse; margin: 16px 0; font-size: 14px; }
        th {
            background: #1B5E20; color: white; padding: 12px 10px;
            text-align: left; font-size: 13px; font-weight: 600;
        }
        td { padding: 10px; border-bottom: 1px solid #f0f0f0; }
        tr:nth-child(even) { background: #fafafa; }
        tr:hover { background: #f0f7f0; }

        /* ── Alert Renkler ── */
        .alert-high { color: #D32F2F; font-weight: 700; }
        .alert-low { color: #F57C00; font-weight: 600; }
        .alert-ok { color: #2E7D32; }

        /* ── En Çok Tüketilen ── */
        .top-foods { margin: 20px 0; }
        .top-food-item {
            display: flex; align-items: center;
            padding: 10px 0; border-bottom: 1px solid #f0f0f0;
        }
        .top-food-rank {
            width: 28px; height: 28px; border-radius: 50%;
            background: #E8F5E9; color: #1B5E20;
            display: flex; align-items: center; justify-content: center;
            font-weight: 700; font-size: 13px; margin-right: 12px;
        }
        .top-food-name { flex: 1; font-weight: 600; }
        .top-food-count { color: #666; font-size: 13px; }

        /* ── Not ── */
        .patient-note {
            background: #FFF3E0; border-left: 4px solid #FF9800;
            padding: 14px 16px; margin: 20px 0; border-radius: 0 8px 8px 0;
        }

        /* ── Dikkat ── */
        .attention-box {
            background: #FFEBEE; border-left: 4px solid #D32F2F;
            padding: 14px 16px; margin: 20px 0; border-radius: 0 8px 8px 0;
        }
        .good-box {
            background: #E8F5E9; border-left: 4px solid #2E7D32;
            padding: 14px 16px; margin: 20px 0; border-radius: 0 8px 8px 0;
        }

        /* ── Footer ── */
        .footer {
            text-align: center; padding: 20px; color: #999; font-size: 12px;
            border-top: 1px solid #f0f0f0;
        }
    </style>
</head>
<body>
<div class="container">
    <!-- ════ HEADER ════ -->
    <div class="header">
        <h1>🍽️ NutriSense Beslenme Raporu</h1>
        <div class="subtitle">{{ patient_name }} — {{ report_type_tr }} Rapor</div>
        <div class="date-range">📅 {{ from_date }} — {{ to_date }}</div>
    </div>

    <div class="content">
        <!-- ════ ÖZET KARTLARI ════ -->
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">{{ total_calories|round|int }}</div>
                <div class="stat-label">Toplam Kalori</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{{ avg_daily_calories|round|int }}</div>
                <div class="stat-label">Günlük Ortalama</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{{ total_meals }}</div>
                <div class="stat-label">Toplam Öğün</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{{ total_days }}</div>
                <div class="stat-label">Gün Sayısı</div>
            </div>
        </div>

        <!-- ════ MAKRO DAĞILIMI ════ -->
        {% if avg_protein or avg_carbs or avg_fat %}
        <h3 style="margin-bottom:8px;">📊 Ortalama Makro Dağılımı</h3>
        {% set macro_total = avg_protein + avg_carbs + avg_fat %}
        {% if macro_total > 0 %}
        <div class="macro-bar">
            <div class="macro-protein" style="width:{{ (avg_protein/macro_total*100)|round }}%%"></div>
            <div class="macro-carb" style="width:{{ (avg_carbs/macro_total*100)|round }}%%"></div>
            <div class="macro-fat" style="width:{{ (avg_fat/macro_total*100)|round }}%%"></div>
        </div>
        <div class="macro-legend">
            <span><span class="macro-dot" style="background:#2196F3"></span>Protein: {{ avg_protein|round(1) }}g ({{ (avg_protein/macro_total*100)|round }}%%)</span>
            <span><span class="macro-dot" style="background:#FF9800"></span>Karb: {{ avg_carbs|round(1) }}g ({{ (avg_carbs/macro_total*100)|round }}%%)</span>
            <span><span class="macro-dot" style="background:#F44336"></span>Yağ: {{ avg_fat|round(1) }}g ({{ (avg_fat/macro_total*100)|round }}%%)</span>
        </div>
        {% endif %}
        {% endif %}

        <!-- ════ DİKKAT KUTULARI ════ -->
        {% for alert in alerts %}
        {% if alert.type == 'warning' %}
        <div class="attention-box">
            <strong>⚠️ Dikkat:</strong> {{ alert.message }}
        </div>
        {% elif alert.type == 'good' %}
        <div class="good-box">
            <strong>✅ Olumlu:</strong> {{ alert.message }}
        </div>
        {% endif %}
        {% endfor %}

        <!-- ════ GÜNLÜK TABLO ════ -->
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
                    <td class="{{ 'alert-high' if day.calories > calorie_target * 1.2 else 'alert-ok' if day.calories <= calorie_target else 'alert-low' }}">
                        {{ day.calories|round|int }} kcal
                    </td>
                    <td>{{ day.protein|round(1) }}g</td>
                    <td>{{ day.carbs|round(1) }}g</td>
                    <td>{{ day.fat|round(1) }}g</td>
                    <td>{{ day.meal_count }}</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% endif %}

        <!-- ════ EN ÇOK TÜKETİLEN 5 BESİN ════ -->
        {% if top_foods %}
        <h3>🏆 En Çok Tüketilen Besinler</h3>
        <div class="top-foods">
            {% for food in top_foods %}
            <div class="top-food-item">
                <div class="top-food-rank">{{ loop.index }}</div>
                <div class="top-food-name">{{ food.name }}</div>
                <div class="top-food-count">{{ food.count }} kez</div>
            </div>
            {% endfor %}
        </div>
        {% endif %}

        <!-- ════ HASTA NOTU ════ -->
        {% if patient_message %}
        <div class="patient-note">
            <strong>💬 Hasta Notu:</strong><br>
            {{ patient_message }}
        </div>
        {% endif %}
    </div>

    <!-- ════ FOOTER ════ -->
    <div class="footer">
        NutriSense — Görme Engelliler İçin Akıllı Besin Takibi<br>
        Bu rapor otomatik olarak oluşturulmuştur. © 2026
    </div>
</div>
</body>
</html>
""")


# ═══════════════════════════════════════════════════════════════════════════════
# PLAIN-TEXT E-POSTA ŞABLONU
# ═══════════════════════════════════════════════════════════════════════════════

REPORT_PLAINTEXT_TEMPLATE = Template("""
╔══════════════════════════════════════════════╗
║      NutriSense Beslenme Raporu              ║
╚══════════════════════════════════════════════╝

Hasta: {{ patient_name }}
Rapor Türü: {{ report_type_tr }}
Tarih Aralığı: {{ from_date }} — {{ to_date }}

────────────────────────────────────────────────
  ÖZET
────────────────────────────────────────────────
  Toplam Kalori:    {{ total_calories|round|int }} kcal
  Günlük Ortalama:  {{ avg_daily_calories|round|int }} kcal
  Toplam Öğün:      {{ total_meals }}
  Gün Sayısı:       {{ total_days }}

{% if avg_protein or avg_carbs or avg_fat %}
────────────────────────────────────────────────
  MAKRO DAĞILIMI (Günlük Ortalama)
────────────────────────────────────────────────
  Protein:       {{ avg_protein|round(1) }}g
  Karbonhidrat:  {{ avg_carbs|round(1) }}g
  Yağ:           {{ avg_fat|round(1) }}g
{% endif %}

{% for alert in alerts %}
{% if alert.type == 'warning' %}⚠️  DİKKAT: {{ alert.message }}
{% elif alert.type == 'good' %}✅  OLUMLU: {{ alert.message }}
{% endif %}
{% endfor %}

{% if daily_breakdown %}
────────────────────────────────────────────────
  GÜNLÜK DAĞILIM
────────────────────────────────────────────────
{% for day in daily_breakdown %}
  {{ day.date }}  |  {{ day.calories|round|int }} kcal  |  P:{{ day.protein|round(1) }}g  K:{{ day.carbs|round(1) }}g  Y:{{ day.fat|round(1) }}g  |  {{ day.meal_count }} öğün
{% endfor %}
{% endif %}

{% if top_foods %}
────────────────────────────────────────────────
  EN ÇOK TÜKETİLEN BESİNLER
────────────────────────────────────────────────
{% for food in top_foods %}
  {{ loop.index }}. {{ food.name }} ({{ food.count }} kez)
{% endfor %}
{% endif %}

{% if patient_message %}
────────────────────────────────────────────────
  HASTA NOTU
────────────────────────────────────────────────
  {{ patient_message }}
{% endif %}

──────────────────────────────────────────────
NutriSense — Görme Engelliler İçin Akıllı Besin Takibi
Bu rapor otomatik olarak oluşturulmuştur.
""")


# ═══════════════════════════════════════════════════════════════════════════════
# RAPOR VERİ HAZIRLAMA
# ═══════════════════════════════════════════════════════════════════════════════

def prepare_report_context(
    patient_name: str,
    report_type: str,
    report_data: dict,
    calorie_target: float = 2000.0,
) -> dict:
    """
    E-posta şablonları için render context'i hazırlar.

    Args:
        patient_name: Hasta adı
        report_type: "daily" | "weekly" | "monthly"
        report_data: API'den gelen rapor verisi
        calorie_target: Günlük kalori hedefi

    Returns:
        Jinja2 render context dict
    """
    report_type_map = {
        "daily": "Günlük",
        "weekly": "Haftalık",
        "monthly": "Aylık",
    }

    daily_breakdown = report_data.get("daily_breakdown", [])

    # ── Ortalama makrolar ──
    total_days = max(len(daily_breakdown), 1)
    avg_protein = sum(d.get("protein", 0) for d in daily_breakdown) / total_days
    avg_carbs = sum(d.get("carbs", 0) for d in daily_breakdown) / total_days
    avg_fat = sum(d.get("fat", 0) for d in daily_breakdown) / total_days

    # ── En çok tüketilen besinler ──
    all_foods = report_data.get("all_food_names", [])
    food_counts = Counter(all_foods)
    top_foods = [
        {"name": name, "count": count}
        for name, count in food_counts.most_common(5)
    ]

    # ── Dikkat çeken değerler ──
    alerts = _generate_alerts(
        daily_breakdown=daily_breakdown,
        calorie_target=calorie_target,
        avg_protein=avg_protein,
        avg_carbs=avg_carbs,
        avg_fat=avg_fat,
    )

    return {
        "patient_name": patient_name,
        "report_type_tr": report_type_map.get(report_type, "Haftalık"),
        "from_date": report_data.get("from_date", ""),
        "to_date": report_data.get("to_date", ""),
        "total_calories": report_data.get("total_calories", 0),
        "avg_daily_calories": report_data.get("avg_daily_calories", 0),
        "total_meals": report_data.get("total_meals", 0),
        "total_days": report_data.get("total_days", 0),
        "calorie_target": calorie_target,
        "avg_protein": avg_protein,
        "avg_carbs": avg_carbs,
        "avg_fat": avg_fat,
        "daily_breakdown": daily_breakdown,
        "top_foods": top_foods,
        "alerts": alerts,
        "patient_message": report_data.get("message"),
    }


def _generate_alerts(
    daily_breakdown: list,
    calorie_target: float,
    avg_protein: float,
    avg_carbs: float,
    avg_fat: float,
) -> list[dict]:
    """Dikkat çeken değerleri analiz eder ve uyarı listesi oluşturur."""
    alerts = []

    if not daily_breakdown:
        return alerts

    avg_cal = sum(d.get("calories", 0) for d in daily_breakdown) / len(daily_breakdown)

    # Kalori uyarıları
    if avg_cal > calorie_target * 1.2:
        over = ((avg_cal / calorie_target) - 1) * 100
        alerts.append({
            "type": "warning",
            "message": f"Günlük ortalama kalori hedefe göre %{over:.0f} fazla. "
                       f"Porsiyon kontrolüne dikkat edilmesi önerilir.",
        })
    elif avg_cal < calorie_target * 0.5:
        alerts.append({
            "type": "warning",
            "message": "Günlük kalori alımı hedefin yarısının altında. "
                       "Yetersiz beslenme riski olabilir.",
        })
    elif 0.9 * calorie_target <= avg_cal <= 1.1 * calorie_target:
        alerts.append({
            "type": "good",
            "message": "Kalori alımı hedefle uyumlu. Dengeli bir beslenme süreci gözlemleniyor.",
        })

    # Protein uyarıları
    if avg_protein < 30:
        alerts.append({
            "type": "warning",
            "message": f"Günlük ortalama protein alımı düşük ({avg_protein:.0f}g). "
                       f"Protein kaynaklarının artırılması önerilir.",
        })
    elif avg_protein > 50:
        alerts.append({
            "type": "good",
            "message": f"Protein alımı yeterli düzeyde ({avg_protein:.0f}g/gün).",
        })

    # Yağ uyarısı
    if avg_fat > 80:
        alerts.append({
            "type": "warning",
            "message": f"Günlük ortalama yağ alımı yüksek ({avg_fat:.0f}g). "
                       f"Doymuş yağ kaynaklarının azaltılması düşünülebilir.",
        })

    # Öğün düzeni uyarısı
    avg_meals = sum(d.get("meal_count", 0) for d in daily_breakdown) / len(daily_breakdown)
    if avg_meals < 2:
        alerts.append({
            "type": "warning",
            "message": f"Günlük ortalama öğün sayısı düşük ({avg_meals:.1f}). "
                       f"Düzenli öğün alışkanlığı sağlık için önemlidir.",
        })

    return alerts


def render_html_report(context: dict) -> str:
    """HTML e-posta raporu render eder."""
    return REPORT_HTML_TEMPLATE.render(**context)


def render_plaintext_report(context: dict) -> str:
    """Plain-text e-posta raporu render eder."""
    return REPORT_PLAINTEXT_TEMPLATE.render(**context)
