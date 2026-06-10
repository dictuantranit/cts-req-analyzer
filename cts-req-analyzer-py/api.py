"""
FastAPI REST API for CTS Requirement Analyzer.
"""
import os
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Depends, Security, status
from fastapi.security import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv

from core.parser import PumlParser
from core.sql_parser import SqlParser
from core.indexer import KnowledgeBase
from core.retriever import RAGEngine

# Load environment variables
load_dotenv()

# API Configuration
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

# Initialize FastAPI app
app = FastAPI(
    title="CTS Requirement Analyzer API",
    description="REST API for analyzing requirements against technical documentation using RAG",
    version="1.0.0"
)

# CORS Configuration (allow all origins for now, can be restricted later)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict to specific domains in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global components (initialized on startup)
puml_parser: Optional[PumlParser] = None
sql_parser: Optional[SqlParser] = None
kb: Optional[KnowledgeBase] = None
engine: Optional[RAGEngine] = None


# Pydantic Models
class AnalyzeRequest(BaseModel):
    requirement: str = Field(..., description="The requirement to analyze", min_length=1)
    k: int = Field(5, description="Number of context documents to retrieve", ge=1, le=20)


class SearchRequest(BaseModel):
    query: str = Field(..., description="Search query", min_length=1)
    k: int = Field(3, description="Number of results to retrieve", ge=1, le=20)


class ReindexRequest(BaseModel):
    docs_path: Optional[str] = Field(None, description="Path to PlantUML documents directory (optional)")
    sql_docs_path: Optional[str] = Field(None, description="Path to SQL documents directory (optional)")


class SearchResultItem(BaseModel):
    filename: str
    diagram_type: str
    content_preview: str


class SearchResponse(BaseModel):
    query: str
    results: List[SearchResultItem]


class AnalysisResponse(BaseModel):
    requirement: str
    analysis: str
    relevant_sources: List[str]


class HealthResponse(BaseModel):
    status: str
    llm_provider: str
    vector_db_exists: bool
    docs_path: str
    sql_docs_path: Optional[str] = None


class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None


# Authentication
async def verify_api_key(api_key: str = Security(api_key_header)):
    """Verify API key from request header."""
    expected_api_key = os.getenv("API_KEY")
    
    if not expected_api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="API_KEY not configured on server"
        )
    
    if not api_key or api_key != expected_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key"
        )
    
    return api_key


# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize components on startup."""
    global puml_parser, sql_parser, kb, engine
    
    print("🚀 Starting CTS Requirement Analyzer API...")
    
    # Configuration
    docs_path = os.getenv('DOCS_PATH', '../md')
    sql_docs_path = os.getenv('SQL_DOCS_PATH', '')
    vector_db_path = os.getenv('VECTOR_DB_PATH', './data/faiss_db')
    
    # Check LLM configuration
    provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
    
    if provider == 'gemini':
        api_key = os.getenv('GOOGLE_API_KEY')
        if not api_key or api_key == 'your_google_api_key_here':
            raise RuntimeError("GOOGLE_API_KEY not configured")
    elif provider == 'openai':
        api_key = os.getenv('OPENAI_API_KEY')
        if not api_key or api_key == 'your_openai_api_key_here':
            raise RuntimeError("OPENAI_API_KEY not configured")
    
    # Initialize components
    puml_parser = PumlParser()
    sql_parser = SqlParser()
    kb = KnowledgeBase(persist_directory=vector_db_path)
    engine = RAGEngine(kb)
    
    # Check if index exists
    if not os.path.exists(vector_db_path) or kb.vector_store is None:
        print(f"⚠️  No existing index found. Please call /api/reindex to build the index.")
    else:
        print(f"✅ Loaded existing index from: {vector_db_path}")
    
    print("✅ API ready!")


# API Endpoints
@app.get("/", tags=["General"])
async def root():
    """Root endpoint with API information."""
    return {
        "message": "CTS Requirement Analyzer API",
        "docs": "/docs",
        "health": "/api/health"
    }


@app.get("/api/health", response_model=HealthResponse, tags=["General"])
async def health_check():
    """Health check endpoint."""
    docs_path = os.getenv('DOCS_PATH', '../md')
    sql_docs_path = os.getenv('SQL_DOCS_PATH', '')
    vector_db_path = os.getenv('VECTOR_DB_PATH', './data/faiss_db')
    provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
    
    return HealthResponse(
        status="healthy",
        llm_provider=provider,
        vector_db_exists=os.path.exists(vector_db_path),
        docs_path=docs_path,
        sql_docs_path=sql_docs_path if sql_docs_path else None
    )


@app.post("/api/analyze", response_model=AnalysisResponse, tags=["Analysis"])
async def analyze_requirement(
    request: AnalyzeRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Analyze a requirement against technical documentation.
    
    Requires authentication via X-API-Key header.
    """
    if not engine or not kb or kb.vector_store is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vector database not initialized. Please call /api/reindex first."
        )
    
    try:
        result = engine.analyze(request.requirement, k=request.k)
        
        return AnalysisResponse(
            requirement=result.requirement,
            analysis=result.analysis,
            relevant_sources=result.relevant_sources
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )


@app.post("/api/search", response_model=SearchResponse, tags=["Search"])
async def search_documentation(
    request: SearchRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Search technical documentation without full analysis.
    
    Requires authentication via X-API-Key header.
    """
    if not engine or not kb or kb.vector_store is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vector database not initialized. Please call /api/reindex first."
        )
    
    try:
        results = engine.retrieve_context(request.query, k=request.k)
        
        search_results = [
            SearchResultItem(
                filename=result.metadata.get('filename', 'unknown'),
                diagram_type=result.metadata.get('diagram_type', 'unknown'),
                content_preview=result.content[:200] + "..." if len(result.content) > 200 else result.content
            )
            for result in results
        ]
        
        return SearchResponse(
            query=request.query,
            results=search_results
        )
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Search failed: {str(e)}"
        )


@app.post("/api/reindex", tags=["Admin"])
async def reindex_documents(
    request: ReindexRequest = ReindexRequest(),
    api_key: str = Depends(verify_api_key)
):
    """
    Rebuild the vector database index from documentation.
    
    Requires authentication via X-API-Key header.
    """
    if not puml_parser or not sql_parser or not kb:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Components not initialized"
        )
    
    docs_path = request.docs_path or os.getenv('DOCS_PATH', '../md')
    sql_docs_path = request.sql_docs_path or os.getenv('SQL_DOCS_PATH', '')
    
    try:
        # Clear existing index
        kb.clear()
        
        all_chunks = []
        
        # Parse PlantUML files
        if os.path.exists(docs_path):
            puml_chunks = puml_parser.parse_directory(docs_path)
            all_chunks.extend(puml_chunks)
        
        # Parse SQL files
        if sql_docs_path and os.path.exists(sql_docs_path):
            sql_chunks = sql_parser.parse_directory(sql_docs_path)
            all_chunks.extend(sql_chunks)
        
        if not all_chunks:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No documents found in the specified directories"
            )
        
        # Ingest into vector store
        kb.ingest(all_chunks)
        
        return {
            "message": "Reindex completed successfully",
            "documents_processed": len(all_chunks),
            "docs_path": docs_path,
            "sql_docs_path": sql_docs_path if sql_docs_path else None
        }
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Reindex failed: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
