import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session_service.dart';

/// Central API Client with pretty console logging for all HTTP requests,
/// responses, status codes, headers, and formatted JSON bodies.
class ApiClient {
  ApiClient._();

  static const Duration defaultTimeout = Duration(seconds: 15);
  static final http.Client client = _LoggingClient();

  static Future<http.Response> _executeWithRetry(
    Future<http.Response> Function(Map<String, String>? headers) action,
    Uri url,
    Map<String, String>? headers,
  ) async {
    final res = await action(headers);
    final isAuthUrl = url.path.contains('/auth/login') ||
        url.path.contains('/auth/refresh') ||
        url.path.contains('/auth/register');

    if (res.statusCode == 401 &&
        !isAuthUrl &&
        headers != null &&
        headers.containsKey('Authorization')) {
      final newToken = await SessionService().refreshAccessToken();
      if (newToken != null && newToken.isNotEmpty) {
        final newHeaders = Map<String, String>.from(headers);
        newHeaders['Authorization'] = 'Bearer $newToken';
        return await action(newHeaders);
      }
    }
    return res;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _executeWithRetry((h) => client.get(url, headers: h), url, headers);

  static Future<http.Response> post(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _executeWithRetry(
          (h) => client.post(url, headers: h, body: body, encoding: encoding),
          url,
          headers);

  static Future<http.Response> put(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _executeWithRetry(
          (h) => client.put(url, headers: h, body: body, encoding: encoding),
          url,
          headers);

  static Future<http.Response> patch(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _executeWithRetry(
          (h) => client.patch(url, headers: h, body: body, encoding: encoding),
          url,
          headers);

  static Future<http.Response> delete(Uri url,
          {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
      _executeWithRetry(
          (h) => client.delete(url, headers: h, body: body, encoding: encoding),
          url,
          headers);

  static Future<http.Response> head(Uri url, {Map<String, String>? headers}) =>
      client.head(url, headers: headers);

  static Future<http.StreamedResponse> sendRequest(http.BaseRequest request) =>
      client.send(request);
}

class _LoggingClient extends http.BaseClient {
  final http.Client _inner;
  _LoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    const timeout = ApiClient.defaultTimeout;
    if (!kDebugMode) {
      return _inner.send(request).timeout(timeout);
    }

    final stopwatch = Stopwatch()..start();
    _logRequest(request);

    try {
      final streamedResponse = await _inner.send(request).timeout(timeout);
      final responseData = await streamedResponse.stream.toBytes();
      stopwatch.stop();

      _logResponse(
        method: request.method,
        url: request.url.toString(),
        statusCode: streamedResponse.statusCode,
        reasonPhrase: streamedResponse.reasonPhrase ?? '',
        elapsedMs: stopwatch.elapsedMilliseconds,
        headers: streamedResponse.headers,
        bodyBytes: responseData,
      );

      return http.StreamedResponse(
        Stream.value(responseData),
        streamedResponse.statusCode,
        contentLength: responseData.length,
        request: streamedResponse.request,
        headers: streamedResponse.headers,
        isRedirect: streamedResponse.isRedirect,
        persistentConnection: streamedResponse.persistentConnection,
        reasonPhrase: streamedResponse.reasonPhrase,
      );
    } catch (e) {
      stopwatch.stop();
      _logError(
        method: request.method,
        url: request.url.toString(),
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      rethrow;
    }
  }

  void _logRequest(http.BaseRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('┌─── 🌐 [HTTP REQUEST] ${request.method} ${request.url}');

    // Headers
    if (request.headers.isNotEmpty) {
      buffer.writeln('│ Headers:');
      request.headers.forEach((key, val) {
        final safeVal = (key.toLowerCase() == 'authorization' && val.length > 25)
            ? '${val.substring(0, 15)}...${val.substring(val.length - 6)}'
            : val;
        buffer.writeln('│   $key: $safeVal');
      });
    }

    // Body
    if (request is http.Request && request.body.isNotEmpty) {
      buffer.writeln('│ Body:');
      final formatted = _formatBody(request.body);
      for (final line in formatted.split('\n')) {
        buffer.writeln('│   $line');
      }
    } else if (request is http.MultipartRequest) {
      if (request.fields.isNotEmpty) {
        buffer.writeln('│ Multipart Fields:');
        request.fields.forEach((k, v) => buffer.writeln('│   $k: $v'));
      }
      if (request.files.isNotEmpty) {
        buffer.writeln('│ Multipart Files:');
        for (final f in request.files) {
          buffer.writeln('│   ${f.field}: ${f.filename} (${f.length} bytes)');
        }
      }
    }

    buffer.writeln('└──────────────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  void _logResponse({
    required String method,
    required String url,
    required int statusCode,
    required String reasonPhrase,
    required int elapsedMs,
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) {
    final buffer = StringBuffer();
    final statusIcon = statusCode >= 200 && statusCode < 300
        ? '🟢'
        : (statusCode >= 400 ? '🔴' : '🟡');

    buffer.writeln('┌─── $statusIcon [HTTP RESPONSE] $statusCode $reasonPhrase for $method $url ($elapsedMs ms)');

    if (bodyBytes.isNotEmpty) {
      try {
        final bodyString = utf8.decode(bodyBytes);
        buffer.writeln('│ Body:');
        final formatted = _formatBody(bodyString);
        if (formatted.length > 4000) {
          final lines = formatted.split('\n');
          final preview = lines.take(30).join('\n│   ');
          buffer.writeln('│   $preview');
          buffer.writeln('│   ... [Truncated ${formatted.length - preview.length} chars]');
        } else {
          for (final line in formatted.split('\n')) {
            buffer.writeln('│   $line');
          }
        }
      } catch (_) {
        buffer.writeln('│ Body: <Binary data: ${bodyBytes.length} bytes>');
      }
    } else {
      buffer.writeln('│ Body: <Empty>');
    }

    buffer.writeln('└──────────────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  void _logError({
    required String method,
    required String url,
    required int elapsedMs,
    required Object error,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('┌─── ❌ [HTTP ERROR] $method $url ($elapsedMs ms)');
    buffer.writeln('│ Error: $error');
    buffer.writeln('└──────────────────────────────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  String _formatBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }
}
