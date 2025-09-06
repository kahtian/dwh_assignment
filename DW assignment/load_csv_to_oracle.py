"""
Simple CSV to Oracle Loader
Loads generated CSV files directly into Oracle using basic SQL
"""

import pandas as pd
import oracledb
import os

# Database configuration
DB_CONFIG = {
    'user': 'C##DWTASGM',
    'password': 'abc123',  # Update this
    'dsn': 'localhost:1521/xe'
}

def load_csv_to_table(csv_file: str, table_name: str, connection):
    """Load CSV file into Oracle table"""
    print(f"📂 Loading {csv_file} into {table_name}...")
    
    if not os.path.exists(csv_file):
        print(f"❌ File not found: {csv_file}")
        return False
    
    try:
        # Read CSV
        df = pd.read_csv(csv_file)
        print(f"   📊 Read {len(df):,} records from CSV")
        
        # Convert DataFrame to list of tuples
        records = [tuple(row) for row in df.values]
        
        # Prepare INSERT statement
        columns = ', '.join(df.columns)
        placeholders = ', '.join([':' + str(i+1) for i in range(len(df.columns))])
        sql = f"INSERT INTO {table_name} ({columns}) VALUES ({placeholders})"
        
        # Bulk insert in batches
        cursor = connection.cursor()
        batch_size = 5000
        total_inserted = 0
        
        for i in range(0, len(records), batch_size):
            batch = records[i:i + batch_size]
            cursor.executemany(sql, batch)
            total_inserted += len(batch)
            print(f"   ⚡ Inserted {total_inserted:,} / {len(records):,} records...")
            
            if i % 20000 == 0:  # Commit every 20K records
                connection.commit()
        
        connection.commit()
        cursor.close()
        print(f"✅ Successfully loaded {len(records):,} records into {table_name}")
        return True
        
    except Exception as e:
        print(f"❌ Error loading {csv_file}: {e}")
        return False

def main():
    print("🎯 CSV to Oracle Loader")
    print("=" * 40)
    
    # Check for CSV files
    csv_files = {
        'LOAN_FACT_data.csv': 'LOAN_FACT',
        'SALES_FACT_data.csv': 'SALES_FACT', 
        'PURCHASE_FACT_data.csv': 'PURCHASE_FACT',
        'RESERVATION_FACT_data.csv': 'RESERVATION_FACT'
    }
    
    missing_files = [f for f in csv_files.keys() if not os.path.exists(f)]
    if missing_files:
        print(f"❌ Missing CSV files: {missing_files}")
        print("Please run: python generate_csv_only.py first")
        return
    
    # Connect to database using python-oracledb (simpler than cx_Oracle)
    try:
        # Use thin mode (no Oracle Client needed)
        oracledb.init_oracle_client()  # Try thick mode first
        connection = oracledb.connect(**DB_CONFIG)
        print("✅ Database connected (thick mode)")
    except:
        try:
            connection = oracledb.connect(**DB_CONFIG)  # Fall back to thin mode
            print("✅ Database connected (thin mode)")
        except Exception as e:
            print(f"❌ Database connection failed: {e}")
            return
    
    try:
        # Load each CSV file
        for csv_file, table_name in csv_files.items():
            success = load_csv_to_table(csv_file, table_name, connection)
            if not success:
                print(f"⚠️ Failed to load {csv_file}, continuing with others...")
                continue
            print()
        
        # Verify final counts
        print("=" * 40)
        print("📊 FINAL VERIFICATION:")
        
        cursor = connection.cursor()
        for _, table_name in csv_files.items():
            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cursor.fetchone()[0]
            print(f"   {table_name}: {count:,} records")
        cursor.close()
        
        total_records = sum(cursor.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] 
                          for _, table in csv_files.items())
        print(f"   TOTAL: {total_records:,} records")
        print()
        print("🎉 CSV loading completed successfully!")
        
    except Exception as e:
        print(f"❌ Error during CSV loading: {e}")
    finally:
        if connection:
            connection.close()
            print("🔐 Database connection closed")

if __name__ == "__main__":
    main()
