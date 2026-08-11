import 'dart:convert';
import 'dart:io';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries a safe GET after a temporary server failure', () async {
    var calls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      calls += 1;
      request.response.statusCode = calls == 1 ? 503 : 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(calls == 1 ? {'detail': 'private'} : {'ok': true}),
      );
      await request.response.close();
    });
    final client = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}/'),
      delay: (_) async {},
    );

    final response = await client.send(
      const ApiRequest(method: ApiMethod.get, path: 'health'),
    );

    expect(calls, 2);
    expect(response.body, {'ok': true});
  });

  test('does not retry a POST or expose backend detail', () async {
    var calls = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      calls += 1;
      request.response.statusCode = 503;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'detail': 'database host'}));
      await request.response.close();
    });
    final client = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}/'),
    );

    await expectLater(
      client.send(
        const ApiRequest(method: ApiMethod.post, path: 'auth/token/refresh'),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'safe message',
          isNot(contains('database')),
        ),
      ),
    );
    expect(calls, 1);
  });

  test(
    'sends authorization and JSON body and accepts an empty response',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer token',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'name': 'Ada',
        });
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
      });
      final client = ApiClient(
        baseUri: Uri.parse('http://${server.address.host}:${server.port}/'),
      );

      final response = await client.send(
        const ApiRequest(
          method: ApiMethod.patch,
          path: 'profile',
          bearerToken: 'token',
          body: {'name': 'Ada'},
        ),
      );

      expect(response.body, isNull);
    },
  );

  test('maps unauthorized responses without exposing response detail', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'code': 'TOKEN_EXPIRED', 'detail': 'secret'}));
      await request.response.close();
    });
    final client = ApiClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}/'),
    );

    await expectLater(
      client.send(const ApiRequest(method: ApiMethod.get, path: 'profile')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiFailureKind.unauthorized)
            .having((e) => e.code, 'code', 'TOKEN_EXPIRED')
            .having((e) => e.message, 'message', isNot(contains('secret'))),
      ),
    );
  });

  test('rejects malformed and oversized responses', () async {
    for (final payload in [
      'not-json',
      '"primitive"',
      List.filled(1024 * 1024 + 1, 'x').join(),
    ]) {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.write(payload);
        await request.response.close();
      });
      final client = ApiClient(
        baseUri: Uri.parse('http://${server.address.host}:${server.port}/'),
      );
      await expectLater(
        client.send(const ApiRequest(method: ApiMethod.get, path: 'data')),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
      await server.close();
    }
  });
}
