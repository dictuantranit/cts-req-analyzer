"""
Simple Gemini API wrapper using requests (works with Python 3.7+)
"""
import os
import requests
import json
import time


class SimpleGemini:
    """Simple wrapper for Google Gemini API using REST"""
    
    def __init__(self, api_key=None, model=None):
        raw_key = api_key or os.getenv('GOOGLE_API_KEY', '')
        # Clean key: strip whitespaces and take the first token in case extra text was copied
        self.api_key = raw_key.strip().split()[0] if raw_key.strip() else ''
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY not found")
        
        self.model = model or os.getenv('GEMINI_MODEL', 'gemini-2.5-flash')
        if self.model.startswith('models/'):
            self.model = self.model[len('models/'):]
            
        self.base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"
    
    def __call__(self, prompt):
        """Generate content from prompt"""
        return self.generate(prompt)
    
    def generate(self, prompt):
        """Generate content using Gemini API"""
        payload = {
            "contents": [{
                "parts": [{
                    "text": prompt
                }]
            }]
        }
        
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.api_key
        }
        
        # Candidate models to try in case the configured model is unavailable (404, 503, 429)
        candidate_models = [self.model]
        fallback_list = [
            'gemini-2.0-flash',
            'gemini-2.0-flash-lite',
            'gemini-2.5-flash',
            'gemini-2.5-flash-lite',
            'gemini-flash-latest',
            'gemini-flash-lite-latest',
            'gemini-2.5-pro'
        ]
        for m in fallback_list:
            if m not in candidate_models:
                candidate_models.append(m)
        
        last_error = None
        for model in candidate_models:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
            try:
                response = requests.post(url, json=payload, headers=headers)
                response.raise_for_status()
                
                data = response.json()
                text = data['candidates'][0]['content']['parts'][0]['text']
                if model != self.model:
                    print(f"✓ Chuyển sang model '{model}' thành công!")
                    self.model = model
                return text
                
            except requests.exceptions.HTTPError as e:
                status_code = getattr(e.response, 'status_code', 400)
                try:
                    error_body = response.json()
                    msg = error_body.get('error', {}).get('message', response.text)
                except Exception:
                    msg = response.text if 'response' in locals() else str(e)
                
                # 404: Not Found, 503: High Demand / Service Unavailable, 429: Rate Limit
                if status_code in (404, 503, 429):
                    last_error = Exception(f"Gemini API error ({status_code}): {msg}")
                    if status_code == 503:
                        print(f"⚠ Model '{model}' đang quá tải (503 High Demand). Đang tự động chuyển sang model khác...")
                        time.sleep(1.5)
                    elif status_code == 429:
                        print(f"⚠ Model '{model}' vượt giới hạn quota (429 Rate Limit). Đang chuyển sang model khác...")
                        time.sleep(2.0)
                    continue
                else:
                    raise Exception(f"Gemini API error ({status_code}): {msg}")
            except Exception as e:
                raise Exception(f"Gemini API error: {e}")
        
        if last_error:
            raise last_error
    
    def invoke(self, messages):
        """For compatibility with ChatOpenAI interface"""
        if isinstance(messages, list):
            prompt = messages[0].content if hasattr(messages[0], 'content') else str(messages[0])
        else:
            prompt = str(messages)
        
        text = self.generate(prompt)
        
        class Response:
            def __init__(self, text):
                self.content = text
        
        return Response(text)
