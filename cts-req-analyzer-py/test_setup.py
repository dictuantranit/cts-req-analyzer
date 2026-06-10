"""
Quick test script to verify the installation and basic functionality.
Run this after installing dependencies to ensure everything works.
"""
import sys

def test_imports():
    """Test if all required packages can be imported."""
    print("Testing imports...")
    
    try:
        import langchain
        print("✓ langchain")
    except ImportError as e:
        print(f"✗ langchain: {e}")
        return False
    
    try:
        from langchain_openai import OpenAIEmbeddings, ChatOpenAI
        print("✓ langchain_openai")
    except ImportError as e:
        print(f"✗ langchain_openai: {e}")
        return False
    
    try:
        from langchain_community.vectorstores import Chroma
        print("✓ langchain_community")
    except ImportError as e:
        print(f"✗ langchain_community: {e}")
        return False
    
    try:
        import chromadb
        print("✓ chromadb")
    except ImportError as e:
        print(f"✗ chromadb: {e}")
        return False
    
    try:
        from dotenv import load_dotenv
        print("✓ python-dotenv")
    except ImportError as e:
        print(f"✗ python-dotenv: {e}")
        return False
    
    try:
        from pydantic import BaseModel
        print("✓ pydantic")
    except ImportError as e:
        print(f"✗ pydantic: {e}")
        return False
    
    return True


def test_modules():
    """Test if our custom modules can be imported."""
    print("\nTesting custom modules...")
    
    try:
        from core.parser import PumlParser
        print("✓ core.parser")
    except ImportError as e:
        print(f"✗ core.parser: {e}")
        return False
    
    try:
        from core.indexer import KnowledgeBase
        print("✓ core.indexer")
    except ImportError as e:
        print(f"✗ core.indexer: {e}")
        return False
    
    try:
        from core.retriever import RAGEngine
        print("✓ core.retriever")
    except ImportError as e:
        print(f"✗ core.retriever: {e}")
        return False
    
    try:
        from models.schema import DocumentChunk, RetrievalResult, AnalysisResult
        print("✓ models.schema")
    except ImportError as e:
        print(f"✗ models.schema: {e}")
        return False
    
    return True


def test_env():
    """Test environment configuration."""
    print("\nTesting environment...")
    
    import os
    from dotenv import load_dotenv
    
    load_dotenv()
    
    api_key = os.getenv('OPENAI_API_KEY')
    if api_key and api_key != 'your_openai_api_key_here':
        print("✓ OPENAI_API_KEY is set")
        return True
    else:
        print("⚠ OPENAI_API_KEY not set or using default value")
        print("  Please update your .env file with a valid API key")
        return False


def main():
    """Run all tests."""
    print("=" * 60)
    print("CTS Requirement Analyzer - Installation Test")
    print("=" * 60)
    print()
    
    all_passed = True
    
    if not test_imports():
        all_passed = False
        print("\n❌ Import test failed!")
        print("Run: pip install -r requirements.txt")
    
    if not test_modules():
        all_passed = False
        print("\n❌ Module test failed!")
        print("Check if all files are in place")
    
    env_ok = test_env()
    
    print("\n" + "=" * 60)
    if all_passed:
        print("✅ All tests passed!")
        if env_ok:
            print("You can now run: python main.py")
        else:
            print("⚠ Please set OPENAI_API_KEY in .env before running main.py")
    else:
        print("❌ Some tests failed. Please fix the issues above.")
    print("=" * 60)
    
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
