import json
import os
import re
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from google import genai  # type: ignore
from google.genai import types  # type: ignore
from dotenv import load_dotenv

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.7): # Increased to 0.7
        print("DEBUG_INIT: Initializing Optimized Hybrid Chatbot...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        
        # High threshold ensures we only use FAQ for very relevant questions
        self.similarity_threshold = similarity_threshold

        # Mimics BERT embeddings via N-grams
        self.vectorizer = TfidfVectorizer(ngram_range=(1, 3)) 

        self.map_related_keywords = [
            "route", "routes", "how to get to", "location", "address",
            "map", "direction", "directions", "saan", "paano pumunta",
            "papunta", "where is", "find", "locate", "how to travel", "by foot",
            "walking", "commute", "paano", "paano pumunta sa",
            "how to", "how to go", "how to get", "how do i get",
            "papunta sa", "punta sa", "pumunta sa"
        ]

        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if self.gemini_api_key:
            self.client = genai.Client(api_key=self.gemini_api_key)
        else:
            self.client = None

        self._load_and_process_data()

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        # Keep math symbols like + - * / and ? 
        return text.lower().strip()

    def _load_and_process_data(self):
        try:
            with open(self.faq_file_path, 'r', encoding='utf-8') as f:
                self.faq_data = json.load(f)
            self.corpus = [self._preprocess_text(item["question"]) for item in self.faq_data]
            if self.corpus:
                self.corpus_embeddings = self.vectorizer.fit_transform(self.corpus)
            else:
                self.corpus_embeddings = None
        except Exception as e:
            self.faq_data = []
            self.corpus_embeddings = None

    async def get_response(self, user_query):
        if not user_query: return "Ano po ang kailangan niyo?"

        processed_query = self._preprocess_text(user_query)

        # FIX: If it looks like math or a very short general question, go straight to Gemini
        if re.search(r'[0-9]', processed_query) and any(op in processed_query for op in '+-*/='):
            return await self._get_gemini_response(user_query)

        # 1. Map Check
        if any(kw in processed_query for kw in self.map_related_keywords):
            return "For questions about routes, locations, or directions, please refer to the MapScreen."

        # 2. Semantic Similarity Check
        if self.corpus_embeddings is not None:
            query_vector = self.vectorizer.transform([processed_query])
            scores = cosine_similarity(query_vector, self.corpus_embeddings).flatten()
            best_idx = np.argmax(scores)
            
            # Only use FAQ if it's a high-confidence match
            if scores[best_idx] >= self.similarity_threshold:
                return self.faq_data[best_idx]["answer"]

        # 3. Gemini Fallback (Handles President, 1+1, etc.)
        return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        try:
            if not self.client:
                print("ERROR: No Gemini API key found")
                return "Subukan po muli mamaya."
            
            prompt = (
                "You are the MAIWAY assistant. You help with Manila commuting. "
                "However, if the user asks general questions or math, answer them directly and concisely. "
                f"User asks: {user_query}"
            )
            print(f"DEBUG: Calling Gemini with query: {user_query}")
            
            # Try multiple model names
            models_to_try = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-latest']
            
            for model_name in models_to_try:
                try:
                    print(f"DEBUG: Trying model: {model_name}")
                    response = self.client.models.generate_content(
                        model=model_name,
                        contents=prompt
                    )
                    print(f"DEBUG: Success with {model_name}! Response: {response.text}")
                    return response.text
                except Exception as model_error:
                    print(f"DEBUG: Model {model_name} failed: {model_error}")
                    continue
            
            # If all models fail, return error
            return "Subukan po muli mamaya."
        except Exception as e:
            print(f"Gemini Error: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            return "Subukan po muli mamaya."

    def get_matching_questions(self, query_text, limit=5):
        if not query_text: return []
        processed_query = self._preprocess_text(query_text)
        return [item["question"] for item in self.faq_data if processed_query in item["question"].lower()][:limit]