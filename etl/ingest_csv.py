import hashlib
import os
import re
import sys
from glob import glob

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

MAX_IDENTIFIER_LENGTH = 128


def build_connection_string(database: str | None = None) -> str:
    """Assemble a SQLAlchemy connection string using environment variables."""
    server = os.environ["MSSQL_HOST"]
    database = database or os.environ["MSSQL_DB"]
    username = os.environ["MSSQL_USER"]
    password = os.environ["MSSQL_PASSWORD"]
    port = os.environ.get("MSSQL_PORT", "1433")
    driver = os.environ.get("ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    safe_db = database.replace("]", "").replace("[", "")
    return (
        f"mssql+pyodbc://{username}:{password}@{server},{port}/{safe_db}"
        f"?driver={driver.replace(' ', '+')}"
    )


def resolve_workbook_paths() -> list[str]:
    """Return all CSV file paths recursively inside the data directory."""
    data_dir = os.environ.get("DATA_PATH", "data")
    pattern = os.path.join(data_dir, "**", "*.csv")
    csv_files = glob(pattern, recursive=True)

    if not csv_files:
        raise FileNotFoundError(
            f"No CSV files found under '{data_dir}'. "
            "Add .csv files or check DATA_PATH environment variable."
        )

    return csv_files


def sanitize_table_name(name: str) -> str:
    """Convert filenames or folder paths into SQL-safe snake_case table names."""
    slug = re.sub(r"[^0-9a-zA-Z]+", "_", name).strip("_").lower()
    return slug or "table"


def clamp_identifier(name: str, max_length: int = MAX_IDENTIFIER_LENGTH) -> str:
    """
    Ensure an identifier complies with SQL Server's 128-char limit.
    Long names are truncated and suffixed with an 8-char hash to avoid collisions.
    """
    if len(name) <= max_length:
        return name

    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    allowed = max_length - len(digest) - 1  # leave room for '_' separator

    if allowed <= 0:
        # Pathological case: fall back to hash only, truncated to max_length
        return digest[:max_length]

    return f"{name[:allowed]}_{digest}"


def derive_table_name(file_path: str) -> str:
    """
    Derive a SQL-safe table name from nested CSV file paths.
    Example:
        data/Exports/Country/csv/Trade_Map_-_List_of_exporters_for_the_selected_product.csv
        → exports_country_csv_trade_map_list_of_exporters_for_the_selected_product
    """
    relative = os.path.relpath(file_path, os.environ.get("DATA_PATH", "data"))
    name, _ = os.path.splitext(relative)
    slug = sanitize_table_name(name)
    return clamp_identifier(slug)


def ensure_database_exists() -> None:
    """
    Create the target database if it does not exist yet.
    SQL Server rejects the connection otherwise, causing every insert to fail.
    """
    target_db = os.environ["MSSQL_DB"]
    master_engine = create_engine(
        build_connection_string("master"),
        isolation_level="AUTOCOMMIT",
    )

    with master_engine.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM sys.databases WHERE name = :db_name"),
            {"db_name": target_db},
        ).scalar()

        if exists:
            return

        conn.execute(text(f"CREATE DATABASE [{target_db}]"))
        print(f"Created database '{target_db}'.")


def main() -> None:
    ensure_database_exists()
    connection_string = build_connection_string()
    file_paths = resolve_workbook_paths()

    print("Connecting to SQL Server...")
    print(
        f"Using Host: {os.environ['MSSQL_HOST']}, "
        f"Port: {os.environ.get('MSSQL_PORT', '1433')}, "
        f"Database: {os.environ['MSSQL_DB']}"
    )

    engine: Engine = create_engine(connection_string)

    print(f"Found {len(file_paths)} CSV files to process.\n")

    had_failures = False

    for file_path in file_paths:
        table_name = derive_table_name(file_path)
        print(f"Processing: {file_path} → Table: {table_name}")

        try:
            df = pd.read_csv(file_path)
        except Exception as e:
            print(f"❌ Failed to load {file_path}: {e}")
            had_failures = True
            continue

        print(f"Loaded {len(df)} rows from {file_path}. Loading into SQL...")

        try:
            df.to_sql(table_name, engine, if_exists="replace", index=False)
            print(f"✅ Loaded '{table_name}' successfully.\n")
        except Exception as e:
            print(f"❌ Failed to insert '{table_name}': {e}\n")
            had_failures = True

    if had_failures:
        print("⚠️ Finished with errors. Review the log entries above.")
        sys.exit(1)

    print("✅ All CSV files loaded into MSSQL!")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"Ingestion failed: {exc}", file=sys.stderr)
        sys.exit(1)
