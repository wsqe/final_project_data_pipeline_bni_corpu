from datetime import datetime, timedelta
import os
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.operators.empty import EmptyOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

# Konfigurasi Koneksi & Direktori Data
POSTGRES_CONN_ID = "postgres_etl"
DATASET_DIR = "/opt/airflow/include/dataset"

# Argumen default untuk manajemen eksekusi task
default_args = {
    "owner": "data_engineering",
    "depends_on_past": False,
    "start_date": datetime(2026, 1, 1),
    "email_on_failure": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
}

def copy_csv_to_staging(table_name, csv_filename):
    """
    Fungsi Python menggunakan PostgresHook untuk mengosongkan tabel staging
    dan memuat data dari file CSV menggunakan perintah COPY EXPERT.
    """
    pg_hook = PostgresHook(postgres_conn_id=POSTGRES_CONN_ID)
    csv_path = os.path.join(DATASET_DIR, csv_filename)
    
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"File tidak ditemukan: {csv_path}")
        
    conn = pg_hook.get_conn()
    cursor = conn.cursor()
    
    # Truncate untuk memastikan data staging bersih sebelum diisi data baru
    cursor.execute(f"TRUNCATE TABLE {table_name};")
    
    # Eksekusi COPY untuk performa loading data skala besar yang optimal
    copy_sql = f"""
        COPY {table_name} 
        FROM STDIN 
        WITH (FORMAT CSV, HEADER true, DELIMITER ',');
    """
    with open(csv_path, 'r') as f:
        cursor.copy_expert(sql=copy_sql, file=f)
        
    conn.commit()
    cursor.close()
    conn.close()
    print(f"Berhasil load {csv_filename} ke {table_name}")

# Inisialisasi Objek DAG (Menggunakan 'schedule' sesuai standar Airflow v3)
with DAG(
    "dag_etl_banking_star_schema",
    default_args=default_args,
    description="Pipeline ETL untuk memproses data transaksi perbankan ke dalam Star Schema",
    schedule="@daily", 
    catchup=False,
    template_searchpath=['/opt/airflow/include'], # Mengarahkan pembacaan file SQL eksternal
) as dag:

    # 1. Start Checkpoint
    start_pipeline = EmptyOperator(task_id="start_pipeline")
    
    # 2. Inisialisasi Skema Tabel (DDL)
    initialize_schema = SQLExecuteQueryOperator(
        task_id="initialize_schema",
        sql="sql/create_tables.sql", 
        conn_id=POSTGRES_CONN_ID
    )

    # Mapping nama tabel staging ke nama file CSV yang dihasilkan generator
    sources = {
        "stg_transaction": "transactions.csv",
        "stg_customers": "customers.csv",
        "stg_fraud_labels": "fraud_labels.csv",
        "stg_branches": "branches.csv",
        "stg_channels": "channels.csv",
        "stg_accounts": "accounts.csv",
        "stg_date": "dim_date.csv"
    }

    # 3. Membuat Loop Task untuk Ekstraksi Staging secara Paralel
    extract_tasks = []
    for table, file_name in sources.items():
        task = PythonOperator(
            task_id=f"extract_{table}",
            python_callable=copy_csv_to_staging,
            op_kwargs={"table_name": table, "csv_filename": file_name}
        )
        extract_tasks.append(task)

    # 4. Checkpoint untuk menandai fase ekstraksi selesai seluruhnya
    extract_completed = EmptyOperator(task_id="extract_completed")

    # 5. Eksekusi Proses Transformasi & Pembuatan Star Schema
    transform_and_load = SQLExecuteQueryOperator(
        task_id="transform_load_star_schema",
        sql="sql/transform_load.sql",
        conn_id=POSTGRES_CONN_ID
    )

    # 6. End Checkpoint
    end_pipeline = EmptyOperator(task_id="end_pipeline")

    # ============================================================================
    # ALUR KETERGANTUNGAN PIPELINE (DEPENDENCY MAPPING)
    # ============================================================================
    start_pipeline >> initialize_schema
    
    # Seluruh proses ekstraksi berjalan paralel setelah DDL sukses
    for task in extract_tasks:
        initialize_schema >> task >> extract_completed
        
    # Fase transformasi dijalankan setelah seluruh tabel staging terisi penuh
    extract_completed >> transform_and_load >> end_pipeline