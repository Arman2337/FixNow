import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';

abstract class ChatRepository {
  Future<({List<ChatMessage> messages, bool canSend})> fetchMessages(
    String bookingId,
  );

  Future<ChatMessage> sendMessage(
    String bookingId,
    String messageText, {
    String? clientMessageId,
  });
}

class HttpChatRepository implements ChatRepository {
  HttpChatRepository({
    required ApiTransport api,
    required Future<String?> Function() accessToken,
    String? Function()? currentUserId,
  }) : _api = api,
       _accessToken = accessToken,
       _currentUserId = currentUserId;

  final ApiTransport _api;
  final Future<String?> Function() _accessToken;
  final String? Function()? _currentUserId;

  Future<String> _token() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to access chat.',
      );
    }
    return token;
  }

  @override
  Future<({List<ChatMessage> messages, bool canSend})> fetchMessages(
    String bookingId,
  ) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.get,
        path: 'bookings/$bookingId/messages',
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;
    final rows = body?['messages'];
    final canSend = body?['canSend'] as bool? ?? true;

    if (rows is! List) {
      return (messages: <ChatMessage>[], canSend: canSend);
    }

    final userId = _currentUserId?.call();
    final list = rows.map((raw) {
      return ChatMessage.fromJson(
        Map<String, Object?>.from(raw as Map),
        currentUserId: userId,
      );
    }).toList();

    return (messages: list, canSend: canSend);
  }

  @override
  Future<ChatMessage> sendMessage(
    String bookingId,
    String messageText, {
    String? clientMessageId,
  }) async {
    final response = await _api.send(
      ApiRequest(
        method: ApiMethod.post,
        path: 'bookings/$bookingId/messages',
        body: {
          'messageText': messageText,
          'clientMessageId': ?clientMessageId,
        },
        bearerToken: await _token(),
      ),
    );

    final body = response.body is Map<String, dynamic>
        ? response.body! as Map<String, dynamic>
        : null;

    if (body == null) {
      throw const ApiException(
        ApiFailureKind.invalidResponse,
        'Could not send message.',
      );
    }

    return ChatMessage.fromJson(
      Map<String, Object?>.from(body),
      overrideIsMe: true,
    );
  }
}
