import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secureStorageChannel =
    MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

/// Güvenli depolama kanalını testte yanıt verir hâle getirir.
///
/// Gerçek cihazda `ApiService` açılışta kayıtlı oturumu okur ve Android
/// Keystore takılırsa uygulamanın kilitlenmemesi için okumayı zaman aşımına
/// bağlar. Testte kanalın karşılığı olmadığından okuma hiç tamamlanmaz;
/// zaman aşımı zamanlayıcısı test bitene kadar askıda kalır ve Flutter
/// "A Timer is still pending" diyerek testi düşürür.
///
/// Okuma ayrıca eski düz metin jetonlarını temizlemek için SharedPreferences'a
/// uğrar; o da taklit edilmezse aynı şekilde askıda kalır. Bu yüzden ikisi
/// birlikte kurulur.
///
/// Kanalları yanıt verir hâle getirmek okumayı tamamlar, zamanlayıcı iptal olur
/// ve üretimdeki koruma olduğu gibi kalır.
void mockSecureStorage() {
  SharedPreferences.setMockInitialValues({});
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    switch (call.method) {
      case 'readAll':
        return <String, String>{};
      case 'containsKey':
        return false;
      default:
        // read, write, delete ve deleteAll için null yeterlidir.
        return null;
    }
  });
}

/// Kurulan taklidi kaldırır.
void resetSecureStorageMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, null);
}

/// Platform deposuna hiç dokunmayan oturum deposu.
class _MemoryTokenStore implements TokenStore {
  AuthSession? _session;

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession value) async => _session = value;
}

/// Ağ isteklerini anında 401 ile karşılayan adaptör.
///
/// Gerçek adaptör bağlantı kurmaya çalışır ve zaman aşımı zamanlayıcıları
/// bırakır; test bittiğinde bunlar askıda kaldığı için Flutter testi düşürür.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode({'detail': 'test'}),
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// Tüm uygulamayı pump eden testler için `apiServiceProvider` override'ı.
///
/// Uygulama kabuğu açılışta oturumu okur ve ekranlar veri çeker. Gerçek
/// güvenli depo ile gerçek ağ adaptörü testte yanıt vermediği için zaman
/// aşımı zamanlayıcıları askıda kalır. Bu override ikisini de devre dışı
/// bırakır: oturum bellekte, istekler anında 401.
Override memoryTokenStoreOverride() => apiServiceProvider.overrideWithValue(
      ApiService(
        dio: Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'))
          ..httpClientAdapter = _OfflineAdapter(),
        tokenStore: _MemoryTokenStore(),
      ),
    );
