// maiway_chatbot/frontend/script.js
document.addEventListener('DOMContentLoaded', () => {
    const chatMessages = document.getElementById('chat-messages');
    const userInput = document.getElementById('user-input');
    const sendButton = document.getElementById('send-button');
    const suggestionsContainer = document.getElementById('suggestions-container');

    const CHAT_API_URL = 'http://127.0.0.1:5000/chat';
    const FAQ_DATA_URL = 'http://127.0.0.1:5000/faq_data.json'; 

    let allQuestions = [];
    let botTypingIndicatorDiv = null; 

    async function loadRecommendedQuestions() {
        try {
            const response = await fetch(FAQ_DATA_URL);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            const data = await response.json();
            allQuestions = data.map(item => item.question).filter(q => typeof q === 'string' && q.trim() !== '');
            console.log("FAQ data loaded for suggestions:", allQuestions.length, "questions");
        } catch (e) {
            console.error("Error loading recommended questions:", e);
        }
    }

    function appendMessage(messageContent, sender, isTypingIndicator = false) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', `${sender}-message`);

        if (isTypingIndicator) {
            messageDiv.classList.add('typing-indicator'); 
            messageDiv.innerHTML = '<span>.</span><span>.</span><span>.</span>';
            botTypingIndicatorDiv = messageDiv;
        } else if (typeof messageContent === 'string') {
            messageDiv.textContent = messageContent;
        } else if (typeof messageContent === 'object' && messageContent !== null) {
            if (messageContent.type === 'text') {
                messageDiv.textContent = messageContent.content;
            } else if (messageContent.type === 'image') {
                const img = document.createElement('img');
                img.src = messageContent.content;
                img.alt = messageContent.alt_text || 'Image from chatbot';
                img.style.maxWidth = '100%';
                img.style.borderRadius = '8px';
                messageDiv.appendChild(img);
            } else if (messageContent.type === 'image_and_text') {
                const textPara = document.createElement('p');
                textPara.textContent = messageContent.text_content;
                const img = document.createElement('img');
                img.src = messageContent.image_content;
                img.alt = messageContent.alt_text || 'Image from chatbot';
                img.style.maxWidth = '100%';
                img.style.borderRadius = '8px';
                img.style.marginTop = '8px';

                messageDiv.appendChild(textPara);
                messageDiv.appendChild(img);
            } else {
                messageDiv.textContent = 'Bot responded with an unknown message type.';
                console.warn('Unknown message type received:', messageContent);
            }
        } else {
            messageDiv.textContent = 'Unexpected message format received.';
            console.warn('Unexpected message format:', messageContent);
        }

        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight; 
        return messageDiv; 
    }

    async function sendMessage() {
        const message = userInput.value.trim();
        if (message === '') return;

        appendMessage(message, 'user'); 
        userInput.value = '';
        suggestionsContainer.innerHTML = '';

        appendMessage('', 'bot', true); 
        chatMessages.scrollTop = chatMessages.scrollHeight; 

        try {
            const fetchPromise = fetch(CHAT_API_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ message: message }),
            });

            const delayTime = Math.random() * 2000 + 1000;
            await new Promise(resolve => setTimeout(resolve, delayTime)); 

            const response = await fetchPromise;
            const data = await response.json();

            if (botTypingIndicatorDiv) {
                botTypingIndicatorDiv.remove(); 
                botTypingIndicatorDiv = null;
            }
            appendMessage(data.response, 'bot'); 

        } catch (error) {
            console.error('Error sending message:', error);

            if (botTypingIndicatorDiv) {
                botTypingIndicatorDiv.remove();
                botTypingIndicatorDiv = null;
            }
            appendMessage("Oops! Something went wrong while connecting to the chatbot. Please try again later.", 'bot');
        }
    }

    function displaySuggestions(query) {
        suggestionsContainer.innerHTML = '';
        const lowerCaseQuery = query.toLowerCase();

        let filteredSuggestions;
        if (query.length > 0) {
            filteredSuggestions = allQuestions.filter(q =>
                q.toLowerCase().includes(lowerCaseQuery)
            ).slice(0, 5);
        } else {
            filteredSuggestions = allQuestions.slice(0, 5);
        }

        if (filteredSuggestions.length > 0) {
            filteredSuggestions.forEach(suggestion => {
                const chip = document.createElement('div');
                chip.classList.add('suggestion-chip');
                chip.textContent = suggestion;
                chip.addEventListener('click', () => {
                    userInput.value = suggestion;
                    sendMessage();
                });
                suggestionsContainer.appendChild(chip);
            });
        }
    }

    sendButton.addEventListener('click', sendMessage);
    userInput.addEventListener('keypress', (event) => {
        if (event.key === 'Enter') {
            sendMessage();
        }
    });

    userInput.addEventListener('input', (event) => {
        displaySuggestions(event.target.value);
    });

    loadRecommendedQuestions().then(() => {
        displaySuggestions('');
    });
});