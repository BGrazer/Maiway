import json
import torch
import os
import re
from transformers import AutoTokenizer, AutoModel
import torch.nn.functional as F
import google.generativeai as genai
# FIXED IMPORTS: Following Pylance's specific export paths
from google.generativeai.generative_models import GenerativeModel 
from google.generativeai.client import configure
from dotenv import load_dotenv
import traceback

load_dotenv()

class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.85):
        print("DEBUG_INIT: Initializing ChatbotModel with DistilBERT (Memory Optimized)...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        self.similarity_threshold = similarity_threshold

        # THESIS REQUIREMENT: Still BERT, but the "Distilled" version to fit in 512MB RAM
        model_name = "distilbert-base-multilingual-cased"
        
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.model = AutoModel.from_pretrained(model_name)
        self.model.eval() # Set to evaluation mode to save memory
        print(f"DEBUG_INIT: {model_name} loaded.")

        self.map_related_keywords = [
            "route", "routes", "location", "map", "direction", "saan", "paano pumunta"
        ]

        # Standardizing API Key access
        self.gemini_api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
        if self.gemini_api_key:
            # FIXED: Using explicitly imported configure from .client
            configure(api_key=self.gemini_api_key)

        self._load_and_encode_data()

    def _preprocess_text(self, text):
        if not isinstance(text, str): return ""
        return text.lower().strip()

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

    def _load_and_encode_data(self):
        try:
            with open(self.faq_file_path, 'r', encoding='utf-8') as f:
                self.faq_data = json.load(f)
            self.corpus = [self._preprocess_text(item["question"]) for item in self.faq_data]
            if self.corpus:
                self.corpus_embeddings = self._encode(self.corpus)
            else:
                self.corpus_embeddings = torch.tensor([])
        except Exception as e:
            print(f"Data Error: {e}")
            self.faq_data = []
            self.corpus_embeddings = torch.tensor([])

    async def get_response(self, user_query):
        if not user_query: return "Ano po ang kailangan niyo?"

        processed_query = self._preprocess_text(user_query)

        # 1. Map Check
        if any(kw in processed_query for kw in self.map_related_keywords):
            return "For questions about routes, locations, or directions, please refer to the MapScreen."

        # 2. BERT Similarity Check
        if self.corpus_embeddings.numel() > 0:
            query_embedding = self._encode(processed_query)
            scores = F.cosine_similarity(query_embedding, self.corpus_embeddings)
            best_idx = int(torch.argmax(scores).item())
            
            if scores[best_idx].item() >= self.similarity_threshold:
                return self.faq_data[best_idx]["answer"]

        # 3. Gemini Fallback
        return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        try:
            # FIXED: Using explicitly imported GenerativeModel from .generative_models
            gemini_model = GenerativeModel('gemini-1.5-flash')
            prompt = f"You are the MAIWAY companion. Answer simply: {user_query}"
            
            response = await gemini_model.generate_content_async(prompt)
            return response.text
        except Exception as e:
            print(f"Gemini Error: {e}")
            return "Subukan po muli mamaya."

    def get_matching_questions(self, query_text, limit=5):
        if not query_text: return []
        processed_query = self._preprocess_text(query_text)
        return [item["question"] for item in self.faq_data if processed_query in item["question"].lower()][:limit]