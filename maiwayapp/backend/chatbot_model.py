import json
import torch
import os
import re
from transformers import AutoTokenizer, AutoModel
import torch.nn.functional as F
import google.generativeai as genai
from dotenv import load_dotenv
import traceback

load_dotenv()


class ChatbotModel:
    def __init__(self, data_path='data/faq_data.json', similarity_threshold=0.95):
        print("DEBUG_INIT: Initializing ChatbotModel...")
        script_dir = os.path.dirname(__file__)
        self.faq_file_path = os.path.join(script_dir, data_path)
        self.similarity_threshold = similarity_threshold

        self.tokenizer = AutoTokenizer.from_pretrained("bert-base-multilingual-uncased")
        self.model = AutoModel.from_pretrained("bert-base-multilingual-uncased")
        print("DEBUG_INIT: BERT tokenizer and model loaded.")

        self.map_related_keywords = [
            "route", "routes", "how to get to", "location", "address",
            "map", "direction", "directions", "saan", "paano pumunta",
            "papunta", "where is", "find", "locate", "how to travel", "by foot",
            "walking", "commute",
        ]


        self.gemini_api_key = os.getenv("GEMINI_API_KEY") 
        if not self.gemini_api_key:
            print("ERROR_INIT: GEMINI_API_KEY environment variable NOT set.")
            raise ValueError("GEMINI_API_KEY environment variable not set. Please create a .env file or set the variable.")
        else:
            print("DEBUG_INIT: GEMINI_API_KEY found in environment.")
        
        genai.configure(api_key=self.gemini_api_key)  # type: ignore[reportPrivateImportUsage]

        self._load_and_encode_data()
        print("DEBUG_INIT: ChatbotModel initialization complete.")

    def _load_data(self, path):
        try:
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            print(f"DEBUG_DATA: Successfully loaded data from: {path}")
            return data
        except FileNotFoundError:
            print(f"ERROR_DATA: FAQ data file not found at {path}. Initializing with empty data.")
            return []
        except json.JSONDecodeError as e:
            print(f"ERROR_DATA: Error decoding JSON from {path}: {e}. Initializing with empty data.")
            return []

    def _save_data(self, path):
        try:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(self.faq_data, f, ensure_ascii=False, indent=4)
            print(f"DEBUG_DATA: Successfully saved data to: {path}")
        except IOError as e:
            print(f"ERROR_DATA: Error saving data to {path}: {e}")

    def _preprocess_text(self, text):
        if not isinstance(text, str):
            return ""
        text = text.lower()
        text = re.sub(r'\s+', ' ', text).strip()
        return text

    def _mean_pooling(self, model_output, attention_mask):
        token_embeddings = model_output[0]
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

    def _encode(self, texts):
        if isinstance(texts, str):
            texts = [texts]
        encoded_input = self.tokenizer(texts, padding=True, truncation=True, return_tensors='pt')
        with torch.no_grad():
            model_output = self.model(**encoded_input)
        embeddings = self._mean_pooling(model_output, encoded_input['attention_mask'])
        return F.normalize(embeddings, p=2, dim=1)

    def _load_and_encode_data(self):
        print(f"DEBUG_DATA: Loading and encoding chatbot data from: {self.faq_file_path}")
        self.faq_data = self._load_data(self.faq_file_path)

        self.corpus = [self._preprocess_text(item["question"]) for item in self.faq_data]
        if not self.corpus:
            self.corpus_embeddings = torch.tensor([])
            print("WARNING_DATA: Corpus is empty, no embeddings generated.")
        else:
            self.corpus_embeddings = self._encode(self.corpus)
        print(f"DEBUG_DATA: Data loaded and corpus encoded. Corpus size: {len(self.corpus)} questions.")

    async def get_response(self, user_query):
        print(f"DEBUG_MAIN: Received user query: '{user_query}'")
        if not user_query:
            print("DEBUG_MAIN: Empty query received.")
            return "Wala po po kayong tinanong. Paano po ako makakatulong?"

        processed_query = self._preprocess_text(user_query)
        print(f"DEBUG_MAIN: Processed query: '{processed_query}'")

        for keyword in self.map_related_keywords:
            if keyword in processed_query:
                print(f"DEBUG_MAIN: Detected map-related query with keyword: '{keyword}'. Redirecting to MapScreen.")
                return "For questions about routes, locations, or directions, please refer to the MapScreen. You can use the search bar there to find places."

        if self.corpus_embeddings.numel() == 0:
            print("DEBUG_MAIN: Warning: Chatbot corpus embeddings are empty. Directly calling Gemini API.")
            return await self._get_gemini_response(user_query)

        query_embedding = self._encode(processed_query)

        cosine_scores = F.cosine_similarity(query_embedding, self.corpus_embeddings)

        if cosine_scores.dim() == 0:
            similarity_score = cosine_scores.item()
            best_match_idx = 0
        else:
            best_match_idx = int(torch.argmax(cosine_scores).item())
            similarity_score = cosine_scores[best_match_idx].item()

        print(f"\n--- Chatbot Response Debug ---")
        print(f"User Query (Original): '{user_query}'")
        print(f"User Query (Processed): '{processed_query}'")
        if self.corpus and best_match_idx < len(self.corpus):
            print(f"Best matching question in corpus: '{self.corpus[best_match_idx]}'")
            print(f"Original question text: '{self.faq_data[best_match_idx]['question']}'")
        print(f"Similarity Score: {similarity_score:.4f}")
        print(f"Configured Threshold: {self.similarity_threshold:.4f}")
        print(f"--- End Debug ---\n")

        if similarity_score >= self.similarity_threshold:
            print(f"DEBUG_MAIN: Similarity score ({similarity_score:.4f}) >= threshold ({self.similarity_threshold:.4f}). Returning FAQ answer.")
            return self.faq_data[best_match_idx]["answer"]
        else:
            print(f"DEBUG_MAIN: Similarity score ({similarity_score:.4f}) < threshold ({self.similarity_threshold:.4f}). Attempting to get response from Gemini API.")
            return await self._get_gemini_response(user_query)

    async def _get_gemini_response(self, user_query):
        print(f"DEBUG_GEMINI: Entering _get_gemini_response for query: '{user_query}'")
        try:
            prompt = (
                "You are the MAIWAY commute companion, an AI assistant dedicated to guiding commuters around the City of Manila. "
                "Your goal is to provide helpful, accurate, and concise information about commuting in Manila, including "
                "transportation options, routes, fares, landmarks, and general travel tips within the city. "
                "While your primary focus is Manila commutes, you can also answer general knowledge questions if they are simple and direct. "
                "Answer the following user query based on your knowledge. "
                "If the query is not directly related to Manila commutes, you may still answer it, but mention your main purpose is commute assistance in Manila. "
                "Answer in the language the user used (English or Tagalog).\n\n"
                f"User: {user_query}\n"
                "MAIWAY: "
            )
            print(f"DEBUG_GEMINI: Sending prompt to Gemini API. Prompt length: {len(prompt)} characters.")
            

            
            if not self.gemini_api_key:
                print("ERROR_GEMINI_API: GEMINI_API_KEY is missing during API call attempt in _get_gemini_response.")
                return "Pasensya na, hindi available ang serbisyo ng AI sa ngayon dahil sa nawawalang API key."
            
            genai.configure(api_key=self.gemini_api_key) # type: ignore[reportPrivateImportUsage]

            local_gemini_model = genai.GenerativeModel('gemini-2.5-flash') # type: ignore[reportPrivateImportUsage]
            print("DEBUG_GEMINI: Fresh Gemini model instance created for this request.")

            response = await local_gemini_model.generate_content_async(prompt)
            
            print(f"DEBUG_GEMINI: Gemini API call completed. Response object type: {type(response)}, content: {response}")
            
            if response.candidates:
                first_candidate = response.candidates[0]
                print(f"DEBUG_GEMINI: Gemini response has candidates. First candidate type: {type(first_candidate)}, content: {first_candidate}")
                
                if hasattr(first_candidate, 'content') and hasattr(first_candidate.content, 'parts') and first_candidate.content.parts:
                    response_text = first_candidate.content.parts[0].text
                    print(f"DEBUG_GEMINI: Gemini returned text: '{response_text}'")
                    return response_text
                else:
                    print(f"DEBUG_GEMINI: Gemini response candidate has no content or parts. Full candidate: {first_candidate}")
                    return "Pasensya na, hindi ko po masasagot ang tanong na iyan sa ngayon. Pakiusap na subukan muli maya-maya."
            else:
                print(f"DEBUG_GEMINI: Gemini response has NO candidates. This usually means the query was blocked by safety settings or was unanswerable. Checking response.prompt_feedback...")
                if hasattr(response, 'prompt_feedback') and response.prompt_feedback:
                    print(f"DEBUG_GEMINI: Prompt Feedback: {response.prompt_feedback}")
                    if hasattr(response.prompt_feedback, 'safety_ratings'):
                        for rating in response.prompt_feedback.safety_ratings:
                            print(f"DEBUG_GEMINI: Safety Rating - Category: {rating.category.name}, Probability: {rating.probability.name}")
                    if hasattr(response.prompt_feedback, 'block_reason'):
                        print(f"DEBUG_GEMINI: Block Reason: {response.prompt_feedback.block_reason}")
                return "Pasensya na, hindi ko po masasagot ang tanong na iyan sa ngayon. Pakiusap na subukan muli maya-maya."
            
        except Exception as e:
            print(f"ERROR_GEMINI_API: Exception caught during Gemini API call: {e}")
            print(f"ERROR_GEMINI_API: Traceback:\n{traceback.format_exc()}")
            return "Pasensya na, nagkaroon ng problema sa pagkuha ng impormasyon. Pakiusap na subukan muli maya-maya."

    def add_faq(self, question, answer):
        if not question or not answer:
            print("Error: Question or answer cannot be empty when adding FAQ.")
            return False

        processed_new_question = self._preprocess_text(question)

        if self.faq_data:
            for item in self.faq_data:
                if self._preprocess_text(item["question"]) == processed_new_question:
                    print(f"Question '{question}' already exists. Skipping.")
                    return False

        self.faq_data.append({"question": question, "answer": answer})
        self._save_data(self.faq_file_path)
        self._load_and_encode_data()
        print(f"New FAQ added: '{question}'. Chatbot knowledge base updated.")
        return True

    def reload_data(self):
        self._load_and_encode_data()
        print("Chatbot data reloaded manually.")

    def get_matching_questions(self, query_text, limit=5):
        if not query_text:
            return []

        processed_query = self._preprocess_text(query_text)
        matches = []
        for item in self.faq_data:
            processed_question = self._preprocess_text(item["question"])
            if processed_query in processed_question:
                matches.append(item["question"])
            if len(matches) >= limit:
                break
        return matches