import json
import torch
import os
import re
# We switch to a lighter BERT model to stay under 512MB
from transformers import AutoTokenizer, AutoModel
import torch.nn.functional as F
import google.generativeai as genai  # type: ignore
from dotenv import load_dotenv
import traceback

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.85):
        print("DEBUG_INIT: Initializing ChatbotModel with Lightweight BERT...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        self.similarity_threshold = similarity_threshold

        # THESIS FIX: Using 'distilbert-base-multilingual-cased' 
        # It's 40% smaller than base BERT but uses the same architecture.
        # This keeps your objective intact while fitting in Render's 512MB RAM.
        model_name = "distilbert-base-multilingual-cased"
        
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        
        # Force model to use evaluation mode and minimal memory
        self.model.eval() 
        print(f"DEBUG_INIT: {model_name} loaded successfully.")

        self.map_related_keywords = [
            "route", "routes", "how to get to", "location", "address",
            "map", "direction", "directions", "saan", "paano pumunta",
            "papunta", "where is", "find", "locate", "how to travel", "by foot",
            "walking", "commute",
        ]

        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if not self.gemini_api_key:
            raise ValueError("GEMINI_API_KEY environment variable not set.")
        
        genai.configure(api_key=self.gemini_api_key)  # type: ignore
        self._load_and_encode_data()  # type: ignore

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        # Keep math symbols like + for general questions
        text = text.lower().strip()
        return text

    def _mean_pooling(self, model_output, attention_mask):
        token_embeddings = model_output[0]
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

    def _encode(self, texts):
        if isinstance(texts, str): texts = [texts]
        encoded_input = self.tokenizer(texts, padding=True, truncation=True, return_tensors='pt')
        with torch.no_grad():
            model_output = self.model(**encoded_input)
        embeddings = self._mean_pooling(model_output, encoded_input['attention_mask'])
        return F.normalize(embeddings, p=2, dim=1)

    # ... [Rest of your get_response and add_faq methods remain the same] ...

    async def _get_gemini_response(self, user_query):
        # This handles the broad questions like 1+1 or current events
        try:
            # Using the version of Gemini you have installed in requirements
            model = genai.GenerativeModel('gemini-1.5-flash')  # type: ignore
            prompt = (
                "You are the MAIWAY commute companion. Help with Manila commutes first, "
                "but you can also answer general knowledge and math simply. "
                f"User Query: {user_query}"
            )
            response = await model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            print(f"ERROR: {e}")
            return "Pasensya na, subukan muli mamaya."