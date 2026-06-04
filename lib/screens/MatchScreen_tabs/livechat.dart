import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/chatmsg.dart';


class LiveChatTab extends StatefulWidget {
  final int matchId;

  const LiveChatTab({super.key, required this.matchId});

  @override
  State<LiveChatTab> createState() => _LiveChatTabState();
}

class _LiveChatTabState extends State<LiveChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];

  User? _firebaseUser;
  String _myUsername = '';
  bool _isInitialized = false;

  late DatabaseReference _messagesRef;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Anonymous Firebase Auth
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _firebaseUser = auth.currentUser;

    // Assign username
    _myUsername = await _fetchUsername();

    // Setup RTDB listener
    _messagesRef = FirebaseDatabase.instance
        .ref('chats/${widget.matchId}/messages');

    _messagesRef.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;
      final msg = ChatMessage.fromSnapshot(event.snapshot.key ?? '', data);
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<String> _fetchUsername() async {
    // TODO: replace with real backend call → GET /players/random
    // final name = await ApiService.instance.getRandomPlayerName();
    // final number = Random().nextInt(9000) + 1000;
    // return '${name}_$number';

    final mockNames = ['Mbappe', 'Haaland', 'Bellingham', 'Vinicius', 'Pedri', 'Salah', 'Saka'];
    final name = mockNames[DateTime.now().millisecond % mockNames.length];
    final number = (DateTime.now().microsecond % 9000) + 1000;
    return '${name}_$number';
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
    if (text.isEmpty || _firebaseUser == null) return;
    _controller.clear();

    await _messagesRef.push().set({
      'userId': _firebaseUser!.uid,
      'username': _myUsername,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });
  }

  void _showContextMenu(BuildContext context, Offset position, ChatMessage msg) {
    final isMe = msg.userId == _firebaseUser?.uid;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      color: const Color(0xFF3D3D3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!isMe)
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.outlined_flag, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Report', style: Body1.style),
              ],
            ),
            onTap: () => _reportMessage(msg),
          ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Copy Text', style: Body1.style),
            ],
          ),
          onTap: () => Clipboard.setData(ClipboardData(text: msg.text)),
        ),
      ],
    );
  }

  Future<void> _reportMessage(ChatMessage msg) async {
    // TODO: POST /reports
    // await ApiService.instance.reportMessage(
    //   reporterUserId: _firebaseUser!.uid,
    //   reportedUserId: msg.userId,
    //   matchId: widget.matchId,
    //   messageId: msg.messageId,
    // );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message reported.')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: Text('Be the first to chat!', style: Body1.style),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 24),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.userId == _firebaseUser?.uid;
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
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.black,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3D3D3D),
                      shape: BoxShape.circle,
                    ),
                    child:
                    const Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: Body1.style,
                        decoration: InputDecoration(
                          hintText: 'Type a message',
                          hintStyle:
                          Body1.style.copyWith(color: Colors.grey),
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

  Widget _buildOtherMessage(ChatMessage msg, bool showHeader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Text(msg.username, style: Body2_b.style),
              const SizedBox(width: 8),
              Opacity(
                opacity: 0.5,
                child: Text(msg.timeString, style: Eyebrow.style),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(msg.text, style: Body1.style),
        ),
      ],
    );
  }

  Widget _buildMyMessage(ChatMessage msg, bool showHeader) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showHeader) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Opacity(
                opacity: 0.5,
                child: Text(msg.timeString, style: Eyebrow.style),
              ),
              const SizedBox(width: 8),
              Text(msg.username, style: Body2_b.style),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(msg.text, style: Body1.style),
        ),
      ],
    );
  }
}