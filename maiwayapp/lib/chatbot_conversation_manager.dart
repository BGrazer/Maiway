import 'package:flutter/foundation.dart'; // For ValueNotifier
import 'package:maiwayapp/models/message.dart'; // Assuming your Message class is here

// This class will hold and manage the conversation history
class ChatbotConversationManager extends ValueNotifier<List<Message>> {
  // Initial messages when the conversation starts or is reset
  static final List<Message> _initialMessages = [
    Message(
      text: "Hello! I am your MAIWAY commute companion. How can I assist you today?",
      isUser: false,
    ),
  ];

  // Initialize ValueNotifier with the initial messages
  ChatbotConversationManager() : super(_initialMessages);

  // Method to add a new message to the conversation
  void addMessage(Message message) {
    // Create a new list to ensure ValueNotifier detects the change
    value = [...value, message]; 
  }

  // Method to clear the conversation (e.g., if you add a "start new chat" button)
  void clearConversation() {
    value = [..._initialMessages]; // Reset to initial messages
  }
}

// Create a global instance of the manager. This instance will persist throughout the app's lifecycle.
final chatbotConversationManager = ChatbotConversationManager();