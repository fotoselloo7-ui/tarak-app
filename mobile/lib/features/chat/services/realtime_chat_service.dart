import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import '../../../../core/config/env_config.dart';
import '../models/chat_message_model.dart';

class RealtimeChatService {
  PusherChannelsClient? _client;
  String? _authToken;
  bool _isConnected = false;
  bool _hasConnectedOnce = false;

  final Map<int, PrivateChannel> _conversationChannels = {};
  final Map<int, List<StreamSubscription>> _channelSubscriptions = {};

  final StreamController<void> _reconnectController =
      StreamController<void>.broadcast();

  Stream<void> get onReconnected => _reconnectController.stream;
  bool get isConnected => _isConnected;

  /// Initialize or update the Pusher/Reverb WebSocket client with Sanctum token.
  void init({
    required String token,
    String? host,
    int? port,
    String? scheme,
    String? key,
  }) {
    if (_authToken == token && _client != null) {
      return;
    }

    // Clean up previous client if token changed
    disconnect();

    _authToken = token;
    final wsHost = host ?? EnvConfig.reverbHost;
    final wsPort = port ?? EnvConfig.reverbPort;
    final wsScheme = scheme ?? EnvConfig.reverbScheme;
    final wsKey = key ?? EnvConfig.reverbAppKey;

    try {
      final options = PusherChannelsOptions.fromHost(
        scheme: wsScheme,
        host: wsHost,
        port: wsPort,
        key: wsKey,
        shouldSupplyMetadataQueries: true,
      );

      _client = PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) async {
          _isConnected = false;
          refresh();
        },
      );

      _client?.onConnectionEstablished.listen((_) {
        _isConnected = true;
        if (_hasConnectedOnce) {
          // Reconnected after a drop -> trigger REST reconciliation
          _reconnectController.add(null);
        }
        _hasConnectedOnce = true;
      });

      _client?.connect();
    } catch (_) {
      // In testing or environments without websocket connectivity,
      // fail gracefully without crashing REST operations.
      _client = null;
      _isConnected = false;
    }
  }

  /// Subscribe to a private conversation channel and receive realtime messages.
  /// Channel name: private-conversation.{conversationId}
  /// Broadcast event: MessageCreated
  void Function() subscribeToConversation(
    int conversationId,
    void Function(ChatMessageModel message) onMessageCreated,
  ) {
    if (_client == null || _authToken == null) {
      return () {};
    }

    final channelName = 'private-conversation.$conversationId';

    // If channel already subscribed, add listener
    PrivateChannel channel;
    if (_conversationChannels.containsKey(conversationId)) {
      channel = _conversationChannels[conversationId]!;
    } else {
      try {
        final authDelegate =
            EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
          authorizationEndpoint: Uri.parse(EnvConfig.broadcastingAuthUrl),
          headers: {
            'Authorization': 'Bearer $_authToken',
            'Accept': 'application/json',
          },
        );

        channel = _client!.privateChannel(
          channelName,
          authorizationDelegate: authDelegate,
        );

        _conversationChannels[conversationId] = channel;
        channel.subscribe();
      } catch (_) {
        return () {};
      }
    }

    final subs = <StreamSubscription>[];

    void handleEvent(ChannelReadEvent event) {
      try {
        final dynamic raw = event.data;
        Map<String, dynamic>? json;
        if (raw is Map<String, dynamic>) {
          json = raw;
        } else if (raw is String && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        }

        if (json != null) {
          // Payload might be wrapped in { "message": { ... } } or direct
          final msgData = json['message'] is Map<String, dynamic>
              ? json['message'] as Map<String, dynamic>
              : json;

          final msg = ChatMessageModel.fromJson(msgData);
          onMessageCreated(msg);
        }
      } catch (_) {
        // Safe parse fallback - no logging of message content
      }
    }

    try {
      // Bind both standard and dot-prefixed event names
      subs.add(channel.bind('MessageCreated').listen(handleEvent));
      subs.add(channel.bind('.MessageCreated').listen(handleEvent));
    } catch (_) {}

    _channelSubscriptions.putIfAbsent(conversationId, () => []).addAll(subs);

    // Return unbind/unsubscribe callback
    return () {
      for (final sub in subs) {
        sub.cancel();
      }
      _channelSubscriptions[conversationId]?.removeWhere(subs.contains);

      // If no listeners left for this conversation, leave channel
      if (_channelSubscriptions[conversationId]?.isEmpty ?? true) {
        _channelSubscriptions.remove(conversationId);
        try {
          channel.unsubscribe();
        } catch (_) {}
        _conversationChannels.remove(conversationId);
      }
    };
  }

  /// Leave all channels and disconnect WebSocket.
  void disconnect() {
    for (final subs in _channelSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _channelSubscriptions.clear();

    for (final channel in _conversationChannels.values) {
      try {
        channel.unsubscribe();
      } catch (_) {}
    }
    _conversationChannels.clear();

    try {
      _client?.disconnect();
    } catch (_) {}

    _client = null;
    _authToken = null;
    _isConnected = false;
    _hasConnectedOnce = false;
  }

  void dispose() {
    disconnect();
    _reconnectController.close();
  }
}
