"""
RAG Engine for requirement analysis.
"""
import os
from typing import List
from langchain_community.chat_models import ChatOpenAI
from langchain_community.llms import Ollama
from langchain_core.prompts import PromptTemplate, ChatPromptTemplate
from core.indexer import KnowledgeBase
from models.schema import RetrievalResult, AnalysisResult


class RAGEngine:
    """RAG Engine for analyzing requirements against technical documentation."""
    
    def __init__(self, knowledge_base: KnowledgeBase, model_name: str = "gpt-3.5-turbo"):
        """
        Initialize the RAG Engine.
        
        Args:
            knowledge_base: KnowledgeBase instance for retrieval
            model_name: OpenAI model name to use
        """
        self.kb = knowledge_base
        self.llm = self._get_llm(model_name)
        self.prompt_template = self._create_prompt_template()
    
    def _get_llm(self, model_name: str):
        """
        Get the LLM instance.
        
        Args:
            model_name: Name of the model
            
        Returns:
            LLM instance (ChatOpenAI, Gemini, or Ollama)
        """
        provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
        
        if provider == 'gemini':
            print("✓ Using Google Gemini (FREE)")
            from core.gemini_wrapper import SimpleGemini
            
            api_key = os.getenv('GOOGLE_API_KEY')
            if not api_key or api_key == 'your_google_api_key_here':
                raise ValueError(
                    "GOOGLE_API_KEY not found in environment. "
                    "Get free key at: https://makersuite.google.com/app/apikey"
                )
            
            return SimpleGemini(api_key=api_key)
            
        elif provider == 'ollama':
            print("✓ Using Ollama (local LLM)")
            ollama_model = os.getenv('OLLAMA_MODEL', 'llama3.2')
            return Ollama(model=ollama_model, temperature=0)
            
        else:  # openai
            api_key = os.getenv('OPENAI_API_KEY')
            if not api_key or api_key == 'your_openai_api_key_here':
                raise ValueError(
                    "OPENAI_API_KEY not found in environment. "
                    "Please set it in your .env file or use LLM_PROVIDER=gemini"
                )
            
            print("✓ Using OpenAI GPT")
            return ChatOpenAI(model=model_name, temperature=0)
    
    def _create_prompt_template(self) -> ChatPromptTemplate:
        """
        Create the prompt template for analysis.
        
        Returns:
            ChatPromptTemplate instance
        """
        template = """You are a technical analyst for a Customer Tracking System (CTS).
Your task is to analyze a new requirement against existing technical documentation.

The documentation is in PlantUML format, which describes system flows, database schemas, 
and business logic through diagrams.

REQUIREMENT:
{requirement}

RELEVANT TECHNICAL DOCUMENTATION:
{context}

Please analyze:
1. **Feasibility**: Is this requirement feasible based on the existing system?
2. **Impact Analysis**: Which components/files will be affected?
3. **Suggested Changes**: What modifications are needed?

Provide your analysis in clear, structured Markdown format.
"""
        
        return ChatPromptTemplate.from_template(template)
    
    def retrieve_context(self, query: str, k: int = 5) -> List[RetrievalResult]:
        """
        Retrieve relevant context for a query.
        
        Args:
            query: Search query
            k: Number of results to retrieve
            
        Returns:
            List of RetrievalResult objects
        """
        return self.kb.search(query, k=k)
    
    def analyze(self, requirement: str, k: int = 5) -> AnalysisResult:
        """
        Analyze a requirement using RAG.
        
        Args:
            requirement: The requirement to analyze
            k: Number of context documents to retrieve
            
        Returns:
            AnalysisResult object
        """
        print(f"\n🔍 Analyzing requirement: {requirement[:100]}...")
        
        # 1. Retrieve relevant context
        print(f"📚 Retrieving top {k} relevant documents...")
        context_results = self.retrieve_context(requirement, k=k)
        
        if not context_results:
            return AnalysisResult(
                requirement=requirement,
                analysis="⚠ No relevant documentation found. Cannot analyze requirement.",
                relevant_sources=[]
            )
        
        # 2. Format context
        context_str = "\n\n---\n\n".join([
            f"**Source**: {result.metadata.get('filename', 'unknown')}\n"
            f"**Type**: {result.metadata.get('diagram_type', 'unknown')}\n"
            f"**Content**:\n```plantuml\n{result.content[:1000]}\n```"
            for result in context_results
        ])
        
        # 3. Generate analysis
        print("🤖 Generating analysis with LLM...")
        
        provider = os.getenv('LLM_PROVIDER', 'gemini').lower()
        
        if provider == 'gemini':
            # Gemini uses simple string prompts
            prompt_text = self.prompt_template.format(
                requirement=requirement,
                context=context_str
            )
            response_text = self.llm(prompt_text)
            
        elif provider == 'ollama':
            # Ollama uses simple string prompts
            prompt_text = self.prompt_template.format(
                requirement=requirement,
                context=context_str
            )
            response_text = self.llm(prompt_text)
            
        else:  # openai
            # OpenAI uses message format
            messages = self.prompt_template.format_messages(
                requirement=requirement,
                context=context_str
            )
            response = self.llm.invoke(messages)
            response_text = response.content
        
        # 4. Create result
        sources = [r.metadata.get('filename', r.source) for r in context_results]
        
        result = AnalysisResult(
            requirement=requirement,
            analysis=response_text,
            relevant_sources=sources
        )
        
        print("✅ Analysis complete!")
        return result
    
    def analyze_simple(self, requirement: str, k: int = 3) -> str:
        """
        Simple analysis that just returns the text response.
        
        Args:
            requirement: The requirement to analyze
            k: Number of context documents to retrieve
            
        Returns:
            Analysis text
        """
        result = self.analyze(requirement, k=k)
        return result.analysis
