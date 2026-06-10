"""
Main entry point for the CTS Requirement Analyzer.
"""
import os
from pathlib import Path
from dotenv import load_dotenv
from core.parser import PumlParser
from core.sql_parser import SqlParser
from core.indexer import KnowledgeBase
from core.retriever import RAGEngine


def main():
    """Main function."""
    print("=" * 60)
    print("CTS Requirement Analyzer - RAG System")
    print("=" * 60)
    
    # Load environment variables
    load_dotenv()
    
    # Configuration
    docs_path = os.getenv('DOCS_PATH', '../md')
    sql_docs_path = os.getenv('SQL_DOCS_PATH', '')  # Optional SQL path
    vector_db_path = os.getenv('VECTOR_DB_PATH', './data/faiss_db')
    
    # Check configuration
    provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
    
    if provider == 'gemini':
        print("\n🌟 Using Google Gemini (FREE)")
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key or api_key == 'your_google_api_key_here':
            print("\n❌ ERROR: GOOGLE_API_KEY not found!")
            print("\n📝 How to get FREE Gemini API key:")
            print("1. Go to: https://makersuite.google.com/app/apikey")
            print("2. Click 'Create API Key'")
            print("3. Copy the key")
            print("4. Add to .env file: GOOGLE_API_KEY=your-key-here")
            print("\n✨ It's completely FREE - no credit card needed!")
            return
            
    elif provider == 'ollama':
        print("\n🦙 Using Ollama (Local LLM Mode)")
        print("Make sure Ollama is installed and running!")
        print("If not installed, download from: https://ollama.com/download")
        print("Then run: ollama pull llama3.2\n")
        
    else:  # openai
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key or api_key == 'your_openai_api_key_here':
            print("\n❌ ERROR: OPENAI_API_KEY not found!")
            print("Please either:")
            print("1. Set OPENAI_API_KEY in your .env file, OR")
            print("2. Set LLM_PROVIDER=gemini in your .env file (FREE!)")
            return
    
    # Initialize components
    print("\n📦 Initializing components...")
    puml_parser = PumlParser()
    sql_parser = SqlParser()
    kb = KnowledgeBase(persist_directory=vector_db_path)
    engine = RAGEngine(kb)
    
    # Check if we need to index documents
    if not os.path.exists(vector_db_path) or kb.vector_store is None:
        print(f"\n📂 No existing index found. Indexing documents...")
        
        all_chunks = []
        
        # Parse PlantUML files
        if os.path.exists(docs_path):
            print(f"\n🔍 Parsing PlantUML files from: {docs_path}")
            puml_chunks = puml_parser.parse_directory(docs_path)
            all_chunks.extend(puml_chunks)
            print(f"✓ Found {len(puml_chunks)} PlantUML document(s)")
        else:
            print(f"\n⚠ PlantUML path not found: {docs_path}")
        
        # Parse SQL files (if path is configured)
        if sql_docs_path and os.path.exists(sql_docs_path):
            print(f"\n🔍 Parsing SQL files from: {sql_docs_path}")
            sql_chunks = sql_parser.parse_directory(sql_docs_path)
            all_chunks.extend(sql_chunks)
            print(f"✓ Found {len(sql_chunks)} SQL document(s)")
        elif sql_docs_path:
            print(f"\n⚠ SQL path not found: {sql_docs_path}")
        else:
            print("\n💡 SQL_DOCS_PATH not configured, skipping SQL files")
        
        if not all_chunks:
            print("\n❌ ERROR: No documents found!")
            print("Please check DOCS_PATH and/or SQL_DOCS_PATH in your .env file.")
            return
        
        print(f"\n✓ Total documents to index: {len(all_chunks)}")
        
        # Ingest into vector store
        kb.ingest(all_chunks)
    else:
        print(f"\n✓ Using existing index from: {vector_db_path}")
    
    # Interactive mode
    print("\n" + "=" * 60)
    print("Ready! You can now analyze requirements.")
    print("=" * 60)
    print("\nCommands:")
    print("  - Type your requirement to analyze it")
    print("  - Type 'search <query>' to just search without analysis")
    print("  - Type 'reindex' to rebuild the index")
    print("  - Type 'quit' to exit")
    print()
    
    while True:
        try:
            user_input = input("\n💬 > ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() in ['quit', 'exit', 'q']:
                print("\n👋 Goodbye!")
                break
            
            if user_input.lower() == 'reindex':
                print(f"\n🔄 Reindexing documents...")
                kb.clear()
                
                all_chunks = []
                
                # Reindex PlantUML files
                if os.path.exists(docs_path):
                    print(f"  📄 Parsing PlantUML files from: {docs_path}")
                    puml_chunks = puml_parser.parse_directory(docs_path)
                    all_chunks.extend(puml_chunks)
                
                # Reindex SQL files
                if sql_docs_path and os.path.exists(sql_docs_path):
                    print(f"  📄 Parsing SQL files from: {sql_docs_path}")
                    sql_chunks = sql_parser.parse_directory(sql_docs_path)
                    all_chunks.extend(sql_chunks)
                
                print(f"\n✓ Reindexing {len(all_chunks)} total documents")
                kb.ingest(all_chunks)
                continue
            
            if user_input.lower().startswith('search '):
                query = user_input[7:].strip()
                print(f"\n🔍 Searching for: {query}")
                results = engine.retrieve_context(query, k=3)
                
                for i, result in enumerate(results, 1):
                    print(f"\n[Result {i}] {result.metadata.get('filename', 'unknown')}")
                    print(f"Type: {result.metadata.get('diagram_type', 'unknown')}")
                    print(f"Content preview: {result.content[:200]}...")
                continue
            
            # Analyze requirement
            result = engine.analyze(user_input, k=5)
            
            print("\n" + "=" * 60)
            print("📊 ANALYSIS RESULT")
            print("=" * 60)
            print(f"\n{result.analysis}")
            print("\n" + "-" * 60)
            print(f"📁 Sources: {', '.join(result.relevant_sources)}")
            print("=" * 60)
            
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")
            import traceback
            traceback.print_exc()


if __name__ == "__main__":
    main()
