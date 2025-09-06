import pandas as pd
from holidays.countries.malaysia import Malaysia
from sqlalchemy import create_engine, text
import logging
import oracledb

# This script requires the following Python libraries:
# pip install pandas holidays sqlalchemy oracledb

# Initialize the Oracle client library.
# Ensure your Oracle client libraries (e.g., Instant Client) are installed and accessible.
oracledb.init_oracle_client()

# --- Configuration ---
# CORRECTED: Removed the 'mode' key for a standard connection.
DB_CONFIG = {
    'user': 'student3', # Change this according to your Oracle DB user
    'password': 'abcxyz',
    'dsn': 'localhost:1521/XE' # Change this according to your Oracle DB connection details
}

# Connection string for SQLAlchemy
DB_CONNECTION_STRING = (
    f"oracle+oracledb://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['dsn']}"
)

# CORRECTED: Since we removed the 'mode', this is no longer needed and has been removed.
# CONNECT_ARGS = {}

# Specify the Malaysian state/federal territory for holidays (e.g., 'KUL' for Kuala Lumpur)
MALAYSIA_STATE_SUBDIVISION = 'KUL'

# CORRECTED: Table names are now UPPERCASE to match how Oracle stores them.
DIM_TABLE = 'DATE_DIM'
STAGING_TABLE = 'DATE_DIM_HOLIDAY_STAGE'

# Set up logging to monitor the script's progress
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def run_holiday_update():
    """
    Connects to the Oracle database, gets Malaysian holiday data,
    and updates the DATE_DIM table with holiday information.
    """
    engine = None
    try:
        logging.info("Connecting to the Oracle database...")
        # CORRECTED: The `connect_args` parameter is no longer needed.
        engine = create_engine(DB_CONNECTION_STRING)

        # 1. Read existing dates from DATE_DIM
        with engine.connect() as connection:
            logging.info(f"Reading 'date_key' and 'cal_date' from '{DIM_TABLE}'...")
            sql_query = f'SELECT date_key, cal_date FROM {DIM_TABLE}'
            date_dim_df = pd.read_sql(sql_query, connection, index_col='cal_date', parse_dates=['cal_date'])

        if date_dim_df.empty:
            logging.warning(f"The '{DIM_TABLE}' table is empty. Nothing to update.")
            return

        # 2. Generate holiday data for the range of years found in the table
        start_year = date_dim_df.index.min().year
        end_year = date_dim_df.index.max().year
        logging.info(f"Generating Malaysia holidays from {start_year} to {end_year} for subdivision '{MALAYSIA_STATE_SUBDIVISION}'.")
        malaysia_holidays_dict = Malaysia(subdiv=MALAYSIA_STATE_SUBDIVISION, years=range(start_year, end_year + 1))
        holidays_df = pd.DataFrame(list(malaysia_holidays_dict.items()), columns=['holiday_date', 'festive_event'])
        holidays_df['holiday_date'] = pd.to_datetime(holidays_df['holiday_date'])

        # 3. Merge holiday data with the dates from the dimension table
        update_df = date_dim_df.merge(holidays_df, left_index=True, right_on='holiday_date', how='left')
        update_df['holiday_ind'] = 'N'
        update_df.loc[update_df['festive_event'].notna(), 'holiday_ind'] = 'Y'
        update_df['festive_event'] = update_df['festive_event'].fillna('').str.slice(0, 50)
        update_df.reset_index(drop=True, inplace=True)
        final_update_df = update_df[['date_key', 'holiday_ind', 'festive_event']]

        # 4. Use a staging table to perform an efficient MERGE operation
        with engine.begin() as connection:
            logging.info("Starting database transaction...")

            logging.info(f"Attempting to drop staging table '{STAGING_TABLE}' to ensure a clean slate.")
            try:
                connection.execute(text(f"DROP TABLE {STAGING_TABLE}"))
                logging.info(f"Existing staging table '{STAGING_TABLE}' was dropped.")
            except Exception as e:
                if "ORA-00942" in str(e): # ORA-00942: table or view does not exist
                    logging.info(f"Staging table '{STAGING_TABLE}' did not exist, which is expected. Continuing.")
                else:
                    raise e # Re-raise other errors

            logging.info(f"Creating and loading {len(final_update_df)} records into staging table '{STAGING_TABLE}'.")
            final_update_df.to_sql(
                STAGING_TABLE,
                connection,
                if_exists='replace',
                index=False,
                chunksize=1000
            )

            logging.info(f"Executing MERGE statement to update '{DIM_TABLE}' from '{STAGING_TABLE}'.")
            merge_sql = text(f"""
                MERGE INTO {DIM_TABLE} d
                USING {STAGING_TABLE} s
                ON (d.date_key = s.date_key)
                WHEN MATCHED THEN
                    UPDATE SET
                        d.holiday_ind = s.holiday_ind,
                        d.festive_event = s.festive_event
            """)
            result = connection.execute(merge_sql)
            logging.info(f"MERGE statement completed. {result.rowcount} rows might have been affected.")

            logging.info(f"Final cleanup: Dropping staging table '{STAGING_TABLE}'.")
            connection.execute(text(f"DROP TABLE {STAGING_TABLE}"))

        logging.info("Transaction committed successfully!")

    except Exception as e:
        logging.error(f"An error occurred: {e}")
        logging.error("Transaction has been automatically rolled back.")
    finally:
        if engine:
            engine.dispose()
            logging.info("Database connection closed.")

if __name__ == "__main__":
    run_holiday_update()
