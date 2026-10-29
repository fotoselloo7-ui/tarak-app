import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? validationErrors;

  const AppException({
    required this.message,
    this.statusCode,
    this.validationErrors,
  });

  factory AppException.fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const AppException(
          message: 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
          statusCode: null,
        );

      case DioExceptionType.badResponse:
        final response = error.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        // Laravel's default 429 body is "Too Many Attempts.".
        // Handle rate limiting before generic server messages so users always
        // get a clear localized message instead of the raw framework string.
        if (statusCode == 429) {
          final retryAfter = response?.headers.value('retry-after');
          final seconds = int.tryParse(retryAfter ?? '');
          return AppException(
            message: seconds != null && seconds > 0
                ? 'Çok fazla deneme yapıldı. $seconds saniye sonra tekrar deneyin.'
                : 'Çok fazla deneme yapıldı. Lütfen kısa bir süre bekleyip tekrar deneyin.',
            statusCode: 429,
          );
        }

        if (data is Map<String, dynamic>) {
          // Laravel validation errors (422)
          if (statusCode == 422 && data['errors'] is Map) {
            final rawErrors = data['errors'] as Map;
            final validationErrors = <String, List<String>>{};
            final errorMessages = <String>[];

            rawErrors.forEach((key, val) {
              if (val is List) {
                final list = val.map((e) => e.toString()).toList();
                validationErrors[key.toString()] = list;
                errorMessages.addAll(list);
              } else if (val != null) {
                final str = val.toString();
                validationErrors[key.toString()] = [str];
                errorMessages.add(str);
              }
            });

            return AppException(
              message: errorMessages.isNotEmpty
                  ? errorMessages.first
                  : (data['message']?.toString() ?? 'Girdiğiniz bilgileri kontrol edin.'),
              statusCode: statusCode,
              validationErrors: validationErrors,
            );
          }

          if (data['message'] != null && data['message'].toString().isNotEmpty) {
            return AppException(
              message: data['message'].toString(),
              statusCode: statusCode,
            );
          }
        }

        switch (statusCode) {
          case 401:
            return const AppException(
              message: 'Oturum süreniz doldu, lütfen tekrar giriş yapın.',
              statusCode: 401,
            );
          case 403:
            return const AppException(
              message: 'Bu işlem için yetkiniz bulunmuyor.',
              statusCode: 403,
            );
          case 404:
            return const AppException(
              message: 'İstenen kaynak bulunamadı.',
              statusCode: 404,
            );
          case 429:
            return const AppException(
              message: 'Çok fazla istek gönderildi. Lütfen biraz bekleyin.',
              statusCode: 429,
            );
          case 500:
          case 502:
          case 503:
            return const AppException(
              message: 'Sunucu hatası oluştu. Lütfen daha sonra tekrar deneyin.',
              statusCode: 500,
            );
          default:
            return AppException(
              message: 'Bir hata oluştu (Kod: $statusCode).',
              statusCode: statusCode,
            );
        }

      case DioExceptionType.cancel:
        return const AppException(
          message: 'İşlem iptal edildi.',
        );

      default:
        return const AppException(
          message: 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.',
        );
    }
  }

  @override
  String toString() => message;
}
