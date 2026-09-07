"""Rebuild the reviewed FNDDS subset from the official, pinned USDA archive.

Usage: python scripts/build_nutrition_catalog.py --archive /path/fndds.zip
No network, API key, participant data, or database access is required.
"""

import argparse
import hashlib
import json
from pathlib import Path
import zipfile


ARCHIVE_SHA256 = "dfb06ae7ddc397ccd570b91c14b75438ab2ba39f64f22d321f61d4a52a77f3eb"
SOURCE_URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_survey_food_json_2024-10-31.zip"
# Hacim olcusunun mililitre karsiligi. Yogunluk, FNDDS porsiyonunun gram
# agirligi bu hacme bolunerek bulunur; sabit "1 ml = 1 g" varsayilmaz.
MILLILITRES = {
    "1 fl oz": 29.5735,
    "1 fl oz (NFS)": 29.5735,
    "1 fl oz (no ice)": 29.5735,
    "1 cup": 236.588,
}
# Katilarda "1 cup" bir hacim olcusudur ama yogunluk degildir: bir su bardagi
# ekmek 40 gramdir. Bu yuzden ml birimi yalnizca burada icecek olarak
# isaretlenen kayitlara verilir; heuristik ile turetilmez.
REVIEWED = {
    # ── İçecekler ───────────────────────────────────────────────────
    2710488: (
        "tea", "Tea, hot, leaf, black",
        "Çay (siyah, demleme)", (("ml", "1 fl oz"),),
    ),
    2710490: (
        "green_tea", "Tea, hot, leaf, green",
        "Yeşil çay", (("ml", "1 fl oz"),),
    ),
    2710377: (
        "turkish_coffee", "Coffee, Turkish",
        "Türk kahvesi", (("ml", "1 fl oz"),),
    ),
    2710375: (
        "brewed_coffee", "Coffee, brewed",
        "Filtre kahve", (("ml", "1 fl oz"),),
    ),
    2705385: (
        "milk", "Milk, whole",
        "Süt (tam yağlı)", (("ml", "1 fl oz"),),
    ),
    2705386: (
        "milk_reduced_fat", "Milk, reduced fat (2%)",
        "Süt (yarım yağlı)", (("ml", "1 fl oz"),),
    ),
    2709186: (
        "orange_juice", "Orange juice, 100%, NFS",
        "Portakal suyu (%100)", (("ml", "1 fl oz (no ice)"),),
    ),
    2709320: (
        "apple_juice", "Apple juice, 100%",
        "Elma suyu (%100)", (("ml", "1 fl oz (no ice)"),),
    ),
    2710570: (
        "lemonade", "Lemonade, fruit juice drink",
        "Limonata", (("ml", "1 fl oz (no ice)"),),
    ),
    2710541: (
        "cola", "Soft drink, cola",
        "Kola (gazlı içecek)", (("ml", "1 fl oz (no ice)"),),
    ),
    # ── Süt ürünleri ────────────────────────────────────────────────
    2705418: (
        "yogurt", "Yogurt, whole milk, plain",
        "Yoğurt (tam yağlı, sade)", (("kase", "1 cup"),),
    ),
    2705714: (
        "feta_cheese", "Cheese, Feta",
        "Beyaz peynir (feta)", (("dilim", "1 wedge (1.33 oz)"),),
    ),
    2705709: (
        "cheddar_cheese", "Cheese, Cheddar",
        "Kaşar benzeri peynir (cheddar)", (("dilim", "1 slice"),),
    ),
    2705747: (
        "cottage_cheese", "Cheese, cottage, NFS",
        "Lor peyniri (cottage)", (("kase", "1 cup"),),
    ),
    2710154: (
        "butter", "Butter, NFS",
        "Tereyağı", (),
    ),
    2705629: (
        "ice_cream", "Ice cream, NFS",
        "Dondurma", (("kase", "1 cup"),),
    ),
    # ── Ekmek ve unlu mamul ─────────────────────────────────────────
    2707598: (
        "bread", "Bread, white",
        "Ekmek (beyaz)", (("dilim", "1 medium or regular slice"),),
    ),
    2707709: (
        "whole_wheat_bread", "Bread, whole wheat",
        "Tam buğday ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707684: (
        "bagel", "Bagel",
        "Halka ekmek (bagel)", (("adet", "1 regular"),),
    ),
    2708726: (
        "cheese_pastry", "Pastry, cheese-filled",
        "Peynirli börek benzeri hamur işi", (("adet", "1 pastry"),),
    ),
    2708044: (
        "baklava", "Baklava",
        "Baklava (genel tarif)", (("adet", "1 piece"),),
    ),
    # ── Tahıl ve bakliyat ───────────────────────────────────────────
    2708403: (
        "rice", "Rice, white, cooked, NS as to fat",
        "Pilav (beyaz pirinç)", (("kase", "1 cup, cooked"),),
    ),
    2708409: (
        "brown_rice", "Rice, brown, cooked, NS as to fat",
        "Esmer pirinç pilavı", (("kase", "1 cup, cooked"),),
    ),
    2708357: (
        "pasta", "Pasta, cooked",
        "Makarna (haşlanmış)", (("kase", "1 cup, cooked"),),
    ),
    2708441: (
        "couscous", "Couscous, plain, cooked",
        "Kuskus (sade)", (("kase", "1 cup, cooked"),),
    ),
    2708438: (
        "bulgur", "Bulgur, no added fat",
        "Bulgur (yağ eklenmemiş)", (("kase", "1 cup, cooked"),),
    ),
    2707414: (
        "chickpeas", "Chickpeas, NFS",
        "Nohut", (("kase", "1 cup"),),
    ),
    2707353: (
        "white_beans", "White beans, NFS",
        "Kuru fasulye (beyaz)", (("kase", "1 cup"),),
    ),
    2707425: (
        "lentils", "Lentils, from dried, no added fat",
        "Mercimek (kuru, yağsız)", (("kase", "1 cup"),),
    ),
    2707402: (
        "hummus", "Hummus, plain",
        "Humus (sade)", (("kase", "1 individual container"),),
    ),
    # ── Et, tavuk, balık ────────────────────────────────────────────
    2705956: (
        "chicken_breast", "Chicken breast, baked, broiled, or roasted, skin not eaten, from raw",
        "Tavuk göğsü (fırında, derisiz)", (("adet", "1 medium breast"),),
    ),
    2706037: (
        "chicken_thigh", "Chicken thigh, stewed, skin eaten",
        "Tavuk but (haşlama, derili)", (("adet", "1 medium thigh"),),
    ),
    2705854: (
        "ground_beef", "Beef, ground",
        "Dana kıyma", (),
    ),
    2706467: (
        "meatballs", "Meatballs, NS as to type of meat, with sauce",
        "Köfte (soslu, et türü belirtilmemiş)", (("adet", "1 meatball with sauce"),),
    ),
    2705905: (
        "lamb", "Lamb, NS as to cut",
        "Kuzu eti (kesim belirtilmemiş)", (("dilim", "1 piece/slice, any size"),),
    ),
    2707154: (
        "egg", "Egg, whole, boiled or poached",
        "Yumurta (haşlanmış)", (("adet", "1 egg"),),
    ),
    2707205: (
        "omelette", "Egg omelet or scrambled egg, no added fat",
        "Omlet (ilave yağsız)", (),
    ),
    2706224: (
        "fish", "Fish, NFS",
        "Balık (tür belirtilmemiş)", (),
    ),
    2706360: (
        "shrimp", "Shrimp, NFS",
        "Karides", (("adet", "1 small/medium shrimp"),),
    ),
    # ── Çorba ───────────────────────────────────────────────────────
    2707462: (
        "lentil_soup", "Soup, lentil",
        "Mercimek çorbası", (("kase", "1 cup"),),
    ),
    2710113: (
        "vegetable_soup", "Soup, vegetable",
        "Sebze çorbası", (("kase", "1 cup"),),
    ),
    2709149: (
        "chicken_noodle_soup", "Soup, chicken noodle",
        "Tavuklu şehriye çorbası", (("kase", "1 cup"),),
    ),
    2709757: (
        "tomato_soup", "Soup, tomato",
        "Domates çorbası", (("kase", "1 cup"),),
    ),
    # ── Sebze ───────────────────────────────────────────────────────
    2709719: (
        "tomato", "Tomatoes, raw",
        "Domates (çiğ)", (("adet", "1 whole"),),
    ),
    2709784: (
        "cucumber", "Cucumber, raw",
        "Salatalık (çiğ)", (("adet", "1 regular"),),
    ),
    2709785: (
        "eggplant", "Eggplant, raw",
        "Patlıcan (çiğ)", (("adet", "1 whole"),),
    ),
    2709800: (
        "green_pepper", "Peppers, sweet, green, raw",
        "Yeşil biber (çiğ)", (("adet", "1 regular"),),
    ),
    2709795: (
        "onion", "Onions, raw",
        "Soğan (çiğ)", (("adet", "1 whole"),),
    ),
    2709660: (
        "carrot", "Carrots, raw",
        "Havuç (çiğ)", (("adet", "1 regular carrot"),),
    ),
    2709789: (
        "lettuce", "Lettuce, raw",
        "Marul (çiğ)", (("kase", "1 cup"),),
    ),
    2709385: (
        "boiled_potato", "Potato, boiled, NFS",
        "Haşlanmış patates", (("adet", "1 medium"),),
    ),
    2709458: (
        "french_fries", "Potato, french fries, from fresh, fried",
        "Patates kızartması (taze patatesten)", (),
    ),
    2710089: (
        "green_olives", "Olives, green",
        "Yeşil zeytin", (("adet", "1 olive"),),
    ),
    # ── Meyve ───────────────────────────────────────────────────────
    2709215: (
        "apple", "Apple, raw",
        "Elma (çiğ)", (("adet", "1 medium"),),
    ),
    2709224: (
        "banana", "Banana, raw",
        "Muz (çiğ)", (("adet", "1 banana"),),
    ),
    2709171: (
        "orange", "Orange, raw",
        "Portakal (çiğ)", (("adet", "1 fruit"),),
    ),
    2709270: (
        "watermelon", "Watermelon, raw",
        "Karpuz (çiğ)", (("dilim", "1 medium wedge/slice"),),
    ),
    2709237: (
        "grapes", "Grapes, raw",
        "Üzüm (çiğ)", (("kase", "1 cup"),),
    ),
    2709283: (
        "strawberry", "Strawberries, raw",
        "Çilek (çiğ)", (("kase", "1 cup"),),
    ),
    2709231: (
        "cherry", "Cherries, raw",
        "Kiraz (çiğ)", (("kase", "1 cup"),),
    ),
    2709235: (
        "fig", "Fig, raw",
        "İncir (çiğ)", (("adet", "1 fig"),),
    ),
    2709221: (
        "apricot", "Apricot, raw",
        "Kayısı (çiğ)", (("adet", "1 apricot"),),
    ),
    2709212: (
        "raisins", "Raisins",
        "Kuru üzüm", (("kase", "1 cup"),),
    ),
    # ── Kuruyemiş ───────────────────────────────────────────────────
    2707531: (
        "walnuts", "Walnuts, excluding honey roasted",
        "Ceviz (bal kaplamasız)", (("adet", "1 nut"),),
    ),
    2707502: (
        "hazelnuts", "Hazelnuts",
        "Fındık", (("adet", "1 nut"),),
    ),
    2707485: (
        "almonds", "Almonds, NFS",
        "Badem", (("adet", "1 nut"),),
    ),
    2707527: (
        "pistachios", "Pistachio nuts, NFS",
        "Antep fıstığı", (("adet", "1 nut"),),
    ),
    # ── Katkı ve tatlı ──────────────────────────────────────────────
    2710186: (
        "olive_oil", "Olive oil",
        "Zeytinyağı", (),
    ),
    2710281: (
        "honey", "Honey",
        "Bal", (),
    ),
    2710301: (
        "jam", "Jam",
        "Reçel", (),
    ),
    # ── Hazır yemek ─────────────────────────────────────────────────
    2706920: (
        "hamburger", "Hamburger, NFS",
        "Hamburger (genel tarif)", (("adet", "1 hamburger"),),
    ),
    2708614: (
        "pizza", "Pizza, cheese, from restaurant or fast food, NS as to type of crust",
        "Pizza (peynirli, restoran tipi)", (("dilim", "1 piece, large pizza"),),
    ),
    # ── Model sınıfları ─────────────────────────────────────────────
    2709766: (
        "artichoke", "Artichoke",
        "Enginar", (("adet", "1 whole"),),
    ),
    2706232: (
        "anchovy", "Fish, anchovy",
        "Hamsi", (),
    ),
    2708404: (
        "rice_with_oil", "Rice, white, cooked, made with oil",
        "Pirinç pilavı (yağlı)", (("kase", "1 cup, cooked"),),
    ),
    2709073: (
        "stuffed_pepper", "Stuffed pepper, with rice and meat",
        "Biber dolması (pirinçli, etli)", (("kase", "1 cup"),),
    ),
    2709064: (
        "stuffed_grape_leaves", "Grape leaves stuffed with rice",
        "Yaprak sarma (pirinçli)", (("adet", "1 roll"),),
    ),
    2706730: (
        "shish_kebab", "Beef shish kabob with vegetables, excluding potatoes",
        "Şiş kebap (sebzeli, dana)", (("adet", "1 shishkabob"),),
    ),
    2710144: (
        "eggplant_meat_casserole", "Eggplant and meat casserole",
        "Patlıcanlı et yemeği (karnıyarık benzeri)", (("kase", "1 cup"),),
    ),
    2705849: (
        "beef_stew_meat", "Beef, stew meat",
        "Et sote için dana eti (haşlama)", (),
    ),
    2709131: (
        "tabbouleh", "Tabbouleh",
        "Kısır benzeri bulgur salatası (tabbouleh)", (("kase", "1 cup"),),
    ),
    2708708: (
        "steamed_dumpling", "Wonton, dumpling or pot sticker, steamed",
        "Buharda mantı benzeri hamur (etli)", (("adet", "1 item, any size"),),
    ),
    2710359: (
        "gummy_candy", "Candy, gummy",
        "Lokum benzeri jel şeker", (("adet", "1 piece"),),
    ),
    2710791: (
        "cooked_spinach", "Spinach, cooked, as ingredient",
        "Ispanak (pişmiş, sade)", (),
    ),
    2710803: (
        "cooked_green_beans", "Green beans, cooked, as ingredient",
        "Taze fasulye (pişmiş, sade)", (),
    ),
    2708024: (
        "fritter", "Fritter, plain",
        "Mücver benzeri kızartma (sade fritter)", (("adet", "1 fritter"),),
    ),
    # ── Meyve (ek) ──────────────────────────────────────────────────
    2709168: (
        "lemon", "Lemon, raw",
        "Limon (çiğ)", (("adet", "1 fruit"),),
    ),
    2709265: (
        "plum", "Plum, raw",
        "Erik (çiğ)", (("adet", "1 fruit"),),
    ),
    2709249: (
        "peach", "Peach, raw",
        "Şeftali (çiğ)", (("adet", "1 fruit"),),
    ),
    2709254: (
        "pear", "Pear, raw",
        "Armut (çiğ)", (("adet", "1 fruit"),),
    ),
    2709260: (
        "pineapple", "Pineapple, raw",
        "Ananas (çiğ)", (("kase", "1 cup"),),
    ),
    2709267: (
        "pomegranate", "Pomegranate, raw",
        "Nar (çiğ)", (("adet", "1 fruit"),),
    ),
    2709226: (
        "cantaloupe", "Cantaloupe, raw",
        "Kavun (çiğ)", (("kase", "1 cup"),),
    ),
    2709175: (
        "tangerine", "Tangerine, raw",
        "Mandalina (çiğ)", (("adet", "1 fruit"),),
    ),
    2709239: (
        "kiwi", "Kiwi fruit, raw",
        "Kivi (çiğ)", (("adet", "1 fruit"),),
    ),
    2709223: (
        "avocado", "Avocado, raw",
        "Avokado (çiğ)", (("adet", "1 fruit"),),
    ),
    2709275: (
        "blueberries", "Blueberries, raw",
        "Yaban mersini (çiğ)", (("kase", "1 cup"),),
    ),
    2709281: (
        "raspberries", "Raspberries, raw",
        "Ahududu (çiğ)", (("kase", "1 cup"),),
    ),
    2709203: (
        "date_fruit", "Date",
        "Hurma", (("adet", "1 date"),),
    ),
    2709204: (
        "dried_fig", "Fig, dried",
        "Kuru incir", (("adet", "1 fig"),),
    ),
    2709197: (
        "dried_apricot", "Apricot, dried",
        "Kuru kayısı", (),
    ),
    # ── Sebze (ek) ──────────────────────────────────────────────────
    2709775: (
        "cabbage", "Cabbage, red, raw",
        "Kırmızı lahana (çiğ)", (("kase", "1 cup"),),
    ),
    2709777: (
        "cauliflower", "Cauliflower, raw",
        "Karnabahar (çiğ)", (("kase", "1 cup"),),
    ),
    2709643: (
        "broccoli", "Broccoli, raw",
        "Brokoli (çiğ)", (("kase", "1 cup"),),
    ),
    2709793: (
        "mushrooms", "Mushrooms, raw",
        "Mantar (çiğ)", (("kase", "1 cup"),),
    ),
    2709803: (
        "radish", "Radish",
        "Turp", (("adet", "1 whole"),),
    ),
    2709778: (
        "celery", "Celery, raw",
        "Kereviz sapı (çiğ)", (("kase", "1 cup"),),
    ),
    2709770: (
        "beet", "Beets, raw",
        "Pancar (çiğ)", (("kase", "1 cup"),),
    ),
    2709599: (
        "kale", "Kale, raw",
        "Kara lahana (çiğ)", (("kase", "1 cup"),),
    ),
    2709574: (
        "chard", "Chard, raw",
        "Pazı (çiğ)", (("kase", "1 cup"),),
    ),
    2709697: (
        "sweet_potato", "Sweet potato, NFS",
        "Tatlı patates", (("adet", "1 medium"),),
    ),
    2709783: (
        "corn_cooked", "Corn, raw",
        "Mısır (çiğ)", (("kase", "1 cup"),),
    ),
    2709687: (
        "peas_cooked", "Peas and carrots, cooked, NS as to form",
        "Bezelye ve havuç (pişmiş)", (("kase", "1 cup"),),
    ),
    2710090: (
        "black_olives", "Olives, black",
        "Siyah zeytin", (("adet", "1 olive"),),
    ),
    2710097: (
        "pickles", "Pickles, NFS",
        "Turşu", (("adet", "1 regular"),),
    ),
    # ── Et, tavuk, balık (ek) ───────────────────────────────────────
    2705822: (
        "beef", "Beef, NFS",
        "Dana eti (kesim belirtilmemiş)", (),
    ),
    2705909: (
        "veal", "Veal, chop",
        "Dana pirzola", (),
    ),
    2705908: (
        "goat", "Goat",
        "Keçi eti", (),
    ),
    2706104: (
        "turkey", "Turkey, NFS",
        "Hindi eti", (),
    ),
    2706061: (
        "chicken_wing", "Chicken wing, stewed",
        "Tavuk kanat (haşlama)", (),
    ),
    2706153: (
        "liver", "Liver, beef",
        "Dana ciğeri", (),
    ),
    2706195: (
        "salami", "Salami, NFS",
        "Salam", (("dilim", "1 slice, NFS"),),
    ),
    2706309: (
        "tuna", "Fish, tuna, NFS",
        "Ton balığı", (),
    ),
    2706285: (
        "salmon", "Fish, salmon, NFS",
        "Somon", (),
    ),
    2706293: (
        "sardines", "Fish, sardines, canned",
        "Sardalya (konserve)", (),
    ),
    2706350: (
        "mussels", "Mussels",
        "Midye", (("adet", "1 mussel"),),
    ),
    2706331: (
        "squid", "Octopus",
        "Ahtapot", (),
    ),
    2706344: (
        "crab", "Crab",
        "Yengeç", (),
    ),
    # ── Süt ürünleri (ek) ───────────────────────────────────────────
    2705393: (
        "buttermilk", "Buttermilk",
        "Yayık ayranı (buttermilk)", (("ml", "1 fl oz"),),
    ),
    2705394: (
        "kefir", "Kefir",
        "Kefir", (("ml", "1 fl oz"),),
    ),
    2705395: (
        "goat_milk", "Goat milk",
        "Keçi sütü", (("ml", "1 fl oz"),),
    ),
    2705422: (
        "greek_yogurt", "Yogurt, Greek, whole milk, plain",
        "Süzme yoğurt (tam yağlı)", (("kase", "1 cup"),),
    ),
    2705597: (
        "cream", "Cream, heavy",
        "Krema (kaymak)", (),
    ),
    2705722: (
        "mozzarella", "Cheese, Mozzarella, NFS",
        "Mozzarella peyniri", (("dilim", "1 slice"),),
    ),
    2705730: (
        "parmesan", "Cheese, Parmesan, hard",
        "Parmesan peyniri (sert)", (),
    ),
    2705412: (
        "oat_milk", "Oat milk",
        "Yulaf sütü", (("ml", "1 fl oz"),),
    ),
    # ── Ekmek ve tahıl (ek) ─────────────────────────────────────────
    2707755: (
        "rye_bread", "Bread, rye",
        "Çavdar ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707810: (
        "cornbread", "Cornbread, prepared from mix",
        "Mısır ekmeği (hazır karışım)", (("dilim", "1 piece"),),
    ),
    2707678: (
        "croissant", "Croissant",
        "Kruvasan", (("adet", "1 medium croissant"),),
    ),
    2708132: (
        "crackers", "Crackers, NFS",
        "Kraker", (),
    ),
    2708380: (
        "oatmeal", "Oatmeal, NFS",
        "Yulaf ezmesi (pişmiş)", (("kase", "1 cup, cooked"),),
    ),
    2708361: (
        "barley", "Barley",
        "Arpa (pişmiş)", (("kase", "1 cup, cooked"),),
    ),
    2708377: (
        "millet", "Millet",
        "Darı (pişmiş)", (("kase", "1 cup, cooked"),),
    ),
    2708352: (
        "noodles", "Noodles, cooked",
        "Erişte (haşlanmış)", (("kase", "1 cup, cooked"),),
    ),
    2708453: (
        "corn_flakes", "Cereal, corn flakes, plain",
        "Mısır gevreği", (("kase", "1 cup"),),
    ),
    2708162: (
        "rice_cake", "Rice cake",
        "Pirinç patlağı", (("adet", "1 cake"),),
    ),
    2708215: (
        "pita_chips", "Pita chips",
        "Pide cipsi", (),
    ),
    # ── Kuruyemiş ve tohum (ek) ─────────────────────────────────────
    2707499: (
        "chestnuts", "Chestnuts",
        "Kestane", (("adet", "1 nut"),),
    ),
    2707526: (
        "pine_nuts", "Pine nuts",
        "Çam fıstığı", (),
    ),
    2707587: (
        "tahini", "Tahini",
        "Tahin", (),
    ),
    2707585: (
        "sunflower_seeds", "Sunflower seeds, NFS",
        "Ay çekirdeği", (),
    ),
    2707579: (
        "pumpkin_seeds", "Pumpkin seeds, NFS",
        "Kabak çekirdeği", (),
    ),
    2707512: (
        "peanuts", "Peanuts, NFS",
        "Yer fıstığı", (),
    ),
    2707493: (
        "cashews", "Cashews, NFS",
        "Kaju", (),
    ),
    2707590: (
        "chia_seeds", "Chia seeds",
        "Chia tohumu", (),
    ),
    2707588: (
        "flax_seeds", "Flax seeds",
        "Keten tohumu", (),
    ),
    # ── Tatlı ve atıştırmalık (ek) ──────────────────────────────────
    2710328: (
        "chocolate", "Chocolate candy",
        "Çikolata", (),
    ),
    2707899: (
        "cookie", "Cookie, NFS",
        "Bisküvi", (("adet", "1 medium"),),
    ),
    2707882: (
        "cake_plain", "Cake, pound",
        "Kek (yağlı hamur)", (("dilim", "1 piece/slice, any size"),),
    ),
    2705685: (
        "rice_pudding", "Pudding, rice",
        "Sütlaç benzeri pirinç muhallebisi", (("kase", "1 cup"),),
    ),
    2708216: (
        "popcorn", "Popcorn, NFS",
        "Patlamış mısır", (),
    ),
    2709421: (
        "potato_chips", "Potato chips, NFS",
        "Patates cipsi", (),
    ),
    2708062: (
        "doughnut", "Doughnut, NFS",
        "Donut", (("adet", "1 doughnut"),),
    ),
    2708312: (
        "waffle", "Waffle, NFS",
        "Waffle", (("adet", "1 medium waffle"),),
    ),
    2708294: (
        "pancake", "Pancakes, NFS",
        "Krep/pankek", (),
    ),
    # ── Yağ ve sos (ek) ─────────────────────────────────────────────
    2710183: (
        "corn_oil", "Corn oil",
        "Mısır yağı", (),
    ),
    2710192: (
        "sunflower_oil", "Sunflower oil",
        "Ayçiçek yağı", (),
    ),
    2710204: (
        "mayonnaise", "Mayonnaise, regular",
        "Mayonez", (),
    ),
    2709733: (
        "ketchup", "Ketchup",
        "Ketçap", (),
    ),
    2710085: (
        "mustard", "Mustard",
        "Hardal", (),
    ),
    2710247: (
        "tomato_sauce", "Tomato sauce, for use with vegetables",
        "Domates sosu", (),
    ),
    # ── Son grup ────────────────────────────────────────────────────
    2710300: (
        "jelly", "Jelly",
        "Jöle reçeli", (),
    ),
    2706171: (
        "beef_sausage", "Beef sausage",
        "Dana sucuk benzeri sosis", (("dilim", "1 slice"),),
    ),
    2706183: (
        "pastrami", "Pastrami, NFS",
        "Pastırma benzeri (pastrami)", (("dilim", "1 slice, NFS"),),
    ),
    2707423: (
        "lentils_nfs", "Lentils, NFS",
        "Yeşil mercimek", (("kase", "1 cup"),),
    ),
    2707420: (
        "split_peas", "Split peas, from dried, no added fat",
        "Kuru bezelye", (("kase", "1 cup"),),
    ),
    2708700: (
        "egg_roll", "Egg roll, meatless",
        "Sigara böreği benzeri rulo (etsiz)", (("adet", "1 egg roll"),),
    ),
    2707156: (
        "fried_egg", "Egg, whole, fried no added fat",
        "Yumurta (yağsız kızartma)", (("adet", "1 egg"),),
    ),
    2709773: (
        "green_cabbage", "Cabbage, green, raw",
        "Beyaz lahana (çiğ)", (("kase", "1 cup"),),
    ),
    2709614: (
        "raw_spinach", "Spinach, raw",
        "Ispanak (çiğ)", (("kase", "1 cup"),),
    ),
    2709590: (
        "romaine", "Romaine lettuce, raw",
        "Kıvırcık marul (çiğ)", (("kase", "1 cup"),),
    ),
    2709801: (
        "red_pepper", "Peppers, sweet, red, raw",
        "Kırmızı biber (çiğ)", (("adet", "1 regular"),),
    ),
    2709786: (
        "garlic", "Garlic, raw",
        "Sarımsak (çiğ)", (("adet", "1 clove"),),
    ),
    2709796: (
        "parsley", "Parsley, raw",
        "Maydanoz (çiğ)", (("kase", "1 cup"),),
    ),
    2709180: (
        "lemon_juice", "Lemon juice, 100%, NS as to form",
        "Limon suyu", (("ml", "1 fl oz (no ice)"),),
    ),
    2708439: (
        "bulgur_with_fat", "Bulgur, fat added",
        "Bulgur pilavı (yağlı)", (("kase", "1 cup, cooked"),),
    ),
    2709165: (
        "grapefruit", "Grapefruit, raw",
        "Greyfurt (çiğ)", (("adet", "1 fruit"),),
    ),
    2709692: (
        "pumpkin", "Pumpkin, cooked",
        "Balkabağı (pişmiş)", (("kase", "1 cup"),),
    ),
    # ── Parti A ─────────────────────────────────────────────────────
    2709809: (
        "turnip", "Turnip, raw",
        "Şalgam (çiğ)", (("kase", "1 cup"),),
    ),
    2709788: (
        "kohlrabi", "Kohlrabi, raw",
        "Alabaş (çiğ)", (("kase", "1 cup"),),
    ),
    2709804: (
        "rutabaga", "Rutabaga, raw",
        "İsveç şalgamı (çiğ)", (("kase", "1 cup"),),
    ),
    2709806: (
        "snowpeas", "Snowpeas, raw",
        "Şeker bezelye (çiğ)", (("kase", "1 cup"),),
    ),
    2709764: (
        "sprouts", "Sprouts, NFS",
        "Filiz", (("kase", "1 cup"),),
    ),
    2709805: (
        "seaweed", "Seaweed, raw",
        "Deniz yosunu (çiğ)", (("kase", "1 cup"),),
    ),
    2709787: (
        "jicama", "Jicama, raw",
        "Yer elması (jikama)", (("kase", "1 cup"),),
    ),
    2709776: (
        "cactus", "Cactus, raw",
        "Kaktüs yaprağı (çiğ)", (("kase", "1 cup"),),
    ),
    2709767: (
        "asparagus", "Asparagus, raw",
        "Kuşkonmaz (çiğ)", (("kase", "1 cup"),),
    ),
    2709772: (
        "brussels_sprouts", "Brussels sprouts, raw",
        "Brüksel lahanası (çiğ)", (("kase", "1 cup"),),
    ),
    2709935: (
        "leek", "Leeks",
        "Pırasa (çiğ)", (("kase", "1 cup"),),
    ),
    2706262: (
        "pickled_fish", "Fish, pickled",
        "Balık turşusu", (),
    ),
    2707368: (
        "lima_beans", "Lima beans, NFS",
        "Bakla (lima fasulyesi)", (("kase", "1 cup"),),
    ),
    2707390: (
        "baked_beans", "Baked beans",
        "Fırın fasulye", (("kase", "1 cup"),),
    ),
    2707396: (
        "refried_beans", "Refried beans",
        "Ezme fasulye", (("kase", "1 cup"),),
    ),
    2707347: (
        "beans_nfs", "Beans, NFS",
        "Fasulye (tür belirtilmemiş)", (("kase", "1 cup"),),
    ),
    2707427: (
        "dal", "Dal",
        "Mercimek yemeği (dal)", (("kase", "1 cup"),),
    ),
    2709242: (
        "mango", "Mango, raw",
        "Mango (çiğ)", (("adet", "1 mango"),),
    ),
    2709246: (
        "papaya", "Papaya, raw",
        "Papaya (çiğ)", (("kase", "1 cup"),),
    ),
    2709238: (
        "guava", "Guava, raw",
        "Guava (çiğ)", (("adet", "1 fruit"),),
    ),
    2709240: (
        "lychee", "Lychee",
        "Liçi", (("adet", "1 lychee"),),
    ),
    2709268: (
        "rhubarb", "Rhubarb",
        "Ravent", (("kase", "1 cup"),),
    ),
    2709269: (
        "tamarind", "Tamarind",
        "Demirhindi", (("adet", "1 tamarind"),),
    ),
    2709273: (
        "blackberries", "Blackberries, raw",
        "Böğürtlen (çiğ)", (("kase", "1 cup"),),
    ),
    2709285: (
        "strawberries_frozen", "Strawberries, frozen",
        "Çilek (dondurulmuş)", (("kase", "1 cup"),),
    ),
    2709211: (
        "prunes", "Prune, dried",
        "Kuru erik", (("adet", "1 prune"),),
    ),
    2709202: (
        "dried_cranberries", "Cranberries, dried",
        "Kuru kızılcık", (("kase", "1 cup"),),
    ),
    2706229: (
        "fish_canned", "Fish, canned",
        "Balık (konserve)", (),
    ),
    2706231: (
        "fish_stick", "Fish, stick",
        "Balık kroketi", (("adet", "1 stick"),),
    ),
    2706233: (
        "fish_carp", "Fish, carp",
        "Sazan", (),
    ),
    2706247: (
        "fish_eel", "Fish, eel",
        "Yılan balığı", (),
    ),
    2706332: (
        "caviar", "Caviar",
        "Havyar", (),
    ),
    2706349: (
        "lobster", "Lobster",
        "Istakoz", (),
    ),
    2706339: (
        "clams", "Clams, NFS",
        "Deniz tarağı", (),
    ),
    2706337: (
        "abalone", "Abalone",
        "Deniz kulağı", (),
    ),
    2706463: (
        "ceviche", "Ceviche",
        "Ceviche (marine balık)", (("kase", "1 cup"),),
    ),
    2706460: (
        "fish_curry", "Fish curry",
        "Balık körisi", (("kase", "1 cup"),),
    ),
    2706549: (
        "crab_cake", "Crab, cake",
        "Yengeç köftesi", (("adet", "1 cake or patty"),),
    ),
    2705704: (
        "cheese_nfs", "Cheese, NFS",
        "Peynir (tür belirtilmemiş)", (("dilim", "1 slice"),),
    ),
    2705716: (
        "cheese_goat", "Cheese, goat",
        "Keçi peyniri", (),
    ),
    2705708: (
        "cheese_brie", "Cheese, Brie",
        "Brie peyniri", (),
    ),
    2705712: (
        "cheese_colby", "Cheese, Colby",
        "Colby peyniri", (("dilim", "1 slice"),),
    ),
    2705745: (
        "queso_fresco", "Queso Fresco",
        "Taze beyaz peynir (queso fresco)", (),
    ),
    2705781: (
        "cheese_ball", "Cheese ball",
        "Peynir topu", (),
    ),
    2705451: (
        "frozen_yogurt", "Frozen yogurt, NFS",
        "Donmuş yoğurt", (("kase", "1 cup"),),
    ),
    2705636: (
        "gelato", "Gelato, vanilla",
        "Gelato (vanilyalı)", (("kase", "1 cup"),),
    ),
    2707613: (
        "naan", "Bread, naan",
        "Naan ekmeği", (),
    ),
    2707616: (
        "pita_bread", "Bread, pita",
        "Pide ekmeği (pita)", (),
    ),
    2707633: (
        "onion_bread", "Bread, onion",
        "Soğanlı ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707764: (
        "black_bread", "Bread, black",
        "Siyah ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707794: (
        "rice_bread", "Bread, rice",
        "Pirinç unlu ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707801: (
        "biscuit", "Biscuit, NFS",
        "Bisküvi ekmeği (biscuit)", (("adet", "1 biscuit"),),
    ),
    2707829: (
        "muffin", "Muffin, NFS",
        "Muffin", (("adet", "1 medium"),),
    ),
    2707808: (
        "scone", "Scone",
        "Çörek (scone)", (("adet", "1 regular"),),
    ),
    2707682: (
        "brioche", "Brioche",
        "Brioche çöreği", (("adet", "1 piece"),),
    ),
    2708070: (
        "churros", "Churros",
        "Churros", (("adet", "1 regular"),),
    ),
    2708071: (
        "beignet", "Beignet",
        "Beignet hamur tatlısı", (("adet", "1 beignet"),),
    ),
    2708053: (
        "puff_pastry", "Pastry, puff",
        "Milföy hamuru", (),
    ),
    2707702: (
        "melba_toast", "Melba toast",
        "Melba tost", (),
    ),
    2707697: (
        "croutons", "Croutons",
        "Kruton", (),
    ),
    2708163: (
        "rice_crackers", "Crackers, rice",
        "Pirinç krakeri", (),
    ),
    2709144: (
        "soup_nfs", "Soup, NFS",
        "Çorba (tür belirtilmemiş)", (("kase", "1 cup"),),
    ),
    2707453: (
        "bean_soup", "Soup, bean",
        "Fasulye çorbası", (("kase", "1 cup"),),
    ),
    2709146: (
        "rice_soup", "Soup, rice",
        "Pirinç çorbası", (("kase", "1 cup"),),
    ),
    2710115: (
        "beef_soup", "Soup, beef",
        "Et çorbası", (("kase", "1 cup"),),
    ),
    2707132: (
        "broth", "Soup, broth",
        "Et suyu", (("kase", "1 cup"),),
    ),
    2709147: (
        "barley_soup", "Soup, barley",
        "Arpa çorbası", (("kase", "1 cup"),),
    ),
    2706721: (
        "stew_nfs", "Stew, NFS",
        "Yahni (tür belirtilmemiş)", (("kase", "1 cup"),),
    ),
    2706592: (
        "beef_stew", "Stew, beef",
        "Dana yahnisi", (("kase", "1 cup"),),
    ),
    2706660: (
        "lamb_stew", "Stew, lamb",
        "Kuzu yahnisi", (("kase", "1 cup"),),
    ),
    2706466: (
        "fish_stew", "Stew, fish",
        "Balık yahnisi", (("kase", "1 cup"),),
    ),
    2706373: (
        "chili", "Chili, NFS",
        "Acılı fasulyeli et (chili)", (("kase", "1 cup"),),
    ),
    2706388: (
        "beef_curry", "Beef curry",
        "Dana köri", (("kase", "1 cup"),),
    ),
    2710188: (
        "canola_oil", "Canola oil",
        "Kanola yağı", (),
    ),
    2710187: (
        "peanut_oil", "Peanut oil",
        "Yer fıstığı yağı", (),
    ),
    2710190: (
        "sesame_oil", "Sesame oil",
        "Susam yağı", (),
    ),
    2710182: (
        "coconut_oil", "Coconut oil",
        "Hindistan cevizi yağı", (),
    ),
    2710191: (
        "soybean_oil", "Soybean oil",
        "Soya yağı", (),
    ),
    2710193: (
        "walnut_oil", "Walnut oil",
        "Ceviz yağı", (),
    ),
    2707484: (
        "nuts_nfs", "Nuts, NFS",
        "Kuruyemiş (tür belirtilmemiş)", (),
    ),
    2707492: (
        "brazil_nuts", "Brazil nuts",
        "Brezilya cevizi", (),
    ),
    2707521: (
        "pecans", "Pecans, NFS",
        "Pekan cevizi", (),
    ),
    2707586: (
        "sesame_seeds", "Sesame seeds",
        "Susam", (),
    ),
    2707589: (
        "mixed_seeds", "Mixed seeds",
        "Karışık tohum", (),
    ),
    2707533: (
        "almond_butter", "Almond butter",
        "Badem ezmesi", (),
    ),
    2707536: (
        "cashew_butter", "Cashew butter",
        "Kaju ezmesi", (),
    ),
    2707535: (
        "almond_paste", "Almond paste",
        "Badem ezmesi (şekerli)", (),
    ),
    2707433: (
        "soy_nuts", "Soy nuts",
        "Kavrulmuş soya", (),
    ),
    2705702: (
        "tiramisu", "Tiramisu",
        "Tiramisu", (("dilim", "1 piece"),),
    ),
    2708045: (
        "basbousa", "Basbousa",
        "Revani benzeri irmik tatlısı (basbousa)", (("dilim", "1 piece"),),
    ),
    2707995: (
        "apple_pie", "Pie, apple",
        "Elmalı turta", (),
    ),
    2708000: (
        "lemon_pie", "Pie, lemon",
        "Limonlu turta", (),
    ),
    2710303: (
        "marmalade", "Marmalade",
        "Marmelat", (),
    ),
    2710274: (
        "corn_syrup", "Corn syrup",
        "Mısır şurubu", (),
    ),
    2710291: (
        "white_icing", "Icing, white",
        "Beyaz krema (glaze)", (),
    ),
    2707971: (
        "marie_biscuit", "Marie biscuit",
        "Marie bisküvi", (("adet", "1 cookie"),),
    ),
    2707927: (
        "coconut_cookie", "Cookie, coconut",
        "Hindistan cevizli kurabiye", (("adet", "1 medium"),),
    ),
    2707960: (
        "raisin_cookie", "Cookie, raisin",
        "Üzümlü kurabiye", (("adet", "1 medium"),),
    ),
    2705660: (
        "banana_split", "Banana split",
        "Muzlu dondurma (banana split)", (("adet", "1 banana split"),),
    ),
    2710378: (
        "espresso", "Coffee, espresso",
        "Espresso", (("ml", "1 fl oz"),),
    ),
    2710386: (
        "latte", "Coffee, Latte",
        "Latte", (("ml", "1 fl oz"),),
    ),
    2710487: (
        "chicory", "Chicory beverage",
        "Hindiba içeceği", (("ml", "1 fl oz"),),
    ),
    2709341: (
        "apricot_nectar", "Apricot nectar",
        "Kayısı nektarı", (("ml", "1 fl oz (no ice)"),),
    ),
    2709346: (
        "peach_nectar", "Peach nectar",
        "Şeftali nektarı", (("ml", "1 fl oz (no ice)"),),
    ),
    2709349: (
        "pear_nectar", "Pear nectar",
        "Armut nektarı", (("ml", "1 fl oz (no ice)"),),
    ),
    2709345: (
        "mango_nectar", "Mango nectar",
        "Mango nektarı", (("ml", "1 fl oz (no ice)"),),
    ),
    2710568: (
        "tamarind_drink", "Tamarind drink",
        "Demirhindi şerbeti", (("ml", "1 fl oz (no ice)"),),
    ),
    2705706: (
        "cheese_brick", "Cheese, Brick",
        "Brick peyniri", (("dilim", "1 slice"),),
    ),
    2705735: (
        "cheese_swiss", "Cheese, Swiss",
        "İsviçre peyniri", (("dilim", "1 slice"),),
    ),
    2705740: (
        "cheese_paneer", "Cheese, paneer",
        "Paneer peyniri", (),
    ),
    2705715: (
        "cheese_fontina", "Cheese, Fontina",
        "Fontina peyniri", (),
    ),
    2705718: (
        "cheese_gruyere", "Cheese, Gruyere",
        "Gruyere peyniri", (),
    ),
    2705750: (
        "cheese_ricotta", "Cheese, Ricotta",
        "Ricotta peyniri", (("kase", "1 cup"),),
    ),
    2705720: (
        "cheese_monterey", "Cheese, Monterey",
        "Monterey peyniri", (("dilim", "1 slice"),),
    ),
    2705726: (
        "cheese_muenster", "Cheese, Muenster",
        "Muenster peyniri", (("dilim", "1 slice"),),
    ),
    2705764: (
        "cheese_american", "Cheese, American",
        "Amerikan peyniri", (("dilim", "1 slice"),),
    ),
    2705707: (
        "cheese_camembert", "Cheese, Camembert",
        "Camembert peyniri", (),
    ),
    2705733: (
        "cheese_provolone", "Cheese, Provolone",
        "Provolone peyniri", (("dilim", "1 slice"),),
    ),
    2705713: (
        "cheese_colby_jack", "Cheese, Colby Jack",
        "Colby Jack peyniri", (("dilim", "1 slice"),),
    ),
    2705746: (
        "queso_cotija", "Queso cotija",
        "Cotija peyniri", (),
    ),
    2706276: (
        "fish_pike", "Fish, pike",
        "Turna balığı", (),
    ),
    2706300: (
        "fish_shark", "Fish, shark",
        "Köpek balığı", (),
    ),
    2706230: (
        "fish_smoked", "Fish, smoked",
        "Füme balık", (),
    ),
    2706269: (
        "fish_mullet", "Fish, mullet",
        "Kefal", (),
    ),
    2706260: (
        "fish_halibut", "Fish, halibut",
        "Halibut", (),
    ),
    2706261: (
        "fish_herring", "Fish, herring",
        "Ringa", (),
    ),
    2706283: (
        "fish_snapper", "Fish, snapper",
        "Mercan balığı", (),
    ),
    2706240: (
        "fish_cod", "Fish, cod, NFS",
        "Morina", (),
    ),
    2706294: (
        "fish_bass", "Fish, bass, NFS",
        "Levrek", (),
    ),
    2706301: (
        "fish_swordfish", "Fish, swordfish",
        "Kılıç balığı", (),
    ),
    2706246: (
        "fish_croaker", "Fish, croaker",
        "Kötek balığı", (),
    ),
    2706223: (
        "fish_raw", "Fish, raw",
        "Balık (çiğ)", (),
    ),
    2707134: (
        "soup_chicken", "Soup, chicken",
        "Tavuk çorbası", (("kase", "1 cup"),),
    ),
    2709556: (
        "soup_potato", "Soup, potato",
        "Patates çorbası", (("kase", "1 cup"),),
    ),
    2709718: (
        "soup_pumpkin", "Soup, pumpkin",
        "Balkabağı çorbası", (("kase", "1 cup"),),
    ),
    2707140: (
        "soup_bisque", "Soup, bisque",
        "Kremalı deniz çorbası", (("kase", "1 cup"),),
    ),
    2710105: (
        "soup_borscht", "Soup, borscht",
        "Pancar çorbası", (("kase", "1 cup"),),
    ),
    2707123: (
        "soup_meatball", "Soup, meatball",
        "Köfteli çorba", (("kase", "1 cup"),),
    ),
    2707282: (
        "soup_egg_drop", "Soup, egg drop",
        "Yumurtalı çorba", (("kase", "1 cup"),),
    ),
    2710106: (
        "soup_gazpacho", "Soup, gazpacho",
        "Soğuk sebze çorbası", (("kase", "1 cup"),),
    ),
    2710110: (
        "soup_seaweed", "Soup, seaweed",
        "Deniz yosunu çorbası", (("kase", "1 cup"),),
    ),
    2709311: (
        "soup_fruit", "Soup, fruit",
        "Meyve çorbası", (("kase", "1 cup"),),
    ),
    2707547: (
        "soup_peanut", "Soup, peanut",
        "Yer fıstığı çorbası", (("kase", "1 cup"),),
    ),
    2709160: (
        "soup_wonton", "Soup, wonton",
        "Mantı çorbası (wonton)", (("kase", "1 cup"),),
    ),
    2707790: (
        "bread_soy", "Bread, soy",
        "Soya ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707848: (
        "bread_nut", "Bread, nut",
        "Cevizli ekmek", (("dilim", "1 slice"),),
    ),
    2707604: (
        "bread_cuban", "Bread, Cuban",
        "Küba ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707850: (
        "bread_fruit", "Bread, fruit",
        "Meyveli ekmek", (("dilim", "1 slice"),),
    ),
    2707618: (
        "bread_cheese", "Bread, cheese",
        "Peynirli ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707642: (
        "bread_potato", "Bread, potato",
        "Patatesli ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707644: (
        "bread_raisin", "Bread, raisin",
        "Üzümlü ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707788: (
        "bread_barley", "Bread, barley",
        "Arpa ekmeği", (("dilim", "1 medium or regular slice"),),
    ),
    2707768: (
        "bread_oatmeal", "Bread, oatmeal",
        "Yulaflı ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707849: (
        "bread_pumpkin", "Bread, pumpkin",
        "Balkabaklı ekmek", (("dilim", "1 slice"),),
    ),
    2707620: (
        "bread_cinnamon", "Bread, cinnamon",
        "Tarçınlı ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707770: (
        "bread_oat_bran", "Bread, oat bran",
        "Yulaf kepekli ekmek", (("dilim", "1 medium or regular slice"),),
    ),
    2707715: (
        "bread_paratha", "Bread, paratha",
        "Paratha ekmeği", (),
    ),
    2707714: (
        "bread_puri", "Bread, puri",
        "Puri ekmeği", (),
    ),
    2707900: (
        "cookie_almond", "Cookie, almond",
        "Bademli kurabiye", (("adet", "1 medium"),),
    ),
    2707968: (
        "cookie_animal", "Cookie, animal",
        "Hayvan bisküvisi", (),
    ),
    2707929: (
        "cookie_fig_bar", "Cookie, fig bar",
        "İncirli bar", (),
    ),
    2707930: (
        "cookie_fortune", "Cookie, fortune",
        "Fal kurabiyesi", (("adet", "1 cookie"),),
    ),
    2707933: (
        "cookie_granola", "Cookie, granola",
        "Granola kurabiyesi", (("adet", "1 medium"),),
    ),
    2707945: (
        "cookie_oatmeal", "Cookie, oatmeal",
        "Yulaflı kurabiye", (("adet", "1 medium"),),
    ),
    2707959: (
        "cookie_pumpkin", "Cookie, pumpkin",
        "Balkabaklı kurabiye", (),
    ),
    2707902: (
        "biscotti", "Cookie, biscotti",
        "Biscotti", (("adet", "1 cookie"),),
    ),
    2707936: (
        "macaroon", "Cookie, macaroon",
        "Makaron", (("adet", "1 cookie"),),
    ),
    2707941: (
        "meringue", "Cookie, meringue",
        "Beze", (("adet", "1 cookie"),),
    ),
    2707942: (
        "cookie_molasses", "Cookie, molasses",
        "Pekmezli kurabiye", (("adet", "1 medium"),),
    ),
    2707984: (
        "rugelach", "Cookie, rugelach",
        "Rugelach", (),
    ),
    2707997: (
        "pie_berry", "Pie, berry",
        "Orman meyveli turta", (),
    ),
    2708002: (
        "pie_peach", "Pie, peach",
        "Şeftalili turta", (),
    ),
    2708015: (
        "pie_pecan", "Pie, pecan",
        "Pekanlı turta", (),
    ),
    2707999: (
        "pie_cherry", "Pie, cherry",
        "Vişneli turta", (),
    ),
    2708011: (
        "pie_pumpkin", "Pie, pumpkin",
        "Balkabaklı turta", (),
    ),
    2707998: (
        "pie_blueberry", "Pie, blueberry",
        "Yaban mersinli turta", (),
    ),
    2708003: (
        "pie_strawberry", "Pie, strawberry",
        "Çilekli turta", (),
    ),
    2707872: (
        "cake_cream", "Cake, cream",
        "Kremalı pasta", (("dilim", "1 piece/slice, any size"),),
    ),
    2707886: (
        "cake_sponge", "Cake, sponge",
        "Pandispanya", (("dilim", "1 piece/slice, any size"),),
    ),
    2707888: (
        "cake_torte", "Cake, torte",
        "Torte pasta", (("dilim", "1 piece/slice, any size"),),
    ),
    2707854: (
        "cake_angel_food", "Cake, angel food",
        "Melek keki", (("dilim", "1 piece/slice, any size"),),
    ),
    2707875: (
        "cake_fruit", "Cake, fruit cake",
        "Meyveli kek", (("dilim", "1 piece/slice, any size"),),
    ),
    2707878: (
        "cake_jelly_roll", "Cake, jelly roll",
        "Rulo pasta", (("dilim", "1 piece/slice, any size"),),
    ),
    2708461: (
        "cereal_granola", "Cereal, granola",
        "Granola", (("kase", "1 cup"),),
    ),
    2708475: (
        "cereal_os", "Cereal, O's, NFS",
        "Halka gevrek", (("kase", "1 cup"),),
    ),
    2708465: (
        "cereal_multigrain", "Cereal, multigrain",
        "Çok tahıllı gevrek", (("kase", "1 cup"),),
    ),
    2708459: (
        "cereal_fruit_rings", "Cereal, fruit rings",
        "Meyveli halka gevrek", (("kase", "1 cup"),),
    ),
    2708466: (
        "cereal_oat_squares", "Cereal, oat squares",
        "Yulaf kare gevrek", (("kase", "1 cup"),),
    ),
    2708360: (
        "cereal_cooked", "Cereal, cooked, NFS",
        "Pişmiş tahıl lapası", (("kase", "1 cup, cooked"),),
    ),
    2708454: (
        "cereal_corn_puffs", "Cereal, corn puffs",
        "Mısır patlağı gevrek", (("kase", "1 cup"),),
    ),
    2708402: (
        "rice_cooked", "Rice, cooked, NFS",
        "Pirinç (pişmiş)", (("kase", "1 cup, cooked"),),
    ),
    2708408: (
        "rice_no_fat", "Rice, white, cooked, no added fat",
        "Pilav (yağsız)", (("kase", "1 cup, cooked"),),
    ),
    2708414: (
        "brown_rice_no_fat", "Rice, brown, cooked, no added fat",
        "Esmer pirinç (yağsız)", (("kase", "1 cup, cooked"),),
    ),
    2708952: (
        "fried_rice", "Rice, fried, NFS",
        "Kavrulmuş pilav", (("kase", "1 cup"),),
    ),
    2708951: (
        "fried_rice_meatless", "Rice, fried, meatless",
        "Kavrulmuş pilav (etsiz)", (("kase", "1 cup"),),
    ),
    2708953: (
        "fried_rice_chicken", "Rice, fried, with chicken",
        "Tavuklu kavrulmuş pilav", (("kase", "1 cup"),),
    ),
    2708422: (
        "glutinous_rice", "Rice, white, cooked, glutinous",
        "Yapışkan pirinç", (("kase", "1 cup, cooked"),),
    ),
    2708416: (
        "rice_with_milk", "Rice, cooked, with milk",
        "Sütlü pirinç", (("kase", "1 cup, cooked"),),
    ),
    2706437: (
        "chicken_curry", "Chicken curry",
        "Tavuk köri", (("kase", "1 cup"),),
    ),
    2706428: (
        "chicken_with_gravy", "Chicken with gravy",
        "Soslu tavuk", (("kase", "1 cup"),),
    ),
    2706092: (
        "chicken_nuggets", "Chicken nuggets, NFS",
        "Tavuk nugget", (),
    ),
    2706090: (
        "chicken_fillet_grilled", "Chicken fillet, grilled",
        "Izgara tavuk fileto", (),
    ),
    2706089: (
        "chicken_fillet_breaded", "Chicken fillet, breaded",
        "Pane tavuk fileto", (),
    ),
    2706088: (
        "chicken_patty", "Chicken patty, breaded",
        "Tavuk köftesi", (),
    ),
    2706445: (
        "chicken_kiev", "Chicken kiev",
        "Kiev usulü tavuk", (),
    ),
    2706084: (
        "chicken_skin", "Chicken skin",
        "Tavuk derisi", (),
    ),
    2705847: (
        "beef_roast", "Beef, roast",
        "Rosto dana", (),
    ),
    2705850: (
        "corned_beef", "Beef, corned",
        "Salamura dana", (("dilim", "1 piece/slice, any size"),),
    ),
    2705851: (
        "beef_brisket", "Beef, brisket",
        "Dana döş", (),
    ),
    2705845: (
        "beef_shortribs", "Beef, shortribs",
        "Dana kaburga", (),
    ),
    2705848: (
        "beef_pot_roast", "Beef, pot roast",
        "Dana haşlama rosto", (),
    ),
    2705824: (
        "beef_steak", "Beef, steak, NFS",
        "Dana biftek", (),
    ),
    2705826: (
        "beef_steak_cube", "Beef, steak, cube",
        "Kuşbaşı dana", (),
    ),
    2705827: (
        "beef_steak_flank", "Beef, steak, flank",
        "Dana pirzola eti", (),
    ),
    2705843: (
        "oxtail", "Beef, oxtails",
        "Kuyruk eti", (),
    ),
    2705862: (
        "pork", "Pork, NFS",
        "Domuz eti", (),
    ),
    2705863: (
        "pork_ground", "Pork, ground",
        "Domuz kıyma", (),
    ),
    2705877: (
        "pork_tenderloin", "Pork, tenderloin",
        "Domuz bonfile", (),
    ),
    2705882: (
        "pork_roast", "Pork, roast",
        "Domuz rosto", (),
    ),
    2709382: (
        "potato_nfs", "Potato, NFS",
        "Patates (tür belirtilmemiş)", (),
    ),
    2709383: (
        "potato_baked", "Potato, baked, NFS",
        "Fırın patates", (("adet", "1 medium"),),
    ),
    2709492: (
        "mashed_potato", "Potato, mashed, NFS",
        "Patates püresi", (("kase", "1 cup"),),
    ),
    2709402: (
        "potato_roasted", "Potato, roasted, NFS",
        "Kızarmış fırın patates", (("kase", "1 cup"),),
    ),
    2709552: (
        "potato_pancake", "Potato pancake",
        "Patates mücveri", (),
    ),
    2709510: (
        "potato_patty", "Potato patty",
        "Patates köftesi", (),
    ),
    2709511: (
        "potato_tots", "Potato tots, NFS",
        "Patates topu", (),
    ),
    2709491: (
        "potato_skins", "Potato skins, NFS",
        "Patates kabuğu", (),
    ),
    2709422: (
        "potato_chips_plain", "Potato chips, plain",
        "Sade patates cipsi", (),
    ),
    2709444: (
        "potato_sticks", "Potato sticks, plain",
        "Patates çubuğu", (),
    ),
    2709448: (
        "potato_scalloped", "Potato, scalloped, NFS",
        "Fırında dilim patates", (("kase", "1 cup"),),
    ),
    2710195: (
        "salad_dressing", "Salad dressing, NFS, for salads",
        "Salata sosu", (),
    ),
    2710215: (
        "salad_dressing_light", "Salad dressing, light, NFS",
        "Hafif salata sosu", (),
    ),
    2707149: (
        "gravy", "Gravy, NFS",
        "Et sosu", (),
    ),
    2710177: (
        "sauce_nfs", "Sauce, NFS",
        "Sos (tür belirtilmemiş)", (),
    ),
    2705618: (
        "dip", "Dip, NFS",
        "Meze sosu (dip)", (),
    ),
    2705786: (
        "cheese_dip", "Cheese dip",
        "Peynirli sos", (),
    ),
    2705621: (
        "onion_dip", "Onion dip, regular",
        "Soğanlı sos", (),
    ),
    2710278: (
        "simple_syrup", "Simple syrup",
        "Şeker şurubu", (),
    ),
    2710272: (
        "syrup", "Syrup, NFS",
        "Şurup", (),
    ),
    2710302: (
        "fruit_butter", "Fruit butter",
        "Meyve ezmesi", (),
    ),
    2705387: (
        "milk_low_fat", "Milk, low fat (1%)",
        "Süt (yağsıza yakın, %1)", (("ml", "1 fl oz"),),
    ),
    2705388: (
        "milk_skim", "Milk, fat free (skim)",
        "Süt (yağsız)", (("ml", "1 fl oz"),),
    ),
    2705404: (
        "soy_milk_sweet", "Soy milk, sweetened",
        "Soya sütü (şekerli)", (("ml", "1 fl oz"),),
    ),
    2705405: (
        "soy_milk_plain", "Soy milk, unsweetened",
        "Soya sütü (şekersiz)", (("ml", "1 fl oz"),),
    ),
    2705407: (
        "almond_milk_sweet", "Almond milk, sweetened",
        "Badem sütü (şekerli)", (("ml", "1 fl oz"),),
    ),
    2705409: (
        "almond_milk_plain", "Almond milk, unsweetened",
        "Badem sütü (şekersiz)", (("ml", "1 fl oz"),),
    ),
    2705466: (
        "chocolate_milk", "Chocolate milk, NFS",
        "Çikolatalı süt", (("ml", "1 fl oz"),),
    ),
    2705472: (
        "hot_chocolate", "Hot chocolate / cocoa, NFS",
        "Sıcak çikolata", (("ml", "1 fl oz"),),
    ),
    2705513: (
        "fruit_smoothie", "Fruit smoothie, NFS",
        "Meyve smoothie", (("ml", "1 fl oz"),),
    ),
    2705594: (
        "half_and_half", "Cream, half and half",
        "Yarım krema", (),
    ),
    2705599: (
        "coffee_creamer", "Coffee creamer, NFS",
        "Kahve kreması", (),
    ),
    2705630: (
        "ice_cream_vanilla", "Ice cream, vanilla",
        "Dondurma (vanilyalı)", (("kase", "1 cup"),),
    ),
    2705632: (
        "ice_cream_chocolate", "Ice cream, chocolate",
        "Dondurma (çikolatalı)", (("kase", "1 cup"),),
    ),
    2705647: (
        "ice_cream_cone", "Ice cream cone, NFS",
        "Külahta dondurma", (("adet", "1 cone"),),
    ),
    2705658: (
        "ice_cream_sundae", "Ice cream sundae, NFS",
        "Dondurmalı sundae", (("kase", "1 cup"),),
    ),
    2705664: (
        "light_ice_cream", "Light ice cream, NFS",
        "Hafif dondurma", (("kase", "1 cup"),),
    ),
    2705452: (
        "frozen_yogurt_vanilla", "Frozen yogurt, vanilla",
        "Donmuş yoğurt (vanilyalı)", (("kase", "1 cup"),),
    ),
    2705450: (
        "yogurt_parfait", "Yogurt parfait, with fruit",
        "Meyveli yoğurt parfe", (),
    ),
    2705623: (
        "ranch_dip", "Ranch dip, regular",
        "Ranch sos", (),
    ),
    2705625: (
        "spinach_dip", "Spinach dip, regular",
        "Ispanaklı sos", (),
    ),
    2705627: (
        "vegetable_dip", "Vegetable dip, regular",
        "Sebzeli sos", (),
    ),
    2705616: (
        "sour_cream_fat_free", "Sour cream, fat free",
        "Ekşi krema (yağsız)", (),
    ),
    2705507: (
        "milk_shake_malt", "Milk shake with malt",
        "Maltlı milkshake", (("ml", "1 fl oz"),),
    ),
    2705406: (
        "soy_milk_chocolate", "Soy milk, chocolate",
        "Çikolatalı soya sütü", (("ml", "1 fl oz"),),
    ),
    2705906: (
        "lamb_chop", "Lamb, chop",
        "Kuzu pirzola", (),
    ),
    2705907: (
        "lamb_ground", "Lamb, ground",
        "Kuzu kıyma", (),
    ),
    2705910: (
        "veal_ground", "Veal, ground",
        "Dana kıyma (buzağı)", (),
    ),
    2705928: (
        "ostrich", "Ostrich",
        "Deve kuşu eti", (),
    ),
    2705912: (
        "rabbit", "Rabbit",
        "Tavşan eti", (),
    ),
    2706174: (
        "bratwurst", "Bratwurst",
        "Bratwurst sosis", (),
    ),
    2706179: (
        "chorizo", "Chorizo",
        "Chorizo sosis", (),
    ),
    2706181: (
        "knockwurst", "Knockwurst",
        "Knockwurst sosis", (),
    ),
    2706199: (
        "thuringer", "Thuringer",
        "Thuringer sosis", (),
    ),
    2706341: (
        "clams_fried", "Clams, fried",
        "Kızarmış deniz tarağı", (),
    ),
    2706551: (
        "gefilte_fish", "Gefilte fish",
        "Balık köftesi (gefilte)", (),
    ),
    2706824: (
        "crab_salad", "Crab salad",
        "Yengeç salatası", (("kase", "1 cup"),),
    ),
    2706826: (
        "salmon_salad", "Salmon salad",
        "Somon salatası", (("kase", "1 cup"),),
    ),
    2706840: (
        "tuna_salad", "Tuna salad with egg",
        "Ton balıklı salata", (("kase", "1 cup"),),
    ),
    2709815: (
        "coleslaw", "Coleslaw",
        "Lahana salatası", (("kase", "1 cup"),),
    ),
    2710056: (
        "pea_salad", "Pea salad",
        "Bezelye salatası", (("kase", "1 cup"),),
    ),
    2709816: (
        "cabbage_salad", "Cabbage salad, NFS",
        "Beyaz lahana salatası", (("kase", "1 cup"),),
    ),
    2705411: (
        "rice_milk", "Rice milk",
        "Pirinç sütü", (("ml", "1 fl oz"),),
    ),
    2705384: (
        "milk_nfs", "Milk, NFS",
        "Süt (tür belirtilmemiş)", (("ml", "1 fl oz"),),
    ),
    2705502: (
        "eggnog", "Eggnog",
        "Yumurtalı süt (eggnog)", (("ml", "1 fl oz"),),
    ),
    2705593: (
        "cream_light", "Cream, light",
        "Krema (hafif)", (),
    ),
    2705598: (
        "whipped_cream", "Cream, whipped",
        "Çırpılmış krema", (),
    ),
    2705614: (
        "sour_cream", "Sour cream, regular",
        "Ekşi krema", (),
    ),
    2705611: (
        "whipped_topping", "Whipped topping",
        "Krema şantisi", (),
    ),
    2705673: (
        "creamsicle", "Creamsicle",
        "Portakallı dondurma çubuğu", (("adet", "1 sicle"),),
    ),
    2705674: (
        "fudgesicle", "Fudgesicle",
        "Çikolatalı dondurma çubuğu", (("adet", "1 sicle"),),
    ),
    2705637: (
        "gelato_chocolate", "Gelato, chocolate",
        "Gelato (çikolatalı)", (("kase", "1 cup"),),
    ),
    2705663: (
        "fried_ice_cream", "Ice cream, fried",
        "Kızarmış dondurma", (),
    ),
    2707421: (
        "split_peas_fat", "Split peas, from dried, fat added",
        "Kuru bezelye (yağlı)", (("kase", "1 cup"),),
    ),
    2707406: (
        "pork_and_beans", "Pork and beans",
        "Etli fasulye konservesi", (("kase", "1 cup"),),
    ),
    2707422: (
        "wasabi_peas", "Wasabi peas",
        "Wasabi bezelye", (),
    ),
    2708418: (
        "congee", "Congee",
        "Pirinç lapası (congee)", (("kase", "1 cup"),),
    ),
    2708165: (
        "popcorn_cake", "Popcorn cake",
        "Mısır patlağı keki", (),
    ),
    2708166: (
        "rice_paper", "Rice paper",
        "Pirinç yufkası", (),
    ),
    2707705: (
        "zwieback", "Zwieback toast",
        "Zwieback peksimet", (),
    ),
    2708292: (
        "bagel_chips", "Bagel chips",
        "Halka ekmek cipsi", (),
    ),
}
NUTRIENTS = {
    1008: ("calories_per_100g", "kcal"),
    1003: ("protein_per_100g", "g"),
    1005: ("carbs_per_100g", "g"),
    1004: ("fat_per_100g", "g"),
    1079: ("fiber_per_100g", "g"),
}


# -- Piyasa ortalamasi tahminleri ----------------------------------------
#
# USDA arsivinde karsiligi olmayan Turk yemekleri. Degerler laboratuvar
# olcumu degildir; herkese acik Turkce kalori kaynaklarinin yayimladigi
# degerlerden secilmistir. Her kayit ESTIMATED olarak isaretlenir, kendi
# kaynak listesini tasir ve dogrulanmis kayitlardan ayri gorunur.
#
# Secim olcutu makro capraz kontroludur: protein*4 + karbonhidrat*4 +
# yag*9 ile bildirilen kalori arasindaki fark yuzde onu asarsa kaynak
# elenir. Boyle kaynaklar genellikle porsiyon degerini 100 gram diye
# yaziyor; ornegin bir gozleme kaydi 100 gramda 103 gram karbonhidrat
# bildiriyordu.
ESTIMATE_LICENSE = (
    "Public secondary sources; published estimates, not a laboratory "
    "measurement"
)
ESTIMATE_RETRIEVED_AT = "2026-09-07T00:00:00Z"
ESTIMATED = {
    "lahmacun": {
        "display_name_tr": "Lahmacun (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/lahmacun",
            "https://www.besinanaliz.com/foods/lahmacun",
        ],
        "nutrients": {
            "calories_per_100g": 221, "protein_per_100g": 9.74,
            "carbs_per_100g": 32.27, "fat_per_100g": 5.55,
            "fiber_per_100g": 2.87,
        },
    },
    "manti": {
        "display_name_tr": "Manti (haslanmis, sossuz, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/manti",
            "https://www.fitekran.com/besin-degeri/manti/",
        ],
        "nutrients": {
            "calories_per_100g": 170, "protein_per_100g": 4.12,
            "carbs_per_100g": 29.71, "fat_per_100g": 3.5,
            "fiber_per_100g": 0.85,
        },
    },
    "icli_kofte": {
        "display_name_tr": "Icli kofte (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/icli-kofte",
            "https://www.fitekran.com/besin-degeri/icli-kofte/",
        ],
        "nutrients": {
            "calories_per_100g": 233, "protein_per_100g": 9.87,
            "carbs_per_100g": 32.28, "fat_per_100g": 6.83,
            "fiber_per_100g": 2.4,
        },
    },
    "kisir": {
        "display_name_tr": "Kisir (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/kisir",
            "https://www.fitekran.com/besin-degeri/kisir/",
        ],
        "nutrients": {
            "calories_per_100g": 178, "protein_per_100g": 4.59,
            "carbs_per_100g": 31.69, "fat_per_100g": 3.75,
            "fiber_per_100g": 3.94,
        },
    },
    "kuru_fasulye": {
        "display_name_tr": "Kuru fasulye yemegi (tahmini)",
        "sources": [
            "https://yemek.com/kuru-fasulye-kalori/",
            "https://www.diyetkolik.com/kac-kalori/kuru-fasulye-etli",
        ],
        "nutrients": {
            "calories_per_100g": 140, "protein_per_100g": 7.0,
            "carbs_per_100g": 19.0, "fat_per_100g": 4.0,
            "fiber_per_100g": 6.0,
        },
    },
    "gozleme": {
        "display_name_tr": "Gozleme (peynirli, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/gozleme",
            "https://www.fitekran.com/besin-degeri/gozleme/",
        ],
        "nutrients": {
            "calories_per_100g": 269, "protein_per_100g": 10.35,
            "carbs_per_100g": 46.1, "fat_per_100g": 6.83,
            "fiber_per_100g": 2.2,
        },
    },
    "mucver": {
        "display_name_tr": "Mucver (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/mucver",
            "https://www.fitekran.com/besin-degeri/mucver/",
        ],
        "nutrients": {
            "calories_per_100g": 145, "protein_per_100g": 6.43,
            "carbs_per_100g": 10.0, "fat_per_100g": 8.82,
            "fiber_per_100g": 2.13,
        },
    },
    "hunkar_begendi": {
        "display_name_tr": "Hunkar begendi (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/hunkar-begendi",
            "https://www.dytseydaertas.com/besin/hunkar-begendi",
        ],
        "nutrients": {
            "calories_per_100g": 174, "protein_per_100g": 10.04,
            "carbs_per_100g": 5.32, "fat_per_100g": 12.1,
            "fiber_per_100g": 1.08,
        },
    },
    "cig_kofte": {
        "display_name_tr": "Cig kofte (etsiz, tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/cig-kofte-etsiz",
            "https://www.fitekran.com/besin-degeri/cig-kofte-etsiz/",
        ],
        "nutrients": {
            "calories_per_100g": 181, "protein_per_100g": 4.62,
            "carbs_per_100g": 32.91, "fat_per_100g": 4.02,
            "fiber_per_100g": 4.28,
        },
    },
    "asure": {
        "display_name_tr": "Asure (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/asure",
            "https://www.nefisyemektarifleri.com/kac-kalori/asure/",
        ],
        "nutrients": {
            "calories_per_100g": 344, "protein_per_100g": 7.84,
            "carbs_per_100g": 61.21, "fat_per_100g": 5.56,
            "fiber_per_100g": 6.82,
        },
    },
    "simit": {
        "display_name_tr": "Simit (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/susamli-simit",
            "https://www.fitekran.com/besin-degeri/sokak-simiti/",
        ],
        "nutrients": {
            "calories_per_100g": 320, "protein_per_100g": 9.0,
            "carbs_per_100g": 62.0, "fat_per_100g": 4.0,
            "fiber_per_100g": 2.5,
        },
    },
    "lokum": {
        "display_name_tr": "Lokum (tahmini)",
        "sources": [
            "https://www.diyetkolik.com/kac-kalori/lokum",
            "https://www.dytseydaertas.com/besin/lokum",
        ],
        "nutrients": {
            "calories_per_100g": 359, "protein_per_100g": 0.12,
            "carbs_per_100g": 89.28, "fat_per_100g": 0.19,
            "fiber_per_100g": 0.5,
        },
    },
}


def _macro_delta_percent(nutrients: dict) -> float:
    macro = (
        nutrients["protein_per_100g"] * 4
        + nutrients["carbs_per_100g"] * 4
        + nutrients["fat_per_100g"] * 9
    )
    calories = nutrients["calories_per_100g"]
    return abs(macro - calories) / calories * 100


def _add_estimates(catalog: dict) -> None:
    """Add estimated Turkish dishes, each carrying the sources used."""
    for key, row in ESTIMATED.items():
        delta = _macro_delta_percent(row["nutrients"])
        if delta > 10:
            raise ValueError(
                f"{key}: macro cross-check failed ({delta:.1f}%)"
            )
        source_id = f"estimate:{key}"
        catalog["_meta"]["source_inventory"][source_id] = {
            "source_url": row["sources"][0],
            "source_item_name": row["display_name_tr"],
            "retrieved_at": ESTIMATE_RETRIEVED_AT,
            "license": ESTIMATE_LICENSE,
            "attribution": (
                "Piyasa ortalamasi tahmini. Kaynaklar: "
                + ", ".join(row["sources"])
            ),
        }
        record = {
            "evidence_status": "ESTIMATED",
            "source_item_id": source_id,
            "locale": "tr-TR",
            "display_name_tr": row["display_name_tr"],
            "default_portion_g": 100,
            "serving_unit": "gram",
            "serving_quantity": 100,
            "portion_units": [],
            "estimate_sources": row["sources"],
            "macro_delta_percent": round(delta, 2),
        }
        record.update(row["nutrients"])
        catalog[key] = record


def _portion_units(food: dict, specs, source_id: str) -> list:
    """Turn reviewed FNDDS portions into unit weights that carry their measure.

    Each row cites the exact portion row it came from. A food citation alone is
    not a weight measurement, so the catalog records the measure text too.
    """
    portions = {
        row["portionDescription"]: row["gramWeight"]
        for row in food.get("foodPortions", [])
        if row.get("portionDescription")
    }
    rows = []
    for unit, measure in specs:
        if measure not in portions:
            raise ValueError(
                f"Reviewed portion '{measure}' missing for {food['description']}"
            )
        grams = portions[measure]
        if not isinstance(grams, (int, float)) or grams <= 0:
            raise ValueError(f"Invalid gram weight for '{measure}'")
        if unit == "ml":
            millilitres = MILLILITRES[measure]
            value = grams / millilitres
            if not 0 < value <= 2:
                raise ValueError(f"Implausible density for {food['description']}")
        else:
            value = float(grams)
        rows.append({
            "unit": unit,
            "grams_per_unit": round(value, 4),
            "source_item_id": source_id,
            "source_measure": f"FNDDS food portion: {measure} = {grams} g",
        })
    return rows


def build_catalog(archive: Path) -> dict:
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("USDA archive checksum mismatch; review a new release explicitly")
    with zipfile.ZipFile(archive) as bundle:
        foods = json.loads(bundle.read("surveyDownload.json"))["SurveyFoods"]
    catalog = {"_meta": {
        "version": "usda-fndds-2021-2023-subset-v1",
        "evidence_status": "VERIFIED",
        "verification_method": "Exact nutrient extraction from pinned official USDA FNDDS archive",
        "archive_url": SOURCE_URL,
        "archive_sha256": ARCHIVE_SHA256,
        "expert_reviewed_at": None,
        "limitations": "Source verification is not clinical validation. Recipe and actual portion may differ.",
        "source_inventory": {},
    }}
    for food in foods:
        if food["fdcId"] not in REVIEWED:
            continue
        key, description, display, unit_specs = REVIEWED[food["fdcId"]]
        if food["description"] != description:
            raise ValueError("Reviewed food description changed")
        source_id = f"usda-fdc:{food['fdcId']}"
        url = f"https://fdc.nal.usda.gov/fdc-app.html#/food-details/{food['fdcId']}/nutrients"
        catalog["_meta"]["source_inventory"][source_id] = {
            "source_url": url, "source_item_name": description,
            "retrieved_at": "2026-09-07T05:37:48Z", "license": "CC0 1.0",
            "attribution": f"USDA FoodData Central, FNDDS 2021-2023. {description}. {url}",
        }
        record = {
            "evidence_status": "VERIFIED", "source_item_id": source_id,
            "locale": "en-US", "display_name_tr": display,
            # 100 g is a calculation basis, not a measured serving or a universal item weight.
            "default_portion_g": 100, "serving_unit": "gram", "serving_quantity": 100,
            "portion_units": _portion_units(food, unit_specs, source_id),
        }
        for nutrient in food["foodNutrients"]:
            spec = NUTRIENTS.get(nutrient["nutrient"]["id"])
            if spec:
                field, unit = spec
                if nutrient["nutrient"]["unitName"].lower() != unit:
                    raise ValueError("Unexpected nutrient unit")
                record[field] = nutrient["amount"]
        if not all(field in record for field, _ in NUTRIENTS.values()):
            raise ValueError("Missing required nutrient")
        catalog[key] = record
    if set(catalog) - {"_meta"} != {row[0] for row in REVIEWED.values()}:
        raise ValueError("Missing reviewed food")
    _add_estimates(catalog)
    return catalog


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "app/data/verified_nutrition.json")
    args = parser.parse_args()
    result = build_catalog(args.archive)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(result) - 1} records (USDA verified + estimates): "
          f"{args.output}")
