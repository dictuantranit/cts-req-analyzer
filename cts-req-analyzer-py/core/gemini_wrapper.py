"""
Simple Gemini API wrapper using requests (works with Python 3.7+)
"""
import os
import requests
import json


class SimpleGemini:
    """Simple wrapper for Google Gemini API using REST"""
    
    def __init__(self, api_key=None):
        self.api_key = api_key or os.getenv('GOOGLE_API_KEY')
        if not self.api_key:
            raise ValueError("GOOGLE_API_KEY not found")
        
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
    
    def __call__(self, prompt):
        """Generate content from prompt"""
        return self.generate(prompt)
    
    def generate(self, prompt):
        """Generate content using Gemini API"""
        url = f"{self.base_url}?key={self.api_key}"
        
        payload = {
            "contents": [{
                "parts": [{
                    "text": prompt
                }]
            }]
        }
        
        headers = {
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(url, json=payload, headers=headers)
            response.raise_for_status()
            
            data = response.json()
            text = data['candidates'][0]['content']['parts'][0]['text']
            return text
            
        except Exception as e:
            raise Exception(f"Gemini API error: {e}")
    
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
