"""Quick test to check if everything works"""
import sys
import os

print("=" * 60)
print("Testing imports...")
print("=" * 60)

try:
    print("\n1. Testing langchain...")
    import langchain
    print("   ✓ langchain OK")
except Exception as e:
    print(f"   ✗ langchain FAILED: {e}")
    sys.exit(1)

try:
    print("\n2. Testing openai...")
    import openai
    print("   ✓ openai OK")
except Exception as e:
    print(f"   ✗ openai FAILED: {e}")
    sys.exit(1)

try:
    print("\n3. Testing faiss...")
    import faiss
    print("   ✓ faiss OK")
except Exception as e:
    print(f"   ✗ faiss FAILED: {e}")
    sys.exit(1)

try:
    print("\n4. Testing dotenv...")
    from dotenv import load_dotenv
    print("   ✓ dotenv OK")
except Exception as e:
    print(f"   ✗ dotenv FAILED: {e}")
    sys.exit(1)

try:
    print("\n5. Testing pydantic...")
    from pydantic import BaseModel
    print("   ✓ pydantic OK")
except Exception as e:
    print(f"   ✗ pydantic FAILED: {e}")
    sys.exit(1)

try:
    print("\n6. Testing langchain components...")
    from langchain.vectorstores import FAISS
    from langchain.embeddings import OpenAIEmbeddings
    from langchain.chat_models import ChatOpenAI
    print("   ✓ langchain components OK")
except Exception as e:
    print(f"   ✗ langchain components FAILED: {e}")
    sys.exit(1)

try:
    print("\n7. Testing custom modules...")
    from models.schema import DocumentChunk
    print("   ✓ models.schema OK")
    
    from core.parser import PumlParser
    print("   ✓ core.parser OK")
except Exception as e:
    print(f"   ✗ custom modules FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "=" * 60)
print("✅ All imports successful!")
print("=" * 60)
print("\nYou can now run: python main.py")
