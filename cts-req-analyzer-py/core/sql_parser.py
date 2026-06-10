"""
SQL Parser for extracting meaningful chunks from .sql files (stored procedures).
"""
import os
import re
from typing import List
from pathlib import Path
from models.schema import DocumentChunk


class SqlParser:
    """Parser for SQL files (stored procedures)."""
    
    def __init__(self):
        """Initialize the parser."""
        pass
    
    def parse_file(self, file_path: str) -> List[DocumentChunk]:
        """
        Parse a SQL file into chunks.
        
        For stored procedures, we treat each procedure as one chunk.
        If no procedure markers found, treat the whole file as one chunk.
        
        Args:
            file_path: Path to the .sql file
            
        Returns:
            List of DocumentChunk objects
        """
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Try to split by stored procedures
        chunks = self._split_by_procedures(file_path, content)
        
        # If no procedures found, treat whole file as one chunk
        if not chunks:
            metadata = self._extract_metadata(file_path, content)
            chunks = [
                DocumentChunk(
                    content=content,
                    metadata=metadata
                )
            ]
        
        return chunks
    
    def _split_by_procedures(self, file_path: str, content: str) -> List[DocumentChunk]:
        """
        Split SQL file by stored procedures.
        
        Looks for patterns like:
        - CREATE PROCEDURE [name]
        - ALTER PROCEDURE [name]
        - CREATE OR REPLACE PROCEDURE [name]
        
        Args:
            file_path: Path to the file
            content: File content
            
        Returns:
            List of DocumentChunk objects, one per procedure
        """
        chunks = []
        
        # Pattern to find procedure definitions
        # Matches: CREATE/ALTER PROCEDURE [schema].[name] or just [name]
        proc_pattern = r'(?:CREATE|ALTER)(?:\s+OR\s+REPLACE)?\s+(?:PROCEDURE|PROC)\s+(?:\[?(\w+)\]?\.)?\[?(\w+)\]?'
        
        matches = list(re.finditer(proc_pattern, content, re.IGNORECASE))
        
        if not matches:
            return []
        
        for i, match in enumerate(matches):
            # Extract procedure content
            start_pos = match.start()
            
            # Find end position (start of next procedure or end of file)
            if i < len(matches) - 1:
                end_pos = matches[i + 1].start()
            else:
                end_pos = len(content)
            
            proc_content = content[start_pos:end_pos].strip()
            
            # Extract procedure name
            schema = match.group(1) if match.group(1) else None
            proc_name = match.group(2)
            full_name = f"{schema}.{proc_name}" if schema else proc_name
            
            # Extract metadata for this procedure
            metadata = self._extract_procedure_metadata(
                file_path, 
                proc_content, 
                full_name
            )
            
            chunks.append(
                DocumentChunk(
                    content=proc_content,
                    metadata=metadata
                )
            )
        
        return chunks
    
    def _extract_procedure_metadata(self, file_path: str, content: str, proc_name: str) -> dict:
        """
        Extract metadata from a stored procedure.
        
        Args:
            file_path: Path to the file
            content: Procedure content
            proc_name: Name of the procedure
            
        Returns:
            Dictionary of metadata
        """
        path_obj = Path(file_path)
        
        metadata = {
            'source': file_path,
            'filename': path_obj.name,
            'type': 'sql',
            'directory': path_obj.parent.name,
            'procedure_name': proc_name
        }
        
        # Extract parameters
        params = self._extract_parameters(content)
        if params:
            metadata['parameters'] = ', '.join(params[:10])  # Limit to 10
        
        # Extract referenced tables
        tables = self._extract_tables(content)
        if tables:
            metadata['tables'] = ', '.join(tables[:10])  # Limit to 10
        
        # Extract other stored procedures called
        called_procs = self._extract_called_procedures(content)
        if called_procs:
            metadata['called_procedures'] = ', '.join(called_procs[:10])
        
        return metadata
    
    def _extract_metadata(self, file_path: str, content: str) -> dict:
        """
        Extract metadata from the file path and content (for non-procedure files).
        
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
            'type': 'sql',
            'directory': path_obj.parent.name
        }
        
        # Extract tables even if no procedure found
        tables = self._extract_tables(content)
        if tables:
            metadata['tables'] = ', '.join(tables[:10])
        
        return metadata
    
    def _extract_parameters(self, content: str) -> List[str]:
        """
        Extract parameter names from stored procedure.
        
        Looks for patterns like: @ParamName type
        
        Args:
            content: Procedure content
            
        Returns:
            List of parameter names
        """
        # Pattern: @ParameterName followed by data type
        param_pattern = r'@(\w+)\s+(?:AS\s+)?(?:INT|VARCHAR|NVARCHAR|DATETIME|BIT|DECIMAL|FLOAT|BIGINT|SMALLINT|TINYINT|CHAR|NCHAR|TEXT|NTEXT)'
        
        matches = re.findall(param_pattern, content, re.IGNORECASE)
        return list(set(matches))  # Remove duplicates
    
    def _extract_tables(self, content: str) -> List[str]:
        """
        Extract table names from SQL content.
        
        Looks for patterns like:
        - FROM [table]
        - JOIN [table]
        - INTO [table]
        - UPDATE [table]
        - CTS_* patterns
        
        Args:
            content: SQL content
            
        Returns:
            List of table names
        """
        tables = []
        
        # Pattern 1: FROM/JOIN/INTO/UPDATE [schema].[table] or [table]
        table_pattern = r'(?:FROM|JOIN|INTO|UPDATE)\s+(?:\[?(\w+)\]?\.)?\[?(\w+)\]?'
        matches = re.findall(table_pattern, content, re.IGNORECASE)
        
        for match in matches:
            schema, table = match
            if table and not table.upper() in ['DELETED', 'INSERTED', 'SELECT']:  # Exclude SQL keywords
                full_name = f"{schema}.{table}" if schema else table
                tables.append(full_name)
        
        # Pattern 2: Look for CTS_ prefixed identifiers
        cts_pattern = r'\b(CTS_\w+)\b'
        cts_matches = re.findall(cts_pattern, content, re.IGNORECASE)
        tables.extend(cts_matches)
        
        return list(set(tables))  # Remove duplicates
    
    def _extract_called_procedures(self, content: str) -> List[str]:
        """
        Extract names of other stored procedures called within this procedure.
        
        Looks for patterns like:
        - EXEC [procedure]
        - EXECUTE [procedure]
        - SP_* patterns
        
        Args:
            content: Procedure content
            
        Returns:
            List of procedure names
        """
        procs = []
        
        # Pattern: EXEC/EXECUTE [schema].[proc] or [proc]
        exec_pattern = r'(?:EXEC|EXECUTE)\s+(?:\[?(\w+)\]?\.)?\[?(\w+)\]?'
        matches = re.findall(exec_pattern, content, re.IGNORECASE)
        
        for match in matches:
            schema, proc = match
            if proc:
                full_name = f"{schema}.{proc}" if schema else proc
                procs.append(full_name)
        
        # Pattern: Look for SP_ prefixed identifiers
        sp_pattern = r'\b(SP_\w+)\b'
        sp_matches = re.findall(sp_pattern, content, re.IGNORECASE)
        procs.extend(sp_matches)
        
        return list(set(procs))  # Remove duplicates
    
    def parse_directory(self, directory_path: str, pattern: str = "**/*.sql") -> List[DocumentChunk]:
        """
        Parse all SQL files in a directory.
        
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
                print(f"✓ Parsed: {file_path.name} ({len(chunks)} procedure(s))")
            except Exception as e:
                print(f"✗ Error parsing {file_path.name}: {e}")
        
        return all_chunks
