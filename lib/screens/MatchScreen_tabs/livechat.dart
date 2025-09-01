import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class LiveChatTab extends StatefulWidget {
  const LiveChatTab({super.key});

  @override
  State<LiveChatTab> createState() => _LiveChatTabState();
}

class _LiveChatTabState extends State<LiveChatTab> {
  final List<Map<String, String>> messages = [
    {
      'user': 'USER 4',
      'time': '2:03 AM',
      'text': 'that guy should start next time!',
    },
    {
      'user': 'USER 5',
      'time': '2:04 AM',
      'text': 'when are we signing new players?',
    },
    {
      'user': 'USER 5',
      'time': '2:04 AM',
      'text': 'guys chill',
    },
  ];

  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF3D3D3D),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('${msg['user']}',
                                    style: Body2_b.style),
                                SizedBox(width: 8,),
                                Opacity(
                                  opacity: 0.5,
                                  child: Text('${msg['time']}',
                                      style: Eyebrow.style),
                                )
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Color(0xFF3D3D3D),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                msg['text']!,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      print('Sending: ${_controller.text}');
                      _controller.clear();
                    },
                    child: const Icon(Icons.send, color: Colors.blue, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


//class LiveChatTab extends StatefulWidget {
//   const LiveChatTab({super.key});
//
//   @override
//   State<LiveChatTab> createState() => _LiveChatTabState();
// }
//
// class _LiveChatTabState extends State<LiveChatTab> {
//   final List<types.Message> _messages = [];
//   final types.User _user = const types.User(id: 'user-1'); // Current user
//
//   @override
//   void initState() {
//     super.initState();
//     _loadInitialMessages();
//   }
//
//   void _loadInitialMessages() {
//     _messages.addAll([
//       types.TextMessage(
//         id: const Uuid().v4(),
//         author: const types.User(id: 'user-4'),
//         text: 'that guy should start next time!',
//         createdAt: DateTime.now().millisecondsSinceEpoch - 100000,
//       ),
//       types.TextMessage(
//         id: const Uuid().v4(),
//         author: const types.User(id: 'user-5'),
//         text: 'when are we signing new players?',
//         createdAt: DateTime.now().millisecondsSinceEpoch - 80000,
//       ),
//       types.TextMessage(
//         id: const Uuid().v4(),
//         author: const types.User(id: 'user-5'),
//         text: 'guys chill',
//         createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
//       ),
//     ]);
//   }
//
//   void _handleSendPressed(types.PartialText message) {
//     final textMessage = types.TextMessage(
//       author: _user,
//       createdAt: DateTime.now().millisecondsSinceEpoch,
//       id: const Uuid().v4(),
//       text: message.text,
//     );
//
//     setState(() {
//       _messages.insert(0, textMessage); // Chat UI uses reversed list
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: MediaQuery.of(context).size.height,
//       child: Chat(
//         messages: _messages,
//         onSendPressed: _handleSendPressed,
//         user: _user,
//         theme: const DefaultChatTheme(
//           backgroundColor: Colors.black,
//           inputBackgroundColor: Color(0xFF1A1A1A),
//           inputTextColor: Colors.white,
//           inputBorderRadius: BorderRadius.all(Radius.circular(24)),
//           inputTextCursorColor: Colors.white,
//           primaryColor: Color(0xFF5B92FF), // Send button color
//           secondaryColor: Color(0xFF444444), // Bubble background
//           receivedMessageBodyTextStyle: TextStyle(color: Colors.white),
//           sentMessageBodyTextStyle: TextStyle(color: Colors.white),
//           sentMessageCaptionTextStyle: TextStyle(color: Colors.grey, fontSize: 11),
//           receivedMessageCaptionTextStyle: TextStyle(color: Colors.grey, fontSize: 11),
//           inputTextDecoration: InputDecoration.collapsed(
//             hintText: 'Type a message...',
//             hintStyle: TextStyle(color: Colors.grey),
//           ),
//           sendButtonIcon: Icon(Icons.send, size: 24, color: Color(0xFF5B92FF)),
//         ),
//         showUserAvatars: true,
//         showUserNames: true,
//       ),
//     );
//   }
// }