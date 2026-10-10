import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_repository_provider.dart'
    as chat_repository_provider;
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/chat/chat_socket_provider.dart'
    as chat_socket_provider;
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:onetouch/screens/CommunityScreen_utils/report_dialog.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class LiveChatTab extends StatefulWidget {
  final int matchId;
  final ChatRepository? repository;
  final ChatSocket? socket;

  const LiveChatTab({
    super.key,
    required this.matchId,
    this.repository,
    this.socket,
  });

  @override
  State<LiveChatTab> createState() => _LiveChatTabState();
}

class _LiveChatTabState extends State<LiveChatTab> with WidgetsBindingObserver {
  static const _reconnectDelays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<FixtureChatMessage> _messages = [];
  ChatSocketSession? _socketSession;
  StreamSubscription<FixtureChatMessage>? _messagesSub;
  bool _isInitialized = false;
  String? _initError;
  int _requestId = 0;
  bool _isClosing = false;
  bool _chatUnavailable = false;
  bool _showTopFade = false;
  bool _canScroll = false;
  bool _scrollStateUpdateScheduled = false;
  bool _followLatest = true;
  bool _showLatestButton = false;
  bool _hasNewMessagesWhileReading = false;
  bool _reconnecting = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  String? _language;

  ChatRepository get _repository =>
      widget.repository ?? chat_repository_provider.chatRepository;

  ChatSocket get _socket => widget.socket ?? chat_socket_provider.chatSocket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scheduleScrollStateUpdate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_language == language) return;
    final firstVisit = _language == null;
    _language = language;
    if (firstVisit) {
      unawaited(_initChat());
    } else {
      unawaited(_restartChat());
    }
  }

  @override
  void didChangeMetrics() {
    if (_followLatest) _scrollToBottom(animate: false);
  }

  @override
  void didUpdateWidget(covariant LiveChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId ||
        oldWidget.repository != widget.repository ||
        oldWidget.socket != widget.socket) {
      unawaited(_restartChat());
    }
  }

  Future<void> _restartChat() async {
    _reconnectTimer?.cancel();
    // 이전 연결을 닫는 동안에도 다른 언어의 메시지나 입력을 보여주지 않아요.
    final closing = _closeChat();
    final requestId = _requestId;
    setState(() {
      _controller.clear();
      _messages.clear();
      _isInitialized = false;
      _initError = null;
      _showTopFade = false;
      _canScroll = false;
      _showLatestButton = false;
      _hasNewMessagesWhileReading = false;
      _followLatest = true;
      _reconnecting = false;
      _reconnectAttempt = 0;
      _chatUnavailable = false;
    });
    await closing;
    if (!mounted || requestId != _requestId) return;
    await _initChat();
  }

  Future<void> _initChat() async {
    final requestId = ++_requestId;
    final reconnecting = _isInitialized;
    final language = _language!;
    _isClosing = false;
    try {
      final session = await _socket.connect(widget.matchId, language: language);
      if (!mounted || requestId != _requestId) {
        await session.close();
        return;
      }
      _socketSession = session;
      _messagesSub = session.messages.listen(
        (message) {
          if (requestId == _requestId) _receiveLiveMessage(message);
        },
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );

      if (reconnecting && _messages.isNotEmpty) {
        // 재연결 사이에 빠진 메시지를 마지막 ID부터 순서대로 채워요.
        var afterId = _messages.last.messageId;
        while (true) {
          final page = await _repository.loadHistory(
            fixtureId: widget.matchId,
            language: language,
            afterId: afterId,
            limit: 100,
          );
          if (!mounted || requestId != _requestId) return;
          if (page.isEmpty) break;
          setState(() {
            _mergeMessages(page);
            if (!_followLatest) _hasNewMessagesWhileReading = true;
          });
          _scheduleScrollStateUpdate();
          if (_followLatest) _scrollToBottom();
          if (page.length < 100) break;
          afterId = page.last.messageId;
        }
      } else {
        final history = await _repository.loadHistory(
            fixtureId: widget.matchId, language: language);
        if (!mounted || requestId != _requestId) return;
        setState(() => _mergeMessages(history));
      }
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isInitialized = true;
        _initError = null;
        _reconnecting = false;
        _reconnectAttempt = 0;
      });
      if (_followLatest) _scrollToBottom(animate: !reconnecting);
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) return;
      await _closeChat(invalidateRequest: false);
      if (!mounted || requestId != _requestId) return;
      _handleConnectionFailure(error);
    }
  }

  Future<void> _retryInit() async {
    _reconnectTimer?.cancel();
    await _closeChat();
    if (!mounted) return;
    setState(() {
      _initError = null;
      _isInitialized = false;
      _reconnecting = false;
      _reconnectAttempt = 0;
    });
    await _initChat();
  }

  void _receiveLiveMessage(FixtureChatMessage message) {
    if (!mounted) return;
    setState(() {
      if (!_followLatest &&
          !_messages.any((item) => item.messageId == message.messageId)) {
        _hasNewMessagesWhileReading = true;
      }
      _mergeMessages([message]);
    });
    if (_followLatest) _scrollToBottom();
    _scheduleScrollStateUpdate();
  }

  void _mergeMessages(Iterable<FixtureChatMessage> incoming) {
    final byId = {
      for (final message in _messages) message.messageId: message,
      for (final message in incoming) message.messageId: message,
    };
    _messages
      ..clear()
      ..addAll(byId.values)
      ..sort((left, right) => left.messageId.compareTo(right.messageId));
  }

  void _handleSocketError(Object error) {
    if (!mounted || _isClosing || _reconnecting) return;
    unawaited(_disconnect(error));
  }

  void _handleSocketDone() {
    if (!mounted || _isClosing || _reconnecting || _initError != null) return;
    unawaited(_disconnect(
        const ChatSocketException(message: 'Fixture chat disconnected.')));
  }

  Future<void> _disconnect(Object error) async {
    _requestId++;
    _handleConnectionFailure(error);
    await _closeChat(invalidateRequest: false);
  }

  void _handleConnectionFailure(Object error) {
    final code = error is ChatSocketException ? error.closeCode : null;
    final text = error.toString();
    // 서버가 명시적으로 거절한 연결은 다시 시도해도 복구되지 않아요.
    final terminal = (code != null && code >= 4000 && code < 5000) ||
        RegExp(r'status 4\d\d\b').hasMatch(text);
    if (terminal) {
      _reconnectTimer?.cancel();
      setState(() {
        _reconnecting = false;
        _chatUnavailable = _isChatUnavailable(error);
        _initError = _friendlyError(error);
      });
      return;
    }
    setState(() => _reconnecting = true);
    final delay = _reconnectDelays[
        _reconnectAttempt.clamp(0, _reconnectDelays.length - 1)];
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (mounted) unawaited(_initChat());
    });
  }

  bool _isChatUnavailable(Object error) => error is ChatSocketException
      ? error.isUnavailable
      : error.toString().contains('status 410');

  String _friendlyError(Object error) {
    if (_isChatUnavailable(error)) {
      return tr(context, 'Live chat is only available during the match.');
    }
    if (error is ChatSocketException) {
      if (error.isUnauthorized) {
        return tr(context, 'Your session expired. Please sign in again.');
      }
      if (error.isForbidden) {
        return tr(context,
            'Chat is available when you follow either team in this match.');
      }
      return error.message;
    }
    final text = error.toString();
    if (text.contains('status 401')) {
      return tr(context, 'Your session expired. Please sign in again.');
    }
    if (text.contains('status 403')) {
      return tr(context,
          'Chat is available when you follow either team in this match.');
    }
    return tr(context, 'Please check your connection and try again.');
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _followLatest && _scrollController.hasClients) {
        _scheduleScrollStateUpdate();
        final target = _scrollController.position.maxScrollExtent;
        if (animate) {
          unawaited(_scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ));
        } else {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  bool _handleUserScroll(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      // 손가락으로 읽던 위치를 움직이는 동안에는 최신 메시지로 따라가지 않아요.
      _followLatest = false;
    } else if (notification is ScrollEndNotification) {
      _followLatest = notification.metrics.extentAfter <= 48;
      if (_followLatest) {
        _hasNewMessagesWhileReading = false;
        _scheduleScrollStateUpdate();
      }
    }
    return false;
  }

  void _scheduleScrollStateUpdate() {
    if (_scrollStateUpdateScheduled) return;
    _scrollStateUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollStateUpdateScheduled = false;
      if (!mounted) return;
      final canScroll = _scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0;
      final showFade = canScroll && _scrollController.position.pixels > 1;
      final remaining = _scrollController.hasClients
          ? _scrollController.position.extentAfter
          : 0.0;
      final showLatestButton = canScroll &&
          (remaining > _scrollController.position.viewportDimension ||
              (_hasNewMessagesWhileReading && remaining > 1));
      if (canScroll != _canScroll ||
          showFade != _showTopFade ||
          showLatestButton != _showLatestButton) {
        setState(() {
          _canScroll = canScroll;
          _showTopFade = showFade;
          _showLatestButton = showLatestButton;
        });
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final session = _socketSession;
    if (text.isEmpty || session == null || !_isInitialized) return;
    try {
      await session.send(text);
      _controller.clear();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(error))),
      );
    }
  }

  void _showContextMenu(
      BuildContext context, Offset position, FixtureChatMessage msg) {
    final isMe = msg.isMine;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: isDark ? AppPalette.lightGrey : AppPalette.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!isMe)
          PopupMenuItem(
            child: Row(
              children: [
                Icon(Icons.outlined_flag, color: foreground, size: 18),
                const SizedBox(width: 10),
                Text(tr(context, 'Report'), style: Body1.style),
              ],
            ),
            onTap: () => _reportMessage(msg),
          ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.copy_outlined, color: foreground, size: 18),
              const SizedBox(width: 10),
              Text(tr(context, 'Copy Text'), style: Body1.style),
            ],
          ),
          onTap: () => Clipboard.setData(ClipboardData(text: msg.text)),
        ),
      ],
    );
  }

  Future<void> _reportMessage(FixtureChatMessage msg) async {
    if (!mounted) return;
    await showReportDialog(
      context,
      targetLabel: 'message',
      onSubmit: (reason) => _repository.reportMessage(
        messageId: msg.messageId,
        reason: reason,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    unawaited(_closeChat());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _closeChat({bool invalidateRequest = true}) async {
    if (invalidateRequest) _requestId++;
    _isClosing = true;
    final subscription = _messagesSub;
    final session = _socketSession;
    _messagesSub = null;
    _socketSession = null;
    final cleanup = <Future<void>>[];
    if (subscription != null) cleanup.add(subscription.cancel());
    if (session != null) cleanup.add(session.close());
    await Future.wait(cleanup);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  _chatUnavailable ? Icons.chat_bubble_outline : Icons.wifi_off,
                  color: appColors.mutedForeground,
                  size: 40),
              const SizedBox(height: 16),
              Text(
                  tr(
                      context,
                      _chatUnavailable
                          ? 'Chat unavailable'
                          : 'Couldn\'t connect to chat'),
                  style: Body1.style,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.5,
                child: Text(_initError!,
                    style: Eyebrow.style, textAlign: TextAlign.center),
              ),
              if (!_chatUnavailable) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _retryInit,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        isDark ? AppPalette.lightGrey : AppPalette.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(tr(context, 'Retry'), style: Body2_b.style),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final pageBackground = mainPageBackground(context);
    final messageContent = !_isInitialized
        ? const SizedBox.expand(key: ValueKey('live-chat-loading-shell'))
        : _messages.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    key: const ValueKey('live-chat-empty-state'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/live_chat/conversation.svg',
                        key: ValueKey('live-chat-empty-icon'),
                        width: 56,
                        height: 56,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.onSurface,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(context, 'Be the first to chat!'),
                        key: const ValueKey('live-chat-empty-title'),
                        style: Heading4.style,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(context, 'Say hi and get the chat started.'),
                        key: const ValueKey('live-chat-empty-description'),
                        style: Body1.style.copyWith(height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  _scheduleScrollStateUpdate();
                  if (_followLatest) _scrollToBottom(animate: false);
                  return false;
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleUserScroll,
                  child: ListView.builder(
                    key: const ValueKey('live-chat-message-list'),
                    controller: _scrollController,
                    physics: _canScroll
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final messageIndex = index;
                      final msg = _messages[messageIndex];
                      final prevMsg =
                          messageIndex > 0 ? _messages[messageIndex - 1] : null;
                      final nextMsg = messageIndex + 1 < _messages.length
                          ? _messages[messageIndex + 1]
                          : null;
                      final showHeader = prevMsg == null ||
                          prevMsg.nicknameEn != msg.nicknameEn;
                      final continuesGroup = nextMsg != null &&
                          nextMsg.nicknameEn == msg.nicknameEn;

                      return GestureDetector(
                        onLongPressStart: (details) => _showContextMenu(
                          context,
                          details.globalPosition,
                          msg,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: nextMsg == null
                                ? 0
                                : continuesGroup
                                    ? 8
                                    : 16,
                          ),
                          child: _buildMessage(msg, showHeader),
                        ),
                      );
                    },
                  ),
                ),
              );

    return Column(
      children: [
        Expanded(
          child: Stack(
            key: const ValueKey('live-chat-message-viewport'),
            children: [
              Positioned.fill(child: messageContent),
              if (_showTopFade)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey('live-chat-top-fade'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            pageBackground,
                            pageBackground.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showLatestButton)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Center(
                      heightFactor: 1,
                      child: IconButton(
                        key: const ValueKey('live-chat-latest-button'),
                        tooltip: tr(context, 'Jump to latest messages'),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDark ? AppPalette.lightGrey : AppPalette.white,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          _followLatest = true;
                          _hasNewMessagesWhileReading = false;
                          _scrollToBottom();
                        },
                        icon:
                            const Icon(Icons.arrow_downward_rounded, size: 24),
                      )),
                ),
            ],
          ),
        ),
        if (_reconnecting)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(tr(context, 'Reconnecting to chat…'),
                style: Eyebrow.style),
          ),
        Container(
          key: const ValueKey('live-chat-composer'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          color: isDark ? const Color(0xFF272828) : AppPalette.white,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 43,
                  child: TextField(
                    key: const ValueKey('live-chat-input'),
                    controller: _controller,
                    style: Body1.style.copyWith(height: 1.3),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: tr(context, 'Type a message'),
                      hintStyle: Body1.style.copyWith(
                        color: appColors.mutedForeground,
                        height: 1.3,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: isDark
                          ? AppPalette.lightGrey
                          : AppPalette.lightGreyBox,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const ValueKey('live-chat-send-button'),
                onTap: _reconnecting ? null : _sendMessage,
                child: Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B92FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(FixtureChatMessage msg, bool showHeader) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = Text(
      msg.authorDeleted
          ? tr(context, 'Deleted user')
          : msg.displayAuthor(Localizations.localeOf(context).languageCode),
      style: Body2_b.style,
    );
    final time = Opacity(
      opacity: 0.5,
      child: Text(_timeString(msg), style: Eyebrow.style),
    );
    const gap = SizedBox(width: 8);
    return Column(
      crossAxisAlignment:
          msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment:
                msg.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: msg.isMine ? [time, gap, author] : [author, gap, time],
          ),
          const SizedBox(height: 8),
        ],
        Container(
          key: ValueKey('live-chat-message-${msg.messageId}'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.white,
            borderRadius: msg.isMine
                ? const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
          ),
          child: Text(msg.text, style: Body1.style),
        ),
      ],
    );
  }

  String _timeString(FixtureChatMessage message) {
    final local = message.createdAt.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    return '$hour:$minute $period';
  }
}
