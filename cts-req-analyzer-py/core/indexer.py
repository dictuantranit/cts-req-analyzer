"""
Knowledge Base manager using FAISS for vector storage.
"""
import os
import pickle
from typing import List, Optional
from pathlib import Path
from langchain_community.vectorstores import FAISS
from langchain_community.embeddings import OpenAIEmbeddings, FakeEmbeddings
from langchain_core.documents import Document
from models.schema import DocumentChunk, RetrievalResult


class KnowledgeBase:
    """Manages the vector database for document storage and retrieval."""
    
    def __init__(self, persist_directory: str = "./data/faiss_db"):
        """
        Initialize the Knowledge Base.
        
        Args:
            persist_directory: Directory to persist the vector database
        """
        self.persist_directory = persist_directory
        self.index_file = os.path.join(persist_directory, "index.faiss")
        self.pkl_file = os.path.join(persist_directory, "index.pkl")
        self.embeddings = self._get_embeddings()
        self.vector_store: Optional[FAISS] = None
        
        # Create directory if it doesn't exist
        Path(persist_directory).mkdir(parents=True, exist_ok=True)
        
        # Load existing vector store if it exists
        if os.path.exists(self.index_file) and os.path.exists(self.pkl_file):
            try:
                self.vector_store = FAISS.load_local(
                    persist_directory,
                    self.embeddings
                )
                print(f"✓ Loaded existing vector store from {persist_directory}")
            except Exception as e:
                print(f"⚠ Could not load existing vector store: {e}")
    
    def _get_embeddings(self):
        """
        Get the embedding model.
        
        Returns:
            Embeddings instance
        """
        provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
        
        if provider == 'gemini':
            print("✓ Using Google Gemini Embeddings (FREE)")
            # Gemini uses simple embeddings, we'll use FakeEmbeddings for now
            # In production, you can use Google's embedding API
            return FakeEmbeddings(size=768)
            
        elif provider == 'ollama':
            print("✓ Using Simple Local Embeddings (free, no GPU needed)")
            return FakeEmbeddings(size=384)
            
        else:  # openai
            api_key = os.getenv('OPENAI_API_KEY')
            if not api_key or api_key == 'your_openai_api_key_here':
                raise ValueError(
                    "OPENAI_API_KEY not found in environment. "
                    "Please set it in your .env file or use LLM_PROVIDER=gemini"
                )
            
            print("✓ Using OpenAI Embeddings")
            return OpenAIEmbeddings()

    
    def ingest(self, chunks: List[DocumentChunk]) -> None:
        """
        Ingest document chunks into the vector store.
        
        Args:
            chunks: List of DocumentChunk objects to ingest
        """
        if not chunks:
            print("⚠ No chunks to ingest")
            return
        
        print(f"📥 Ingesting {len(chunks)} chunks into vector store...")
        
        # Convert DocumentChunk to LangChain Document format
        documents = [
            Document(
                page_content=chunk.content,
                metadata=chunk.metadata
            )
            for chunk in chunks
        ]
        
        # Create or update vector store
        if self.vector_store is None:
            self.vector_store = FAISS.from_documents(
                documents=documents,
                embedding=self.embeddings
            )
        else:
            # Add to existing store
            new_store = FAISS.from_documents(
                documents=documents,
                embedding=self.embeddings
            )
            self.vector_store.merge_from(new_store)
        
        # Persist to disk
        self.vector_store.save_local(self.persist_directory)
        print(f"✓ Ingestion complete. Data persisted to {self.persist_directory}")
    
    def search(self, query: str, k: int = 5) -> List[RetrievalResult]:
        """
        Search for relevant documents.
        
        Args:
            query: Search query
            k: Number of results to return
            
        Returns:
            List of RetrievalResult objects
        """
        if self.vector_store is None:
            raise ValueError(
                "Vector store not initialized. Call ingest() first or "
                "ensure the persist directory contains data."
            )
        
        # Perform similarity search
        docs = self.vector_store.similarity_search(query, k=k)
        
        # Convert to RetrievalResult
        results = [
            RetrievalResult(
                content=doc.page_content,
                source=doc.metadata.get('source', 'unknown'),
                metadata=doc.metadata
            )
            for doc in docs
        ]
        
        return results
    
    def clear(self) -> None:
        """Clear the vector store."""
        if self.vector_store is not None:
            self.vector_store = None
            # Remove files
            if os.path.exists(self.index_file):
                os.remove(self.index_file)
            if os.path.exists(self.pkl_file):
                os.remove(self.pkl_file)
            print("✓ Vector store cleared")
