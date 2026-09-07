# -*- coding: utf-8 -*-
"""tr222_v1.json config'ini ham veri klasorlerinden uretir."""

import io
import json
import os

RAW = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\data\raw"
OUT = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\configs\tr222_v1.json"
BASE = r"C:\Users\TAHA\Desktop\2209\nutrisense\ml\configs\tr29_v1.json"
DROP = {"__ood__", "kraker"}  # kraker'da 28 gorsel var, egitime yetmez

TR = {
    "apple_pie": "elmalı turta", "baby_back_ribs": "domuz kaburga",
    "beef_carpaccio": "dana karpaçyo", "beef_tartare": "dana tartar",
    "beet_salad": "pancar salatası", "beignets": "beignet hamur tatlısı",
    "bibimbap": "bibimbap", "bread_pudding": "ekmek pudingi",
    "breakfast_burrito": "kahvaltı burrito", "bruschetta": "bruschetta",
    "caesar_salad": "sezar salata", "cannoli": "cannoli",
    "caprese_salad": "caprese salata", "carrot_cake": "havuçlu kek",
    "ceviche": "ceviche", "cheese_plate": "peynir tabağı",
    "cheesecake": "cheesecake", "chicken_curry": "tavuk körü",
    "chicken_quesadilla": "tavuklu quesadilla", "chicken_wings": "tavuk kanat",
    "chocolate_cake": "çikolatalı kek", "chocolate_mousse": "çikolatalı mus",
    "churros": "churros", "clam_chowder": "deniz tarağı çorbası",
    "club_sandwich": "kulüp sandviç", "crab_cakes": "yengeç köftesi",
    "creme_brulee": "krem brüle", "croque_madame": "croque madame",
    "cup_cakes": "kapkek", "deviled_eggs": "baharatlı yumurta",
    "donuts": "donut", "dumplings": "buğulama mantı",
    "edamame": "edamame", "eggs_benedict": "eggs benedict",
    "escargots": "salyangoz", "falafel": "falafel",
    "filet_mignon": "fileto mignon", "fish_and_chips": "balık ve patates",
    "foie_gras": "kaz ciğeri", "french_fries": "patates kızartması",
    "french_onion_soup": "soğan çorbası", "french_toast": "fransız tostu",
    "fried_calamari": "kalamar tava", "fried_rice": "kızarmış pilav",
    "frozen_yogurt": "donmuş yoğurt", "garlic_bread": "sarımsaklı ekmek",
    "gnocchi": "gnocchi", "greek_salad": "yunan salatası",
    "grilled_cheese_sandwich": "kaşarlı tost", "grilled_salmon": "ızgara somon",
    "guacamole": "guacamole", "gyoza": "gyoza", "hamburger": "hamburger",
    "hot_and_sour_soup": "acı ekşi çorba", "hot_dog": "sosisli sandviç",
    "huevos_rancheros": "huevos rancheros", "hummus": "humus",
    "ice_cream": "dondurma", "lasagna": "lazanya",
    "lobster_bisque": "ıstakoz çorbası", "lobster_roll_sandwich": "ıstakoz sandviç",
    "macaroni_and_cheese": "peynirli makarna", "macarons": "makaron",
    "miso_soup": "miso çorbası", "mussels": "midye", "nachos": "nachos",
    "omelette": "omlet", "onion_rings": "soğan halkası", "oysters": "istiridye",
    "pad_thai": "pad thai", "paella": "paella", "pancakes": "pankek",
    "panna_cotta": "panna cotta", "peking_duck": "peking ördeği",
    "pho": "pho", "pizza": "pizza", "pork_chop": "domuz pirzola",
    "poutine": "poutine", "prime_rib": "kaburga rosto",
    "pulled_pork_sandwich": "didilmiş domuz sandviç", "ramen": "ramen",
    "ravioli": "ravioli", "red_velvet_cake": "red velvet kek",
    "risotto": "rizotto", "samosa": "samosa", "sashimi": "sashimi",
    "scallops": "deniz tarağı", "seaweed_salad": "yosun salatası",
    "shrimp_and_grits": "karidesli irmik", "spaghetti_bolognese": "bolonez spagetti",
    "spaghetti_carbonara": "karbonara spagetti", "spring_rolls": "bahar rulosu",
    "steak": "biftek", "strawberry_shortcake": "çilekli pasta",
    "sushi": "suşi", "tacos": "tako", "takoyaki": "takoyaki",
    "tiramisu": "tiramisu", "tuna_tartare": "ton balığı tartar",
    "waffles": "waffle",
    # Turkce slug'larda otomatik uretimin yetmedigi ozel durumlar
    "asure": "aşure", "biber_dolmasi": "biber dolması", "borek": "börek",
    "cig_kofte": "çiğ köfte", "et_sote": "et sote", "gozleme": "gözleme",
    "hunkar_begendi": "hünkar beğendi", "icli_kofte": "içli köfte",
    "ispanak": "ıspanak yemeği", "izmir_kofte": "İzmir köfte",
    "karniyarik": "karnıyarık", "kisir": "kısır", "manti": "mantı",
    "mucver": "mücver", "pirinc_pilavi": "pirinç pilavı",
    "yas_pasta": "yaş pasta", "cay": "çay", "cilek": "çilek",
    "cipura": "çipura", "cacik": "cacık", "coban_salatasi": "çoban salatası",
    "doner": "döner", "kokorec": "kokoreç", "misir": "mısır",
    "muz": "muz", "seftali": "şeftali", "sehriye_corbasi": "şehriye çorbası",
    "sutlac": "sütlaç", "tursu": "turşu", "uzum": "üzüm",
    "yogurt": "yoğurt", "yogurtlu_makarna": "yoğurtlu makarna",
    "sulu_bamya_yemegi": "bamya yemeği", "sulu_barbunya_yemegi": "barbunya yemeği",
    "sulu_bezelye_yemegi": "bezelye yemeği", "sulu_mercimek_yemegi": "mercimek yemeği",
    "sulu_nohut_yemegi": "nohut yemeği", "sulu_patates_yemegi": "patates yemeği",
    "kuru_fasulye": "kuru fasulye", "turk_kahvesi": "Türk kahvesi",
    "kemal_pasa_tatlisi": "Kemalpaşa tatlısı", "kiymali_borek": "kıymalı börek",
    "kiymali_pide": "kıymalı pide", "peynirli_borek": "peynirli börek",
    "su_boregi": "su böreği", "bruksel_lahanasi": "Brüksel lahanası",
    "beyaz_lahana_sarmasi": "beyaz lahana sarması", "haslanmis_yumurta": "haşlanmış yumurta",
    "salcali_makarna": "salçalı makarna", "sandvic": "sandviç",
    "patlamis_misir": "patlamış mısır", "patlican_kebabi": "patlıcan kebabı",
    "tarhana_corbasi": "tarhana çorbası", "tas_kebabi": "taş kebabı",
    "tavuk_sote": "tavuk sote", "yayla_corbasi": "yayla çorbası",
    "zeytinyagli_fasulye": "zeytinyağlı fasulye", "sucuklu_yumurta": "sucuklu yumurta",
    "mumbar_dolmasi": "mumbar dolması", "midye_dolma": "midye dolma",
    "midye_tava": "midye tava", "mercimek_corbasi": "mercimek çorbası",
    "mercimek_koftesi": "mercimek köftesi", "domates_corbasi": "domates çorbası",
    "meyve_suyu": "meyve suyu", "muffin_kek": "muffin kek",
    "halka_corek": "halka çörek", "elmali_turta": "elmalı turta",
    "anne_koftesi": "ev köftesi", "adana_kebap": "Adana kebap",
    "siyah_zeytin": "siyah zeytin", "yesil_zeytin": "yeşil zeytin",
    "patates_puresi": "patates püresi", "patates_salatasi": "patates salatası",
    "bulgur_pilavi": "bulgur pilavı", "kalburabasti": "kalburabastı",
    "tulumba_tatlisi": "tulumba tatlısı", "yaprak_sarma": "yaprak sarma",
    "havuc": "havuç", "kayisi": "kayısı", "pirasa": "pırasa",
    "salatalik": "salatalık", "iskender": "İskender", "kazandibi": "kazandibi",
    "ananas": "ananas", "armut": "armut", "avokado": "avokado", "ayran": "ayran",
    "brokoli": "brokoli", "domates": "domates", "ekmek": "ekmek", "elma": "elma",
    "enginar": "enginar", "erik": "erik", "hamsi": "hamsi", "incir": "incir",
    "karides": "karides", "karnabahar": "karnabahar", "karpuz": "karpuz",
    "kavun": "kavun", "kebap": "kebap", "kiraz": "kiraz", "kivi": "kivi",
    "kola": "kola", "kurabiye": "kurabiye", "lahmacun": "lahmacun",
    "levrek": "levrek", "limon": "limon", "lokma": "lokma", "lokum": "lokum",
    "mango": "mango", "menemen": "menemen", "nar": "nar", "peynir": "peynir",
    "portakal": "portakal", "sahlep": "salep", "simit": "simit",
    "somon": "somon", "tantuni": "tantuni", "taze_fasulye": "taze fasulye",
    "baklava": "baklava",
}

classes = sorted(
    d for d in os.listdir(RAW)
    if os.path.isdir(os.path.join(RAW, d)) and d not in DROP
)
missing = [c for c in classes if c not in TR]
base = json.load(io.open(BASE, encoding="utf-8"))

config = {
    "schema_version": 1,
    "scope_id": "nutrisense-tr222-v1",
    "seed": 2209,
    "image": base["image"],
    "splits": base["splits"],
    "classes": [
        {
            "id": c,
            "tr": TR.get(c, c.replace("_", " ")),
            "target": 200,
            "source_plan": "Food-101, Turkish-Food-Dataset-Combined ve proje cekimleri",
            "min_groups": 60,
            "confusions": [],
        }
        for c in classes
    ],
    "ood": base["ood"],
    "model": dict(base["model"], batch_size=48),
    "decision": base["decision"],
}
io.open(OUT, "w", encoding="utf-8", newline="\n").write(
    json.dumps(config, ensure_ascii=False, indent=2) + "\n"
)
print("sinif:", len(classes))
print("turkce adi eksik:", missing)
