import json
import os
import re
import asyncio
from google import genai 
from google.genai import types 
from dotenv import load_dotenv
import traceback

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.95):
        print("DEBUG_INIT: Initializing ChatbotModel (Optimized Version)...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        
        # Keywords specifically for redirecting to Map
        self.map_related_keywords = [
            "route", "routes", "how to get to", "location", "address",
            "map", "direction", "directions", "saan", "paano pumunta",
            "papunta", "where is", "find", "locate", "how to travel", "by foot",
            "walking", "commute",
        ]

        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        
        if not self.gemini_api_key:
            print("ERROR_INIT: API Key NOT set.")
        
        self.client = genai.Client(api_key=self.gemini_api_key)
        self.model_id = "gemini-2.0-flash" 

        self._load_data_into_memory()
        print("DEBUG_INIT: ChatbotModel initialization complete.")

    def _load_data_into_memory(self):
        try:
            if os.path.exists(self.faq_file_path):
                with open(self.faq_file_path, 'r', encoding='utf-8') as f:
                    self.faq_data = json.load(f)
                print(f"DEBUG_DATA: Loaded {len(self.faq_data)} FAQ entries.")
            else:
                self.faq_data = []
        except Exception as e:
            print(f"ERROR_DATA: {e}")
            self.faq_data = []

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        # We only lowercase and trim; keeping symbols like + and ? for better AI understanding
        return text.lower().strip()

    async def get_response(self, user_query):
        if not user_query:
            return "Wala po kayong tinanong. Paano po ako makakatulong?"

        processed_query = self._preprocess_text(user_query)

        # 1. Map Check (Only redirect if it's clearly about navigation)
        if any(keyword in processed_query for keyword in self.map_related_keywords):
            # Only redirect if the query is long enough to be a navigation request
            if len(processed_query.split()) > 1:
                return "For questions about routes, locations, or directions, please refer to the MapScreen. You can use the search bar there to find places."

        # 2. Strict FAQ Match
        # We only return an FAQ answer if the user's question is very similar to our saved questions
        for item in self.faq_data:
            if processed_query == self._preprocess_text(item["question"]):
                return item["answer"]

        # 3. Gemini Fallback (Handles 1+1, President, and general talk)
        return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        try:
            # System instruction to keep it as a commute companion but allow general help
            instruction = (
                "You are the MAIWAY commute companion. While your expertise is Manila commuting, "
                "you are helpful and can answer general questions (math, facts, etc.) concisely. "
                "Answer in the user's language (English or Tagalog)."
            )
            
            # Note: The 'await' is used if your framework is async, 
            # but standard client.models.generate_content is synchronous unless using specific async clients.
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=f"{instruction}\n\nUser: {user_query}"
            )
            
            return response.text
        except Exception as e:
            print(f"ERROR_GEMINI: {e}")
            traceback.print_exc()
            return "Pasensya na, nagkaroon ng problema sa pagkuha ng impormasyon. Pakiusap na subukan muli."

    def get_matching_questions(self, query_text, limit=5):
        if not query_text: return []
        processed_query = self._preprocess_text(query_text)
        matches = [item["question"] for item in self.faq_data 
                   if processed_query in self._preprocess_text(item["question"])]
        return matches[:limit]

    def add_faq(self, question, answer):
        self.faq_data.append({"question": question, "answer": answer})
        try:
            os.makedirs(os.path.dirname(self.faq_file_path), exist_ok=True)
            with open(self.faq_file_path, 'w', encoding='utf-8') as f:
                json.dump(self.faq_data, f, indent=4)
            return True
        except:
            return False