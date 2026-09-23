import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_repository_provider.dart'
    as chat_repository_provider;
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/chat/chat_socket_provider.dart'
    as chat_socket_provider;
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/profile/current_user_repository_provider.dart'
    as current_user_provider;
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:onetouch/screens/CommunityScreen_utils/ReportDialog.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class LiveChatTab extends StatefulWidget {
  final int matchId;
  final ChatRepository? repository;
  final ChatSocket? socket;
  final CurrentUserRepository? currentUserRepository;

  const LiveChatTab({
    super.key,
    required this.matchId,
    this.repository,
    this.socket,
    this.currentUserRepository,
  });

  @override
  State<LiveChatTab> createState() => _LiveChatTabState();
}

class _LiveChatTabState extends State<LiveChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<FixtureChatMessage> _messages = [];
  ChatSocketSession? _socketSession;
  StreamSubscription<FixtureChatMessage>? _messagesSub;
  int? _currentUserId;
  bool _isInitialized = false;
  String? _initError;
  int _requestId = 0;
  bool _isClosing = false;

  ChatRepository get _repository =>
      widget.repository ?? chat_repository_provider.chatRepository;

  ChatSocket get _socket => widget.socket ?? chat_socket_provider.chatSocket;

  CurrentUserRepository get _currentUserRepository =>
      widget.currentUserRepository ??
      current_user_provider.currentUserRepository;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void didUpdateWidget(covariant LiveChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId ||
        oldWidget.repository != widget.repository ||
        oldWidget.socket != widget.socket ||
        oldWidget.currentUserRepository != widget.currentUserRepository) {
      unawaited(_restartChat());
    }
  }

  Future<void> _restartChat() async {
    await _closeChat();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _currentUserId = null;
      _isInitialized = false;
      _initError = null;
    });
    await _initChat();
  }

  Future<void> _initChat() async {
    final requestId = ++_requestId;
    _isClosing = false;
    try {
      final session = await _socket.connect(widget.matchId);
      if (!mounted || requestId != _requestId) {
        await session.close();
        return;
      }
      _socketSession = session;
      _messagesSub = session.messages.listen(
        _receiveLiveMessage,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
      );

      final results = await Future.wait<Object>([
        _repository.loadHistory(fixtureId: widget.matchId),
        _currentUserRepository.load(),
      ]);
      if (!mounted || requestId != _requestId) return;
      final history = results[0] as List<FixtureChatMessage>;
      final currentUser = results[1] as CurrentUserProfile;
      setState(() {
        _mergeMessages(history);
        _currentUserId = currentUser.userId;
        _isInitialized = true;
        _initError = null;
      });
      _scrollToBottom();
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) return;
      await _closeChat(invalidateRequest: false);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isInitialized = false;
        _initError = _friendlyError(error);
      });
    }
  }

  Future<void> _retryInit() async {
    await _closeChat();
    if (!mounted) return;
    setState(() {
      _initError = null;
      _isInitialized = false;
    });
    await _initChat();
  }

  void _receiveLiveMessage(FixtureChatMessage message) {
    if (!mounted) return;
    setState(() => _mergeMessages([message]));
    _scrollToBottom();
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
    if (!mounted || _isClosing) return;
    _requestId++;
    setState(() => _initError = _friendlyError(error));
  }

  void _handleSocketDone() {
    if (!mounted || _isClosing || _initError != null) return;
    _requestId++;
    setState(
        () => _initError = tr(context, 'Chat disconnected. Please try again.'));
  }

  String _friendlyError(Object error) {
    if (error is ChatSocketException) {
      if (error.isUnauthorized) {
        return tr(context, 'Your session expired. Please sign in again.');
      }
      if (error.isForbidden) {
        return tr(context,
            'Chat is only available to supporters of the participating teams.');
      }
      return error.message;
    }
    final text = error.toString();
    if (text.contains('status 401')) {
      return tr(context, 'Your session expired. Please sign in again.');
    }
    if (text.contains('status 403')) {
      return tr(context,
          'Chat is only available to supporters of the participating teams.');
    }
    return tr(context, 'Please check your connection and try again.');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
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
    final isMe = msg.userId == _currentUserId;
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
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, color: appColors.mutedForeground, size: 40),
              const SizedBox(height: 16),
              Text(tr(context, 'Couldn\'t connect to chat'),
                  style: Body1.style, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.5,
                child: Text(_initError!,
                    style: Eyebrow.style, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _retryInit,
                style: TextButton.styleFrom(
                  backgroundColor:
                      isDark ? AppPalette.lightGrey : AppPalette.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(tr(context, 'Retry'), style: Body2_b.style),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Text(tr(context, 'Be the first to chat!'),
                          style: Body1.style),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.userId == _currentUserId;
                      final prevMsg = index > 0 ? _messages[index - 1] : null;
                      final showHeader =
                          prevMsg == null || prevMsg.username != msg.username;

                      return GestureDetector(
                        onLongPressStart: (details) => _showContextMenu(
                          context,
                          details.globalPosition,
                          msg,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: isMe
                              ? _buildMyMessage(msg, showHeader)
                              : _buildOtherMessage(msg, showHeader),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: isDark ? Colors.black : AppPalette.white,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppPalette.lightGrey
                          : AppPalette.lightGreyBox,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: foreground, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppPalette.darkGrey
                            : AppPalette.lightGreyBox,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: Body1.style,
                        decoration: InputDecoration(
                          hintText: tr(context, 'Type a message'),
                          hintStyle: Body1.style.copyWith(
                            color: appColors.mutedForeground,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2979FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherMessage(FixtureChatMessage msg, bool showHeader) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Text(
                  msg.authorDeleted
                      ? tr(context, 'Deleted user')
                      : msg.displayUsername,
                  style: Body2_b.style),
              const SizedBox(width: 8),
              Opacity(
                opacity: 0.5,
                child: Text(_timeString(msg), style: Eyebrow.style),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(msg.text, style: Body1.style),
        ),
      ],
    );
  }

  Widget _buildMyMessage(FixtureChatMessage msg, bool showHeader) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Opacity(
                opacity: 0.5,
                child: Text(_timeString(msg), style: Eyebrow.style),
              ),
              const SizedBox(width: 8),
              Text(
                  msg.authorDeleted
                      ? tr(context, 'Deleted user')
                      : msg.displayUsername,
                  style: Body2_b.style),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
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
