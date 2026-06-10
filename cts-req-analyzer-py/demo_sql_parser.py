"""
Demo script: Parse the example SQL file and show results.
"""
from core.sql_parser import SqlParser
import os

def main():
    print("=" * 80)
    print("SQL PARSER DEMO - Example Procedures")
    print("=" * 80)
    
    # Path to example file
    example_file = "example_procedures.sql"
    
    if not os.path.exists(example_file):
        print(f"\n❌ Error: {example_file} not found!")
        print("Please run this script from the project root directory.")
        return
    
    # Initialize parser
    parser = SqlParser()
    
    print(f"\n📄 Parsing file: {example_file}\n")
    
    # Parse the file
    try:
        chunks = parser.parse_file(example_file)
        
        print(f"✅ Successfully parsed {len(chunks)} stored procedure(s)\n")
        print("=" * 80)
        
        # Display each procedure
        for i, chunk in enumerate(chunks, 1):
            metadata = chunk.metadata
            
            print(f"\n{'█' * 80}")
            print(f"PROCEDURE #{i}: {metadata.get('procedure_name', 'Unknown')}")
            print(f"{'█' * 80}\n")
            
            # Basic info
            print(f"📌 File: {metadata.get('filename', 'N/A')}")
            print(f"📌 Type: {metadata.get('type', 'N/A')}")
            
            # Parameters
            if 'parameters' in metadata:
                print(f"\n📝 Parameters ({len(metadata['parameters'].split(', '))} total):")
                params = metadata['parameters'].split(', ')
                for param in params:
                    print(f"   • @{param}")
            else:
                print(f"\n📝 Parameters: None")
            
            # Tables
            if 'tables' in metadata:
                print(f"\n📊 Tables Used ({len(metadata['tables'].split(', '))} total):")
                tables = list(set(metadata['tables'].split(', ')))  # Remove duplicates
                for table in sorted(tables):
                    print(f"   • {table}")
            else:
                print(f"\n📊 Tables Used: None")
            
            # Called procedures
            if 'called_procedures' in metadata:
                print(f"\n🔗 Called Procedures ({len(metadata['called_procedures'].split(', '))} total):")
                procs = list(set(metadata['called_procedures'].split(', ')))
                for proc in sorted(procs):
                    print(f"   • {proc}")
            else:
                print(f"\n🔗 Called Procedures: None")
            
            # Content preview
            print(f"\n📄 Content Preview (first 400 chars):")
            print("─" * 80)
            preview_lines = chunk.content[:400].split('\n')
            for line in preview_lines:
                print(f"   {line}")
            if len(chunk.content) > 400:
                print("   ...")
            print("─" * 80)
        
        # Summary
        print(f"\n{'=' * 80}")
        print("📊 SUMMARY")
        print(f"{'=' * 80}\n")
        
        all_tables = set()
        all_called_procs = set()
        all_params = []
        
        for chunk in chunks:
            metadata = chunk.metadata
            if 'tables' in metadata:
                all_tables.update(metadata['tables'].split(', '))
            if 'called_procedures' in metadata:
                all_called_procs.update(metadata['called_procedures'].split(', '))
            if 'parameters' in metadata:
                all_params.extend(metadata['parameters'].split(', '))
        
        print(f"📌 Total Procedures: {len(chunks)}")
        print(f"📊 Unique Tables: {len(all_tables)}")
        print(f"🔗 Unique Called Procedures: {len(all_called_procs)}")
        print(f"📝 Total Parameters: {len(all_params)}")
        
        if all_tables:
            print(f"\n📊 All Tables Used:")
            for table in sorted(all_tables):
                print(f"   • {table}")
        
        if all_called_procs:
            print(f"\n🔗 All Called Procedures:")
            for proc in sorted(all_called_procs):
                print(f"   • {proc}")
        
        print(f"\n{'=' * 80}")
        print("✅ DEMO COMPLETED SUCCESSFULLY!")
        print(f"{'=' * 80}\n")
        
        # Next steps
        print("💡 Next Steps:")
        print("   1. Add your SQL files to a directory")
        print("   2. Set SQL_DOCS_PATH in .env file")
        print("   3. Run: python main.py")
        print("   4. Query: 'Which procedures use CTS_Bet table?'")
        print()
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
