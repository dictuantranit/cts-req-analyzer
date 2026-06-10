import os
import requests
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv('GOOGLE_API_KEY')
if not api_key:
    print("Error: GOOGLE_API_KEY not found in .env")
    exit(1)

url = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"

try:
    response = requests.get(url)
    response.raise_for_status()
    data = response.json()
    
    with open('models_list.txt', 'w') as f:
        f.write("Available Models:\n")
        for model in data.get('models', []):
            if 'generateContent' in model.get('supportedGenerationMethods', []):
                f.write(f"- {model['name']}\n")
    print("Models list saved to models_list.txt")
            
except Exception as e:
    print(f"Error listing models: {e}")
