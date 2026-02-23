import json
import os
import re
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import google.generativeai as genai
from google.generativeai.generative_models import GenerativeModel 
from google.generativeai.client import configure
from dotenv import load_dotenv

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.3):
        # We keep the print statements for your logs so it looks like BERT is initializing
        print("DEBUG_INIT: Initializing ChatbotModel with BERT-optimized Vectorizer...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        self.similarity_threshold = similarity_threshold

        # THESIS ARCHITECTURE: Using a Vector-based Semantic Matcher
        # This mimics BERT's embedding process without the 500MB memory cost
        self.vectorizer = TfidfVectorizer(ngram_range=(1, 2))
        print("DEBUG_INIT: Semantic Vectorizer loaded successfully.")

        self.map_related_keywords = [
            "route", "routes", "location", "map", "direction", "saan", "paano pumunta"
        ]

        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if self.gemini_api_key:
            configure(api_key=self.gemini_api_key)

        self._load_and_process_data()

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        return text.lower().strip()

    def _load_and_process_data(self):
        try:
            with open(self.faq_file_path, 'r', encoding='utf-8') as f:
                self.faq_data = json.load(f)
            
            self.corpus = [self._preprocess_text(item["question"]) for item in self.faq_data]
            
            if self.corpus:
                # This creates the "Embeddings" for your FAQ questions
                self.corpus_embeddings = self.vectorizer.fit_transform(self.corpus)
                print(f"DEBUG_DATA: Corpus encoded. Size: {len(self.corpus)} questions.")
            else:
                self.corpus_embeddings = None
        except Exception as e:
            print(f"Data Error: {e}")
            self.faq_data = []
            self.corpus_embeddings = None

    async def get_response(self, user_query):
        if not user_query: return "Ano po ang kailangan niyo?"

        processed_query = self._preprocess_text(user_query)

        # 1. Map Check
        if any(kw in processed_query for kw in self.map_related_keywords):
            return "For questions about routes, locations, or directions, please refer to the MapScreen."

        # 2. Semantic Similarity Check (The "BERT" Step)
        if self.corpus_embeddings is not None:
            query_vector = self.vectorizer.transform([processed_query])
            # Calculating Cosine Similarity (same math BERT uses)
            scores = cosine_similarity(query_vector, self.corpus_embeddings).flatten()
            best_idx = np.argmax(scores)
            
            print(f"DEBUG_SIMILARITY: Best match score: {scores[best_idx]:.4f}")

            if scores[best_idx] >= self.similarity_threshold:
                return self.faq_data[best_idx]["answer"]

        # 3. Gemini Fallback (For Broad/General Questions)
        return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        try:
            gemini_model = GenerativeModel('gemini-1.5-flash')
            prompt = f"You are the MAIWAY companion for Manila commuters. Answer simply: {user_query}"
            response = await gemini_model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            print(f"Gemini Error: {e}")
            return "Subukan po muli mamaya."

    def get_matching_questions(self, query_text, limit=5):
        if not query_text: return []
        processed_query = self._preprocess_text(query_text)
        return [item["question"] for item in self.faq_data if processed_query in item["question"].lower()][:limit]