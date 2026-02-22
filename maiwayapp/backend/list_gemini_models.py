import google.generativeai as genai
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

def list_gemini_models():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set.")
        return

    genai.configure(api_key=api_key)

    try:
        print("Listing available Gemini models and their capabilities:")
        for m in genai.list_models():
            if "generateContent" in m.supported_generation_methods:
                print(f"  Model: {m.name}")
                print(f"    Description: {m.description}")
                print(f"    Input Token Limit: {m.input_token_limit}")
                print(f"    Output Token Limit: {m.output_token_limit}")
                print(f"    Supported Methods: {m.supported_generation_methods}")
                print("-" * 30)
    except Exception as e:
        print(f"An error occurred while listing models: {e}")

if __name__ == "__main__":
    list_gemini_models()