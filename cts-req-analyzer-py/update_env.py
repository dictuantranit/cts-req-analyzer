"""
Script to update .env file with SQL_DOCS_PATH
"""
import os

def update_env_file():
    env_file = '.env'
    
    # SQL path provided by user
    sql_path = r'D:\TAKE NOTE FEATURE\CTS\Analysis\Code\CustomerTrackingSystem-DB\dbscript\CTS_CustomerTrackingSystem'
    
    # Convert to forward slashes for consistency
    sql_path_formatted = sql_path.replace('\\', '/')
    
    print("=" * 70)
    print("Updating .env file with SQL_DOCS_PATH")
    print("=" * 70)
    
    if not os.path.exists(env_file):
        print(f"\n❌ Error: {env_file} not found!")
        return
    
    # Read current .env content
    with open(env_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Update SQL_DOCS_PATH line
    updated = False
    for i, line in enumerate(lines):
        if line.startswith('SQL_DOCS_PATH='):
            old_value = line.strip()
            lines[i] = f'SQL_DOCS_PATH={sql_path_formatted}\n'
            updated = True
            print(f"\n✅ Updated line:")
            print(f"   Old: {old_value}")
            print(f"   New: SQL_DOCS_PATH={sql_path_formatted}")
            break
    
    if not updated:
        # If SQL_DOCS_PATH doesn't exist, add it
        lines.append(f'\nSQL_DOCS_PATH={sql_path_formatted}\n')
        print(f"\n✅ Added new line:")
        print(f"   SQL_DOCS_PATH={sql_path_formatted}")
    
    # Write back to .env
    with open(env_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print(f"\n{'=' * 70}")
    print("✅ .env file updated successfully!")
    print(f"{'=' * 70}\n")
    
    # Verify the path exists
    if os.path.exists(sql_path):
        # Count SQL files
        sql_files = []
        for root, dirs, files in os.walk(sql_path):
            for file in files:
                if file.endswith('.sql'):
                    sql_files.append(os.path.join(root, file))
        
        print(f"📁 SQL Path: {sql_path}")
        print(f"✅ Path exists!")
        print(f"📊 Found {len(sql_files)} .sql file(s)")
        
        if sql_files:
            print(f"\n📄 Sample files:")
            for i, file in enumerate(sql_files[:5], 1):
                print(f"   {i}. {os.path.basename(file)}")
            if len(sql_files) > 5:
                print(f"   ... and {len(sql_files) - 5} more")
    else:
        print(f"\n⚠️  Warning: Path does not exist: {sql_path}")
        print("   Please verify the path is correct")
    
    print(f"\n💡 Next steps:")
    print("   1. Delete old index: rm -rf ./data/faiss_db")
    print("   2. Run: python main.py")
    print()

if __name__ == "__main__":
    update_env_file()
