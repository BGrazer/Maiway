import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:maiwayapp/models/message.dart';
import 'package:maiwayapp/chatbot_conversation_manager.dart';

class ChatbotDialog extends StatefulWidget {
  const ChatbotDialog({super.key});

  @override
  State<ChatbotDialog> createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textEditingController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isBotTyping = false;
  List<String> _dynamicSuggestions = [];
  late AnimationController _typingAnimationController;

  final String _chatBackendUrl =
      'https://maiway-backend-production.up.railway.app/chat';
  final String _dynamicSuggestionsUrl =
      'https://maiway-backend-production.up.railway.app/dynamic_suggestions';

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _onInputChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _dynamicSuggestions = [];
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          '$_dynamicSuggestionsUrl?query=${Uri.encodeComponent(query)}',
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> fetchedSuggestions =
            responseData['suggestions'] ?? [];

        setState(() {
          _dynamicSuggestions = fetchedSuggestions.cast<String>();
        });
      } else {
        print(
          "Failed to load dynamic suggestion. Status: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Error fetching dynamic suggestions: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    chatbotConversationManager.addMessage(Message(text: text, isUser: true));
    _textEditingController.clear();

    setState(() {
      _isBotTyping = true;
      _dynamicSuggestions = [];
    });

    try {
      final response = await http.post(
        Uri.parse(_chatBackendUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{'message': text}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final botResponse = responseData['response'];

        chatbotConversationManager.addMessage(
          Message(text: botResponse, isUser: false),
        );
        setState(() {
          _isBotTyping = false;
        });
      } else {
        chatbotConversationManager.addMessage(
          Message(
            text:
                "Error: Could not get a response from the chatbot. Status: ${response.statusCode}",
            isUser: false,
          ),
        );
        setState(() {
          _isBotTyping = false;
        });
        print(
          "Chatbot server error: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      chatbotConversationManager.addMessage(
        Message(
          text:
              "Error: Failed to connect to the chatbot. Please check your network or server. ($e)",
          isUser: false,
        ),
      );
      setState(() {
        _isBotTyping = false;
      });
      print("Chatbot communication error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 15,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0084FF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          FontAwesomeIcons.chevronLeft,
                          size: 20,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      ClipOval(
                        child: Image.asset(
                          'assets/images/chatbot_icon.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MAIWAY FAQs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: ValueListenableBuilder<List<Message>>(
                    valueListenable: chatbotConversationManager,
                    builder: (context, messages, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                      return Container(
                        color: const Color(0xFFF0F2F5),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(15.0),
                          itemCount: messages.length + (_isBotTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              return _buildTypingIndicator();
                            }
                            final message = messages[index];
                            return Align(
                              alignment:
                                  message.isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10.0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15.0,
                                    vertical: 10.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        message.isUser
                                            ? const Color(0xFF0084FF)
                                            : const Color(0xFFE4E6EB),
                                    borderRadius: BorderRadius.circular(18.0),
                                  ),
                                  child: Text(
                                    message.text,
                                    style: TextStyle(
                                      color:
                                          message.isUser
                                              ? Colors.white
                                              : Colors.black,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                if (_dynamicSuggestions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(
                      left: 15.0,
                      right: 15.0,
                      top: 5.0,
                      bottom: 5.0,
                    ),
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children:
                          _dynamicSuggestions
                              .map((text) => _buildSuggestionChip(text))
                              .toList(),
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.all(15.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFDDDDDD), width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textEditingController,
                          onChanged: _onInputChanged,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                              vertical: 10.0,
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => _sendMessage(_textEditingController.text),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0084FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            FontAwesomeIcons.paperPlane,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _textEditingController.text = text;
        _sendMessage(text);
      },
      child: Chip(
        label: Text(
          text,
          style: const TextStyle(fontSize: 14.0, color: Color(0xFF333333)),
        ),
        backgroundColor: const Color(0xFFE4E6EB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: const BorderSide(color: Color(0xFFD3D6DB), width: 1.0),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10.0),
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: const Color(0xFFE4E6EB),
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _typingAnimationController,
              builder: (context, child) {
                final double opacity =
                    (index == 0
                        ? _typingAnimationController.value
                        : index == 1
                        ? (_typingAnimationController.value + 0.33) % 1.0
                        : (_typingAnimationController.value + 0.66) % 1.0) *
                    2;
                return Opacity(
                  opacity: (opacity > 1.0 ? 2.0 - opacity : opacity).clamp(
                    0.2,
                    1.0,
                  ),
                  child: const Text(
                    '.',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _typingAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
