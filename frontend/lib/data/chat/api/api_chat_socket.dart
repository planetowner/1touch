import 'dart:async';
import 'dart:convert';

import 'package:onetouch/data/chat/api/api_chat_mapper.dart';
import 'package:onetouch/data/chat/api/api_chat_response.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:web_socket_channel/status.dart' as socket_status;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef ChatSocketConnector = ChatSocketConnection Function(Uri uri);

abstract interface class ChatSocketConnection {
  Future<void> get ready;
  Stream<Object?> get stream;
  int? get closeCode;
  String? get closeReason;

  void add(Object data);
  Future<void> close([int? closeCode, String? closeReason]);
}

class ApiChatSocket implements ChatSocket {
  ApiChatSocket({
    required Uri apiBaseUri,
    String? sessionToken,
    String Function()? sessionTokenProvider,
    ChatSocketConnector? connector,
    Duration handshakeTimeout = const Duration(seconds: 10),
  })  : _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _sessionTokenProvider = sessionTokenProvider ?? (() => sessionToken!),
        _connector = connector ?? _WebSocketChannelConnection.connect,
        _handshakeTimeout = handshakeTimeout {
    if ((sessionToken == null) == (sessionTokenProvider == null)) {
      throw ArgumentError(
        'Provide exactly one of sessionToken or sessionTokenProvider.',
      );
    }
    if (sessionToken != null &&
        (sessionToken.trim().length < 40 || sessionToken.trim().length > 100)) {
      throw ArgumentError.value(
        sessionToken,
        'sessionToken',
        'Must contain between 40 and 100 characters',
      );
    }
  }

  final Uri _apiBaseUri;
  final String Function() _sessionTokenProvider;
  final ChatSocketConnector _connector;
  final Duration _handshakeTimeout;

  @override
  Future<ChatSocketSession> connect(int fixtureId) async {
    if (fixtureId < 1) {
      throw RangeError.value(fixtureId, 'fixtureId', 'Must be positive');
    }
    final sessionToken = _sessionTokenProvider().trim();
    if (sessionToken.length < 40 || sessionToken.length > 100) {
      throw StateError('A valid authenticated session is required for chat.');
    }
    final httpUri = _apiBaseUri.resolve('fixtures/$fixtureId/chat');
    final socketUri = httpUri.replace(
      scheme: switch (httpUri.scheme) {
        'https' => 'wss',
        'http' => 'ws',
        _ => throw FormatException(
            'Expected an HTTP(S) API URI for fixture chat.',
          ),
      },
    );
    final session = _ApiChatSocketSession(
      connection: _connector(socketUri),
      fixtureId: fixtureId,
      sessionToken: sessionToken,
      apiBaseUri: _apiBaseUri,
      handshakeTimeout: _handshakeTimeout,
    );
    await session.open();
    return session;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}

class _ApiChatSocketSession implements ChatSocketSession {
  _ApiChatSocketSession({
    required ChatSocketConnection connection,
    required this.fixtureId,
    required this.sessionToken,
    required this.apiBaseUri,
    required this.handshakeTimeout,
  }) : _connection = connection;

  final ChatSocketConnection _connection;
  final int fixtureId;
  final String sessionToken;
  final Uri apiBaseUri;
  final Duration handshakeTimeout;
  final StreamController<FixtureChatMessage> _messages =
      StreamController.broadcast();
  final Completer<void> _serverReady = Completer<void>();
  StreamSubscription<Object?>? _subscription;
  bool _opened = false;
  bool _closedLocally = false;
  bool _terminalErrorSent = false;

  @override
  Stream<FixtureChatMessage> get messages => _messages.stream;

  Future<void> open() async {
    try {
      await _connection.ready;
      _subscription = _connection.stream.listen(
        _handleFrame,
        onError: _handleTransportError,
        onDone: _handleDone,
        cancelOnError: false,
      );
      _connection.add(jsonEncode({'token': sessionToken}));
      await _serverReady.future.timeout(handshakeTimeout);
      _opened = true;
    } on Object {
      _closedLocally = true;
      await _subscription?.cancel();
      await _closeConnection(socket_status.goingAway, 'Handshake failed');
      rethrow;
    }
  }

  void _handleFrame(Object? frame) {
    try {
      if (frame is! String) {
        throw const FormatException('Expected a JSON text frame from chat.');
      }
      final decoded = jsonDecode(frame);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a chat frame object.');
      }
      final type = decoded['type'];
      if (type == 'ready') {
        if (_serverReady.isCompleted || decoded['fixture_id'] != fixtureId) {
          throw const FormatException('Invalid fixture chat ready frame.');
        }
        _serverReady.complete();
        return;
      }
      if (type != 'message' || !_serverReady.isCompleted) {
        throw FormatException('Unexpected fixture chat frame type: $type.');
      }
      final message = chatMessageFromApiResponse(
        ApiChatMessageResponse.fromJson(decoded),
        apiBaseUri: apiBaseUri,
      );
      if (message.fixtureId != fixtureId) {
        throw FormatException(
          'Expected fixture_id $fixtureId but received ${message.fixtureId}.',
        );
      }
      _messages.add(message);
    } on Object catch (error, stackTrace) {
      _terminateWithError(error, stackTrace);
    }
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    _terminateWithError(
      ChatSocketException(message: 'Fixture chat connection failed: $error'),
      stackTrace,
    );
  }

  void _handleDone() {
    if (_closedLocally) {
      unawaited(_messages.close());
      return;
    }
    final error = _exceptionForClose(
      _connection.closeCode,
      _connection.closeReason,
    );
    if (!_serverReady.isCompleted) {
      _serverReady.completeError(error);
    } else if (!_terminalErrorSent) {
      _terminalErrorSent = true;
      _messages.addError(error);
    }
    unawaited(_messages.close());
  }

  void _terminateWithError(Object error, StackTrace stackTrace) {
    if (!_serverReady.isCompleted) {
      _serverReady.completeError(error, stackTrace);
    } else if (!_terminalErrorSent) {
      _terminalErrorSent = true;
      _messages.addError(error, stackTrace);
    }
    unawaited(
      _closeConnection(socket_status.protocolError, 'Invalid chat frame'),
    );
  }

  @override
  Future<void> send(String text) async {
    if (!_opened || _closedLocally) {
      throw StateError('Fixture chat is not connected.');
    }
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.length > maxChatMessageLength) {
      throw ArgumentError.value(
        text,
        'text',
        'Must contain between 1 and $maxChatMessageLength characters',
      );
    }
    _connection.add(jsonEncode({'text': normalized}));
  }

  @override
  Future<void> close() async {
    _closedLocally = true;
    await _subscription?.cancel();
    await _closeConnection(socket_status.normalClosure, 'Screen closed');
    await _messages.close();
  }

  Future<void> _closeConnection(int code, String reason) async {
    try {
      await _connection.close(code, reason);
    } on Object {
      // Closing is best effort after a transport or protocol failure.
    }
  }
}

ChatSocketException _exceptionForClose(int? code, String? reason) {
  final message = switch (code) {
    4400 => 'The chat server rejected an invalid message.',
    4401 => 'Your chat session has expired. Please sign in again.',
    4403 => 'Chat is limited to supporters of the participating teams.',
    _ => 'Fixture chat disconnected.',
  };
  return ChatSocketException(
    message: message,
    closeCode: code,
    closeReason: reason,
  );
}

class _WebSocketChannelConnection implements ChatSocketConnection {
  _WebSocketChannelConnection(this._channel);

  factory _WebSocketChannelConnection.connect(Uri uri) =>
      _WebSocketChannelConnection(WebSocketChannel.connect(uri));

  final WebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;

  @override
  void add(Object data) => _channel.sink.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    await _channel.sink.close(closeCode, closeReason);
  }
}
