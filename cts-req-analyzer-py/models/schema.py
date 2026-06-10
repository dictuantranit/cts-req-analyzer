"""
Data models for the RAG system.
"""
from typing import Dict, List, Optional
from pydantic import BaseModel


class DocumentChunk(BaseModel):
    """Represents a chunk of a document with metadata."""
    content: str
    metadata: Dict[str, str]
    
    class Config:
        arbitrary_types_allowed = True


class RetrievalResult(BaseModel):
    """Represents a search result from the vector store."""
    content: str
    source: str
    score: Optional[float] = None
    metadata: Dict[str, str] = {}


class AnalysisResult(BaseModel):
    """Represents the final analysis result from the RAG engine."""
    requirement: str
    analysis: str
    relevant_sources: List[str]
    confidence: Optional[str] = None
