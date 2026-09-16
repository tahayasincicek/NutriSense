"""Sunucu tarafı görüntü tanıma sağlayıcılarının ortak hataları.

Sunucuda şu an bir sağlayıcı yoktur; tanımayı uygulama telefondaki modelle
yapar. İleride yurt içinde çalışan bir sunucu modeli eklenirse bu hataları
kullanır.
"""


class VisionAPIError(Exception):
    """Görüntü tanıma sağlayıcısı kullanılamıyor."""


class FoodNotFoundError(Exception):
    """Görüntüde besin tespit edilemedi."""
