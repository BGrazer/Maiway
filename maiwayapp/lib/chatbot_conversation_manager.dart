import 'package:flutter/foundation.dart';
import 'package:maiwayapp/models/message.dart'; 

class ChatbotConversationManager extends ValueNotifier<List<Message>> {
  static final List<Message> _initialMessages = [
    Message(
      text: "Hello! I am your MAIWAY commute companion. How can I assist you today?",
      isUser: false,
    ),
  ];

  ChatbotConversationManager() : super(_initialMessages);

  void addMessage(Message message) {
    value = [...value, message]; 
  }

  void clearConversation() {
    value = [..._initialMessages]; 
  }
}

final chatbotConversationManager = ChatbotConversationManager();