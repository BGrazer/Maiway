import json
import os
import re
import asyncio
from google import genai  # type: ignore
from google.genai import types  # type: ignore
from dotenv import load_dotenv
import traceback

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.95):
        print("DEBUG_INIT: Initializing ChatbotModel (Lightweight Version)...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        
        # We use keyword matching now to save 500MB of RAM
        self.map_related_keywords = [
            "route", "routes", "how to get to", "location", "address",
            "map", "direction", "directions", "saan", "paano pumunta",
            "papunta", "where is", "find", "locate", "how to travel", "by foot",
            "walking", "commute",
        ]

        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") # Render standard key name
        if not self.gemini_api_key:
            print("ERROR_INIT: GOOGLE_API_KEY environment variable NOT set.")
            # Fallback for your specific variable name if needed
            self.gemini_api_key = os.getenv("GEMINI_API_KEY")
        
        # New GenAI Client
        self.client = genai.Client(api_key=self.gemini_api_key)
        self.model_id = "gemini-2.0-flash" # Latest stable fast model

        self._load_data_into_memory()
        print("DEBUG_INIT: ChatbotModel initialization complete.")

    def _load_data_into_memory(self):
        try:
            with open(self.faq_file_path, 'r', encoding='utf-8') as f:
                self.faq_data = json.load(f)
            print(f"DEBUG_DATA: Loaded {len(self.faq_data)} FAQ entries.")
        except Exception as e:
            print(f"ERROR_DATA: Could not load FAQ: {e}")
            self.faq_data = []

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        text = text.lower()
        return re.sub(r'[^a-z0-9\s]', '', text).strip()

    async def get_response(self, user_query):
        if not user_query:
            return "Wala po kayong tinanong. Paano po ako makakatulong?"

        processed_query = self._preprocess_text(user_query)

        # 1. Map Check
        if any(keyword in processed_query for keyword in self.map_related_keywords):
            return "For questions about routes, locations, or directions, please refer to the MapScreen. You can use the search bar there to find places."

        # 2. Simple FAQ Match (Keyword based to save memory)
        for item in self.faq_data:
            if processed_query in self._preprocess_text(item["question"]):
                return item["answer"]

        # 3. Gemini Fallback
        return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        try:
            prompt = (
                "You are the MAIWAY commute companion, an AI assistant for Manila commuters. "
                "Provide helpful, accurate, and concise info about Manila travel. "
                "Answer in the language used by the user (English or Tagalog).\n\n"
                f"User: {user_query}"
            )
            
            # Use the new unified SDK call
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt
            )
            return response.text
        except Exception as e:
            print(f"ERROR_GEMINI: {e}")
            return "Pasensya na, nagkaroon ng problema sa pagkuha ng impormasyon. Pakiusap na subukan muli."

    def get_matching_questions(self, query_text, limit=5):
        if not query_text: return []
        processed_query = self._preprocess_text(query_text)
        matches = [item["question"] for item in self.faq_data 
                   if processed_query in self._preprocess_text(item["question"])]
        return matches[:limit]

    def add_faq(self, question, answer):
        self.faq_data.append({"question": question, "answer": answer})
        with open(self.faq_file_path, 'w', encoding='utf-8') as f:
            json.dump(self.faq_data, f, indent=4)
        return True