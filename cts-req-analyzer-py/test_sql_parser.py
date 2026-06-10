"""
Test script to demonstrate SQL parser capabilities.
"""
from core.sql_parser import SqlParser

# Sample SQL content for testing
SAMPLE_SQL = """
CREATE PROCEDURE dbo.SP_CTS_ProcessBet
    @BetId BIGINT,
    @UserId INT,
    @Amount DECIMAL(18,2),
    @MatchId INT
AS
BEGIN
    -- Insert bet record
    INSERT INTO CTS_Bet (BetId, UserId, Amount, MatchId, CreatedDate)
    VALUES (@BetId, @UserId, @Amount, @MatchId, GETDATE())
    
    -- Update user balance
    UPDATE CTS_User
    SET Balance = Balance - @Amount
    WHERE UserId = @UserId
    
    -- Log the transaction
    EXEC SP_LogTransaction @UserId, @BetId, 'BET_PLACED'
    
    -- Check match status
    SELECT * FROM CTS_Match m
    JOIN CTS_League l ON m.LeagueId = l.LeagueId
    WHERE m.MatchId = @MatchId
END
GO

CREATE PROCEDURE dbo.SP_CTS_GetUserBets
    @UserId INT,
    @FromDate DATETIME,
    @ToDate DATETIME
AS
BEGIN
    SELECT 
        b.*,
        m.MatchName,
        m.MatchDate
    FROM CTS_Bet b
    INNER JOIN CTS_Match m ON b.MatchId = m.MatchId
    WHERE b.UserId = @UserId
        AND b.CreatedDate BETWEEN @FromDate AND @ToDate
    ORDER BY b.CreatedDate DESC
    
    -- Also get summary
    EXEC SP_GetBetSummary @UserId
END
"""

def test_sql_parser():
    """Test the SQL parser with sample content."""
    print("=" * 70)
    print("SQL PARSER TEST")
    print("=" * 70)
    
    parser = SqlParser()
    
    # Create a temporary test file
    import tempfile
    import os
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(SAMPLE_SQL)
        temp_file = f.name
    
    try:
        print(f"\n📄 Parsing test SQL file: {os.path.basename(temp_file)}\n")
        
        chunks = parser.parse_file(temp_file)
        
        print(f"✅ Found {len(chunks)} stored procedure(s)\n")
        
        for i, chunk in enumerate(chunks, 1):
            print(f"\n{'─' * 70}")
            print(f"PROCEDURE #{i}")
            print(f"{'─' * 70}")
            
            metadata = chunk.metadata
            
            print(f"\n📌 Basic Info:")
            print(f"   • Procedure Name: {metadata.get('procedure_name', 'N/A')}")
            print(f"   • File: {metadata.get('filename', 'N/A')}")
            print(f"   • Type: {metadata.get('type', 'N/A')}")
            
            if 'parameters' in metadata:
                print(f"\n📝 Parameters:")
                params = metadata['parameters'].split(', ')
                for param in params:
                    print(f"   • @{param}")
            
            if 'tables' in metadata:
                print(f"\n📊 Tables Used:")
                tables = metadata['tables'].split(', ')
                for table in tables:
                    print(f"   • {table}")
            
            if 'called_procedures' in metadata:
                print(f"\n🔗 Called Procedures:")
                procs = metadata['called_procedures'].split(', ')
                for proc in procs:
                    print(f"   • {proc}")
            
            print(f"\n📄 Content Preview:")
            preview = chunk.content[:300].replace('\n', '\n   ')
            print(f"   {preview}...")
        
        print(f"\n{'=' * 70}")
        print("✅ TEST COMPLETED SUCCESSFULLY")
        print(f"{'=' * 70}\n")
        
    finally:
        # Clean up temp file
        os.unlink(temp_file)


def test_metadata_extraction():
    """Test metadata extraction from various SQL patterns."""
    print("\n" + "=" * 70)
    print("METADATA EXTRACTION TEST")
    print("=" * 70)
    
    parser = SqlParser()
    
    test_cases = [
        ("Parameters", "@UserId INT, @Amount DECIMAL(18,2)", 
         parser._extract_parameters),
        ("Tables", "SELECT * FROM CTS_Bet JOIN CTS_User ON ...", 
         parser._extract_tables),
        ("Procedures", "EXEC SP_LogActivity @UserId, 'action'", 
         parser._extract_called_procedures),
    ]
    
    for name, sample, func in test_cases:
        print(f"\n📌 Testing {name} Extraction:")
        print(f"   Input: {sample[:50]}...")
        result = func(sample)
        print(f"   Result: {result}")
    
    print(f"\n{'=' * 70}\n")


if __name__ == "__main__":
    test_sql_parser()
    test_metadata_extraction()
    
    print("\n💡 TIP: To test with your own SQL files:")
    print("   from core.sql_parser import SqlParser")
    print("   parser = SqlParser()")
    print("   chunks = parser.parse_directory('path/to/your/sql/files')")
    print()
