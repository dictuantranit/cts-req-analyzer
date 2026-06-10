"""
PlantUML Parser for extracting meaningful chunks from .puml files.
"""
import os
from typing import List
from pathlib import Path
from models.schema import DocumentChunk


class PumlParser:
    """Parser for PlantUML files."""
    
    def __init__(self):
        """Initialize the parser."""
        pass
    
    def parse_file(self, file_path: str) -> List[DocumentChunk]:
        """
        Parse a PlantUML file into chunks.
        
        For MVP, we treat the entire file as one chunk, but extract metadata
        like filename, diagram type, and entities mentioned.
        
        Args:
            file_path: Path to the .puml file
            
        Returns:
            List of DocumentChunk objects
        """
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Extract metadata
        metadata = self._extract_metadata(file_path, content)
        
        # For MVP: whole file as one chunk
        # Future enhancement: split by @startuml/@enduml blocks,
        # or by notes, sequences, classes, etc.
        chunks = [
            DocumentChunk(
                content=content,
                metadata=metadata
            )
        ]
        
        return chunks
    
    def _extract_metadata(self, file_path: str, content: str) -> dict:
        """
        Extract metadata from the file path and content.
        
        Args:
            file_path: Path to the file
            content: File content
            
        Returns:
            Dictionary of metadata
        """
        path_obj = Path(file_path)
        
        metadata = {
            'source': file_path,
            'filename': path_obj.name,
            'type': 'puml',
            'directory': path_obj.parent.name
        }
        
        # Try to detect diagram type
        if '@startuml' in content:
            if 'sequence' in content.lower() or '->' in content:
                metadata['diagram_type'] = 'sequence'
            elif 'class' in content.lower():
                metadata['diagram_type'] = 'class'
            elif 'activity' in content.lower():
                metadata['diagram_type'] = 'activity'
            else:
                metadata['diagram_type'] = 'unknown'
        
        # Extract entities (tables, procedures, etc.)
        # Simple heuristic: look for common patterns
        entities = []
        for line in content.split('\n'):
            line = line.strip()
            # Look for database objects
            if 'CTS_' in line or 'SP_' in line:
                # Extract the identifier
                words = line.split()
                for word in words:
                    if 'CTS_' in word or 'SP_' in word:
                        entities.append(word.strip('":(),'))
        
        if entities:
            metadata['entities'] = ', '.join(list(set(entities))[:10])  # Limit to 10
        
        return metadata
    
    def parse_directory(self, directory_path: str, pattern: str = "**/*.puml") -> List[DocumentChunk]:
        """
        Parse all PlantUML files in a directory.
        
        Args:
            directory_path: Path to the directory
            pattern: Glob pattern for finding files
            
        Returns:
            List of all DocumentChunk objects from all files
        """
        all_chunks = []
        path_obj = Path(directory_path)
        
        for file_path in path_obj.glob(pattern):
            try:
                chunks = self.parse_file(str(file_path))
                all_chunks.extend(chunks)
                print(f"✓ Parsed: {file_path.name}")
            except Exception as e:
                print(f"✗ Error parsing {file_path.name}: {e}")
        
        return all_chunks
