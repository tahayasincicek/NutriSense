import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisense/shared/models/auth_model.dart';
import 'package:nutrisense/shared/models/food_analysis_model.dart';
import 'package:nutrisense/shared/services/api_service.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('contracts/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('paylaşılan JSON fixture consumer contract', () {
    test('başarılı ve ileri uyumlu besin yanıtını parse eder', () {
      final result = FoodAnalysisResult.fromJson(
        _fixture('food_analysis_success.json'),
      );

      expect(result.analysisId, '550e8400-e29b-41d4-a716-446655440000');
      expect(result.logId, isNull);
      expect(result.foodNameTr, 'Elma');
      expect(result.portionGrams, 150);
      expect(result.nutrients.carbs, 20.7);
      expect(result.needsConfirmation, isTrue);
      expect(result.canConfirm, isTrue);
      expect(result.candidates.single.foodNameTr, 'Elma');
      expect(result.recognitionSource, 'google_vision');
      expect(result.nutritionSource, 'nutritionix');
    });

    test('düşük güven yanıtı kullanıcı onayı gerektirir', () {
      final result = FoodAnalysisResult.fromJson(
        _fixture('food_analysis_low_confidence.json'),
      );
      expect(result.confidence, 0.42);
      expect(result.needsConfirmation, isTrue);
    });

    test('geçmiş fixture alanlarını ve ISO-8601 zamanı parse eder', () {
      final history = FoodHistoryResult.fromJson(
        _fixture('food_history_success.json'),
      );
      expect(history.dailyLogs.single.foods.single.foodNameTr, 'Elma');
      expect(history.dailyLogs.single.foods.single.loggedAt.isUtc, isTrue);
      expect(history.dailyLogs.single.foods.single.nutrients.carbs, 20.7);
    });

    test('auth token fixture rotation sürelerini parse eder', () {
      final auth = AuthTokenResult.fromJson(
        _fixture('auth_tokens_success.json'),
      );
      expect(auth.expiresIn, 3600);
      expect(auth.refreshExpiresIn, 2592000);
    });

    test('zorunlu alan null ise sözleşme ihlalini gizlemez', () {
      final fixture = _fixture('food_analysis_success.json');
      fixture['analysis_id'] = null;
      expect(
        () => FoodAnalysisResult.fromJson(fixture),
        throwsFormatException,
      );
    });

    test('confidence 0..1 dışındaysa reddeder', () {
      final fixture = _fixture('food_analysis_success.json');
      fixture['confidence'] = 93;
      expect(
        () => FoodAnalysisResult.fromJson(fixture),
        throwsFormatException,
      );
    });
  });

  group('kanonik istemci auth kuyruğu', () {
    test('başarılı login tokenları güvenli token store soyutlamasına yazar',
        () async {
      final store = _MemoryTokenStore(null);
      final apiDio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
        ..httpClientAdapter = _FakeAdapter(
          (_) async => _jsonResponse(200, _fixture('auth_tokens_success.json')),
        );
      final api = ApiService(dio: apiDio, tokenStore: store);

      final result = await api.login(
        email: 'user@example.test',
        password: 'Guvenli123',
      );

      expect(result.isSuccess, isTrue);
      expect(store.session?.accessToken, isNotEmpty);
      expect(store.session?.refreshToken, isNotEmpty);
    });

    test('başarısız hesap silme yerel oturumu silmez', () async {
      final store = _MemoryTokenStore(_oldSession);
      final apiDio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
        ..httpClientAdapter = _FakeAdapter(
          (_) async => _jsonResponse(401, _fixture('error_unauthorized.json')),
        );
      final api = ApiService(dio: apiDio, tokenStore: store);

      final result = await api.deleteAccount(password: 'Yanlis123');

      expect(result.isError, isTrue);
      expect(store.session, isNotNull);
      expect(store.clearCount, 0);
    });

    test('eşzamanlı 401 yanıtları tek refresh isteğini paylaşır', () async {
      final store = _MemoryTokenStore(_oldSession);
      var protectedCalls = 0;
      var refreshCalls = 0;

      final apiDio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
        ..httpClientAdapter = _FakeAdapter((request) async {
          if (request.path.endsWith('/auth/refresh')) {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            final fixture = _fixture('auth_tokens_success.json')
              ..['access_token'] = 'new-access'
              ..['refresh_token'] = 'rotated-refresh';
            return _jsonResponse(200, fixture);
          }
          protectedCalls++;
          if (request.headers['Authorization'] == 'Bearer new-access') {
            return _jsonResponse(200, _fixture('food_history_success.json'));
          }
          return _jsonResponse(401, _fixture('error_unauthorized.json'));
        });
      final api = ApiService(
        dio: apiDio,
        tokenStore: store,
      );
      await api.initialize();

      final results = await Future.wait([
        api.getFoodHistory(),
        api.getFoodHistory(),
      ]);

      expect(results.every((result) => result.isSuccess), isTrue);
      expect(refreshCalls, 1);
      expect(protectedCalls, 4);
      expect(store.session?.refreshToken, 'rotated-refresh');
    });

    test('refresh başarısızsa oturum tek depolama işlemiyle temizlenir',
        () async {
      final store = _MemoryTokenStore(_oldSession);
      final apiDio = Dio(BaseOptions(baseUrl: 'https://contract.test/api/v1'))
        ..httpClientAdapter = _FakeAdapter(
          (request) async => _jsonResponse(
            401,
            _fixture('error_unauthorized.json'),
          ),
        );

      final api = ApiService(
        dio: apiDio,
        tokenStore: store,
      );
      await api.initialize();
      final result = await api.getFoodHistory();

      expect(result.isError, isTrue);
      expect(store.session, isNull);
      expect(store.clearCount, 1);
    });
  });

  test('diyetisyen atama sözleşmesi doğrulama durumlarını parse eder', () {
    final assignment = DietitianAssignmentInfo.fromJson({
      'assignment_id': '550e8400-e29b-41d4-a716-446655440000',
      'status': 'approved',
      'dietitian_id': 'e33029ee-4d91-4fc5-b489-26a2ba955e44',
      'dietitian_name': 'Test Diyetisyen',
      'email_verified': true,
      'phone_verified': false,
    });
    expect(assignment.isApproved, isTrue);
    expect(assignment.hasVerifiedContact, isTrue);
  });

  test('timeout TTS başlatmadan tipli ağ hatasına dönüşür', () {
    final request = RequestOptions(path: '/analyze-food');
    final failure = ApiFailure.fromDio(DioException(
      requestOptions: request,
      type: DioExceptionType.receiveTimeout,
    ));
    expect(failure.code, 'TIMEOUT');
    expect(failure.kind, ApiFailureKind.timeout);
  });
}

const _oldSession = AuthSession(
  accessToken: 'old-access',
  refreshToken: 'old-refresh',
  userId: '9e4e5356-b491-4575-a9dd-c5abbc777fe9',
  fullName: 'Contract User',
  expiresIn: 1,
  refreshExpiresIn: 3600,
);

class _MemoryTokenStore implements TokenStore {
  AuthSession? session;
  int clearCount = 0;

  _MemoryTokenStore(this.session);

  @override
  Future<void> clear() async {
    clearCount++;
    session = null;
  }

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession session) async {
    this.session = session;
  }
}

typedef _Responder = FutureOr<ResponseBody> Function(RequestOptions request);

class _FakeAdapter implements HttpClientAdapter {
  final _Responder responder;

  _FakeAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      responder(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int status, Map<String, dynamic> data) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
