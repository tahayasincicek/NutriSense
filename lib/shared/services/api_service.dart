import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../models/food_analysis_model.dart';
import '../models/auth_model.dart';
import '../../features/dietitian/models/dietitian_dashboard_models.dart';

enum ApiCallState { idle, loading, success, error }

class ApiResult<T> {
  final ApiCallState state;
  final T? data;
  final ApiFailure? failure;

  const ApiResult._(this.state, {this.data, this.failure});

  const ApiResult.idle() : this._(ApiCallState.idle);
  const ApiResult.loading() : this._(ApiCallState.loading);
  const ApiResult.success(T data) : this._(ApiCallState.success, data: data);
  const ApiResult.error(ApiFailure failure)
      : this._(ApiCallState.error, failure: failure);

  bool get isLoading => state == ApiCallState.loading;
  bool get isSuccess => state == ApiCallState.success;
  bool get isError => state == ApiCallState.error;
  String? get errorMessage => failure?.message;
  String? get errorCode => failure?.code;
}

enum ApiFailureKind {
  unauthorized,
  validation,
  timeout,
  connection,
  cancelled,
  server,
  contract,
  unknown,
}

class ApiFailure implements Exception {
  final String code;
  final String message;
  final ApiFailureKind kind;
  final int? statusCode;
  final String? requestId;
  final Object? details;

  const ApiFailure({
    required this.code,
    required this.message,
    required this.kind,
    this.statusCode,
    this.requestId,
    this.details,
  });

  factory ApiFailure.fromDio(DioException error) {
    final response = error.response;
    final body = response?.data;
    final errorBody = body is Map ? body['error'] : null;
    final standard = errorBody is Map ? errorBody : const <String, dynamic>{};
    final requestId = standard['request_id'] as String? ??
        response?.headers.value('x-request-id');

    if (error.type == DioExceptionType.cancel) {
      return const ApiFailure(
        code: 'REQUEST_CANCELLED',
        message: 'İstek iptal edildi.',
        kind: ApiFailureKind.cancelled,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiFailure(
        code: 'TIMEOUT',
        message: 'Sunucu zamanında yanıt vermedi.',
        kind: ApiFailureKind.timeout,
        requestId: requestId,
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return ApiFailure(
        code: 'CONNECTION_ERROR',
        message: 'Sunucuya bağlanılamadı.',
        kind: ApiFailureKind.connection,
        requestId: requestId,
      );
    }

    final status = response?.statusCode;
    return ApiFailure(
      code: standard['code'] as String? ?? 'HTTP_ERROR',
      message: standard['message'] as String? ?? 'İstek tamamlanamadı.',
      kind: status == 401
          ? ApiFailureKind.unauthorized
          : status == 400 || status == 413 || status == 415 || status == 422
              ? ApiFailureKind.validation
              : status != null && status >= 500
                  ? ApiFailureKind.server
                  : ApiFailureKind.unknown,
      statusCode: status,
      requestId: requestId,
      details: standard['details'],
    );
  }

  @override
  String toString() => 'ApiFailure($code, requestId: $requestId): $message';
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String fullName;
  final int expiresIn;
  final int refreshExpiresIn;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.fullName,
    required this.expiresIn,
    required this.refreshExpiresIn,
  });

  factory AuthSession.fromAuth(AuthTokenResult auth) => AuthSession(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        userId: auth.userId,
        fullName: auth.fullName,
        expiresIn: auth.expiresIn,
        refreshExpiresIn: auth.refreshExpiresIn,
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? '',
        expiresIn: json['expires_in'] as int? ?? 0,
        refreshExpiresIn: json['refresh_expires_in'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'user_id': userId,
        'full_name': fullName,
        'expires_in': expiresIn,
        'refresh_expires_in': refreshExpiresIn,
      };
}

abstract interface class TokenStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

class FlutterSecureStorageTokenStore implements TokenStore {
  static const _sessionKey = 'auth_session_v1';
  final FlutterSecureStorage _storage;

  FlutterSecureStorageTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<AuthSession?> read() async {
    await _removeLegacyPlaintextTokens();
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null) return null;
    try {
      return AuthSession.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _removeLegacyPlaintextTokens();
  }

  Future<void> _removeLegacyPlaintextTokens() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('auth_access_token');
    await preferences.remove('auth_refresh_token');
    await preferences.remove('auth_user_id');
    await preferences.remove('auth_full_name');
    await preferences.remove('auth_expires_in');
    await preferences.remove('auth_refresh_expires_in');
  }
}

/// Uygulamadaki tek kanonik HTTP istemcisi.
class ApiService {
  static const _maxImageBytes = 5 * 1024 * 1024;
  static const _retryCountKey = 'idempotent_retry_count';
  static const _authRetriedKey = 'auth_retried';
  static const _skipAuthKey = 'skip_auth';
  static const _skipRefreshKey = 'skip_refresh';
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS'};

  final Dio _dio;
  final TokenStore _tokenStore;
  final Uuid _uuid;
  late final Future<void> _initialization;
  AuthSession? _session;
  Completer<bool>? _refreshCompleter;

  ApiService({
    Dio? dio,
    TokenStore? tokenStore,
    Uuid uuid = const Uuid(),
  })  : _dio = dio ?? Dio(_baseOptions()),
        _tokenStore = tokenStore ?? FlutterSecureStorageTokenStore(),
        _uuid = uuid {
    _initialization = _restoreSession();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  static BaseOptions _baseOptions() => BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {'Accept': 'application/json'},
      );

  String? get userId => _session?.userId;
  bool get isAuthenticated => _session != null;

  Future<void> initialize() => _initialization;

  Future<void> _restoreSession() async {
    _session = await _tokenStore.read();
  }

  Future<void> _saveAuth(AuthTokenResult auth) async {
    final session = AuthSession.fromAuth(auth);
    await _tokenStore.write(session);
    _session = session;
  }

  Future<void> _clearSession() async {
    _session = null;
    await _tokenStore.clear();
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _initialization;
    options.headers.putIfAbsent('X-Request-ID', _uuid.v4);
    if (options.extra[_skipAuthKey] != true && _session != null) {
      options.headers['Authorization'] = 'Bearer ${_session!.accessToken}';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final canRefresh = error.response?.statusCode == 401 &&
        request.extra[_skipAuthKey] != true &&
        request.extra[_skipRefreshKey] != true &&
        request.extra[_authRetriedKey] != true &&
        _session?.refreshToken != null;

    if (canRefresh && await _refreshSession()) {
      request.extra[_authRetriedKey] = true;
      request.headers['Authorization'] = 'Bearer ${_session!.accessToken}';
      try {
        return handler.resolve(await _dio.fetch(request));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }

    final retryCount = request.extra[_retryCountKey] as int? ?? 0;
    if (_isTransient(error) &&
        _idempotentMethods.contains(request.method.toUpperCase()) &&
        retryCount < 1 &&
        request.cancelToken?.isCancelled != true) {
      request.extra[_retryCountKey] = retryCount + 1;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      try {
        return handler.resolve(await _dio.fetch(request));
      } on DioException catch (retryError) {
        return handler.next(retryError);
      }
    }

    handler.next(error);
  }

  bool _isTransient(DioException error) =>
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionError ||
      (error.response?.statusCode != null &&
          error.response!.statusCode! >= 500);

  Future<bool> _refreshSession() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    _performRefresh().then(completer.complete).catchError((Object _) {
      if (!completer.isCompleted) completer.complete(false);
    }).whenComplete(() {
      _refreshCompleter = null;
    });
    return completer.future;
  }

  Future<bool> _performRefresh() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(extra: const {_skipAuthKey: true}),
      );
      final auth = AuthTokenResult.fromJson(response.data ?? const {});
      await _saveAuth(auth);
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<ApiResult<AuthTokenResult>> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    double dailyCalorieTarget = 2000,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/register',
          data: {
            'email': email,
            'password': password,
            'full_name': fullName,
            'phone': phone,
            'daily_calorie_target': dailyCalorieTarget,
          },
          cancelToken: cancelToken,
          options: Options(extra: const {_skipAuthKey: true}),
        );
        final auth = AuthTokenResult.fromJson(response.data ?? const {});
        await _saveAuth(auth);
        return auth;
      });

  Future<ApiResult<AuthTokenResult>> registerDietitian({
    required String email,
    required String password,
    required String fullName,
    required String specialization,
    String? phone,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/register-dietitian',
          data: {
            'email': email,
            'password': password,
            'full_name': fullName,
            'phone': phone,
            'specialization': specialization,
          },
          cancelToken: cancelToken,
          options: Options(extra: const {_skipAuthKey: true}),
        );
        final auth = AuthTokenResult.fromJson(response.data ?? const {});
        await _saveAuth(auth);
        return auth;
      });

  Future<ApiResult<AuthTokenResult>> login({
    required String email,
    required String password,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: {'email': email, 'password': password},
          cancelToken: cancelToken,
          options: Options(extra: const {_skipAuthKey: true}),
        );
        final auth = AuthTokenResult.fromJson(response.data ?? const {});
        await _saveAuth(auth);
        return auth;
      });

  Future<ApiResult<void>> logout({CancelToken? cancelToken}) =>
      _safeCall(() async {
        final refreshToken = _session?.refreshToken;
        try {
          if (refreshToken != null) {
            await _dio.post<void>(
              '/auth/logout',
              data: {'refresh_token': refreshToken},
              cancelToken: cancelToken,
            );
          }
        } finally {
          await _clearSession();
        }
      });

  Future<ApiResult<UserProfile>> getCurrentUser({CancelToken? cancelToken}) =>
      _safeCall(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/users/me',
          cancelToken: cancelToken,
        );
        return UserProfile.fromJson(response.data ?? const {});
      });

  Future<ApiResult<DietitianDashboardData>> getDietitianDashboard({
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/dietitian/dashboard',
          cancelToken: cancelToken,
        );
        return DietitianDashboardData.fromJson(response.data ?? const {});
      });

  Future<ApiResult<DietitianPatientHistoryData>> getDietitianPatientHistory({
    required String patientId,
    int days = 30,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/dietitian/patients/$patientId/history',
          queryParameters: {'days': days},
          cancelToken: cancelToken,
        );
        return DietitianPatientHistoryData.fromJson(
          response.data ?? const {},
        );
      });

  /// Parola sıfırlama kodu ister.
  ///
  /// Sunucu, e-posta kayıtlı olsun ya da olmasın aynı yanıtı döner; hesabın
  /// varlığı sızdırılmaz. Bu yüzden başarı yanıtı "kod gönderildi" anlamına
  /// gelmez, yalnız isteğin işlendiğini gösterir.
  Future<ApiResult<String>> requestPasswordReset({
    required String email,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/password-reset',
          data: {'email': email.trim().toLowerCase()},
          cancelToken: cancelToken,
          options: Options(extra: const {_skipRefreshKey: true}),
        );
        return response.data?['message'] as String? ??
            'Sıfırlama kodu gönderildi.';
      });

  /// Kod ile yeni parolayı belirler.
  Future<ApiResult<String>> confirmPasswordReset({
    required String token,
    required String newPassword,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/password-reset/confirm',
          data: {
            'token': token.trim(),
            'new_password': newPassword,
          },
          cancelToken: cancelToken,
          options: Options(extra: const {_skipRefreshKey: true}),
        );
        return response.data?['message'] as String? ?? 'Parolanız güncellendi.';
      });

  Future<ApiResult<void>> deleteAccount({
    required String password,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        await _dio.delete<void>(
          '/users/me',
          data: {
            'password': password,
            'confirmation': 'HESABIMI SIL',
          },
          cancelToken: cancelToken,
          options: Options(extra: const {_skipRefreshKey: true}),
        );
        await _clearSession();
      });

  Future<ApiResult<DietitianAssignmentInfo?>> getDietitianAssignment({
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.get<dynamic>(
          '/dietitians/assignment',
          cancelToken: cancelToken,
        );
        final data = response.data;
        if (data == null) return null;
        return DietitianAssignmentInfo.fromJson(
          Map<String, dynamic>.from(data as Map),
        );
      });

  Future<ApiResult<DietitianAssignmentInfo>> requestDietitianAssignment({
    required String email,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/dietitians/assignment',
          data: {'dietitian_email': email},
          cancelToken: cancelToken,
        );
        return DietitianAssignmentInfo.fromJson(response.data ?? const {});
      });

  Future<ApiResult<DietitianAssignmentInfo>> approveDietitianAssignment({
    required String assignmentId,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/dietitians/assignment/$assignmentId/approve',
          cancelToken: cancelToken,
        );
        return DietitianAssignmentInfo.fromJson(response.data ?? const {});
      });

  Future<ApiResult<void>> cancelDietitianAssignment({
    required String assignmentId,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        await _dio.delete<void>(
          '/dietitians/assignment/$assignmentId',
          cancelToken: cancelToken,
        );
      });

  Future<ApiResult<FoodAnalysisResult>> analyzeFood({
    required Uint8List imageBytes,
    required String captureId,
    String fileName = 'capture.jpg',
    String mealType = 'atistirmalik',
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) =>
      _safeCall(() async {
        if (imageBytes.isEmpty || imageBytes.length > _maxImageBytes) {
          throw const ApiFailure(
            code: 'INVALID_IMAGE_SIZE',
            message: 'Görüntü boş olamaz ve en fazla 5 MB olabilir.',
            kind: ApiFailureKind.validation,
          );
        }
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
          'meal_type': mealType,
          'capture_id': captureId,
        });
        final response = await _dio.post<Map<String, dynamic>>(
          '/analyze-food',
          data: form,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        );
        return FoodAnalysisResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodAnalysisDecisionResult>> decideFoodAnalysis({
    required String analysisId,
    required String action,
    String? correctedFoodName,
    String? correctedFoodNameTr,
    double? portionValue,
    String? portionUnit,
    String? portionMethod,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/food-analysis/$analysisId/decision',
          data: {
            'action': action,
            if (correctedFoodName != null)
              'corrected_food_name': correctedFoodName,
            if (correctedFoodNameTr != null)
              'corrected_food_name_tr': correctedFoodNameTr,
            if (portionValue != null) 'portion_value': portionValue,
            if (portionUnit != null) 'portion_unit': portionUnit,
            if (portionMethod != null) 'portion_method': portionMethod,
          },
          cancelToken: cancelToken,
        );
        return FoodAnalysisDecisionResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodAnalysisResult>> updateFoodPortion({
    required String analysisId,
    required double portionValue,
    required String portionUnit,
    required String portionMethod,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/food-analysis/$analysisId/portion',
          data: {
            'portion_value': portionValue,
            'portion_unit': portionUnit,
            'portion_method': portionMethod,
          },
          cancelToken: cancelToken,
        );
        return FoodAnalysisResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodAnalysisDecisionResult>> createManualFoodLog({
    required String captureId,
    required String foodName,
    String? foodNameTr,
    String mealType = 'atistirmalik',
    double portionValue = 100,
    String portionMethod = 'user_selected',
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/food-log/manual',
          data: {
            'capture_id': captureId,
            'food_name': foodName,
            'food_name_tr': foodNameTr,
            'meal_type': mealType,
            'confirmed': true,
            'portion_value': portionValue,
            'portion_unit': 'gram',
            'portion_method': portionMethod,
          },
          cancelToken: cancelToken,
        );
        return FoodAnalysisDecisionResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodAnalysisResult>> searchFoodByName({
    required String query,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/food/search',
          queryParameters: {'query': query},
          cancelToken: cancelToken,
        );
        return FoodAnalysisResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodHistoryResult>> getFoodHistory({
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int pageSize = 7,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final currentUserId = userId;
        if (currentUserId == null) {
          throw const ApiFailure(
            code: 'AUTH_REQUIRED',
            message: 'Yemek geçmişi için oturum açılmalıdır.',
            kind: ApiFailureKind.unauthorized,
          );
        }
        final response = await _dio.get<Map<String, dynamic>>(
          '/food-history/$currentUserId',
          queryParameters: {
            if (fromDate != null) 'from_date': _date(fromDate),
            if (toDate != null) 'to_date': _date(toDate),
            'page': page,
            'page_size': pageSize,
          },
          cancelToken: cancelToken,
        );
        return FoodHistoryResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<FoodLogEntry>> updateFoodLog({
    required String logId,
    String? foodNameTr,
    double? portionGrams,
    String? mealType,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          '/food-logs/$logId',
          data: {
            if (foodNameTr != null) 'food_name_tr': foodNameTr,
            if (portionGrams != null) 'portion_g': portionGrams,
            if (mealType != null) 'meal_type': mealType,
          },
          cancelToken: cancelToken,
        );
        return FoodLogEntry.fromJson(response.data ?? const {});
      });

  Future<ApiResult<Map<String, dynamic>>> deleteFoodLog({
    required String logId,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.delete<Map<String, dynamic>>(
          '/food-logs/$logId',
          cancelToken: cancelToken,
        );
        return response.data ?? const {};
      });

  Future<ApiResult<Map<String, dynamic>>> restoreFoodLog({
    required String logId,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/food-logs/$logId/restore',
          cancelToken: cancelToken,
        );
        return response.data ?? const {};
      });

  Future<ApiResult<SendToDietitianResult>> sendToDietitian({
    required bool consent,
    required List<String> channels,
    required String consentContextHash,
    required String idempotencyKey,
    String reportType = 'weekly',
    DateTime? fromDate,
    DateTime? toDate,
    String? message,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final currentUserId = userId;
        if (currentUserId == null) {
          throw const ApiFailure(
            code: 'AUTH_REQUIRED',
            message: 'Rapor göndermek için oturum açılmalıdır.',
            kind: ApiFailureKind.unauthorized,
          );
        }
        final response = await _dio.post<Map<String, dynamic>>(
          '/send-to-dietitian',
          data: {
            'user_id': currentUserId,
            'report_type': reportType,
            'consent': consent,
            'channels': channels,
            'consent_context_hash': consentContextHash,
            if (fromDate != null) 'from_date': _date(fromDate),
            if (toDate != null) 'to_date': _date(toDate),
            if (message != null) 'message': message,
          },
          cancelToken: cancelToken,
          options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
        return SendToDietitianResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<DietitianReportPreview>> previewDietitianReport({
    required List<String> channels,
    String reportType = 'weekly',
    DateTime? fromDate,
    DateTime? toDate,
    String? message,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final currentUserId = userId;
        if (currentUserId == null) {
          throw const ApiFailure(
            code: 'AUTH_REQUIRED',
            message: 'Rapor önizlemek için oturum açılmalıdır.',
            kind: ApiFailureKind.unauthorized,
          );
        }
        final response = await _dio.post<Map<String, dynamic>>(
          '/dietitian-reports/preview',
          data: {
            'user_id': currentUserId,
            'report_type': reportType,
            'channels': channels,
            if (fromDate != null) 'from_date': _date(fromDate),
            if (toDate != null) 'to_date': _date(toDate),
            if (message != null) 'message': message,
          },
          cancelToken: cancelToken,
        );
        return DietitianReportPreview.fromJson(response.data ?? const {});
      });

  Future<ApiResult<SendToDietitianResult>> retryDietitianReport({
    required String reportId,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/dietitian-reports/$reportId/retry',
          cancelToken: cancelToken,
        );
        return SendToDietitianResult.fromJson(response.data ?? const {});
      });

  Future<ApiResult<Map<String, dynamic>>> submitSurvey(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) =>
      _postJson(
        '/survey',
        payload,
        idempotencyKey: payload['id']?.toString(),
        cancelToken: cancelToken,
      );

  Future<ApiResult<Map<String, dynamic>>> submitUsability(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) =>
      _postJson(
        '/usability',
        payload,
        idempotencyKey: payload['id']?.toString(),
        cancelToken: cancelToken,
      );

  Future<ApiResult<Map<String, dynamic>>> createResearchConsent(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) =>
      _postJson('/research/consents', payload, cancelToken: cancelToken);

  Future<ApiResult<Map<String, dynamic>>> withdrawResearchData(
    Map<String, dynamic> payload, {
    CancelToken? cancelToken,
  }) =>
      _postJson('/research/withdraw', payload, cancelToken: cancelToken);

  Future<ApiResult<Map<String, dynamic>>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
    CancelToken? cancelToken,
  }) =>
      _safeCall(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          path,
          data: payload,
          cancelToken: cancelToken,
          options: idempotencyKey == null
              ? null
              : Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
        return response.data ?? const {};
      });

  Future<ApiResult<T>> _safeCall<T>(Future<T> Function() operation) async {
    try {
      await _initialization;
      return ApiResult.success(await operation());
    } on ApiFailure catch (failure) {
      return ApiResult.error(failure);
    } on DioException catch (error) {
      return ApiResult.error(ApiFailure.fromDio(error));
    } on FormatException catch (error) {
      return ApiResult.error(ApiFailure(
        code: 'CONTRACT_MISMATCH',
        message: 'Sunucu yanıtı beklenen API sözleşmesiyle uyumlu değil.',
        kind: ApiFailureKind.contract,
        details: error.message,
      ));
    } catch (error) {
      return ApiResult.error(ApiFailure(
        code: 'UNEXPECTED_ERROR',
        message: 'Beklenmeyen bir istemci hatası oluştu.',
        kind: ApiFailureKind.unknown,
        details: error.toString(),
      ));
    }
  }

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}

final apiServiceProvider = Provider<ApiService>((ref) {
  final service = ApiService();
  unawaited(service.initialize());
  return service;
});
