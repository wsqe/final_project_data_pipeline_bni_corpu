-- ============================================================================
-- 1. STAGING LAYER TABLES
-- ============================================================================
CREATE TABLE IF NOT EXISTS stg_transaction (
    transaction_id INT,
    transaction_code VARCHAR(50),
    account_id INT,
    customer_id INT,
    branch_id INT,
    channel_id INT,
    transaction_date DATE,
    transaction_at TIMESTAMP,
    transaction_type VARCHAR(50),
    amount NUMERIC(15, 2),
    balance_before NUMERIC(15, 2),
    balance_after NUMERIC(15, 2),
    status VARCHAR(20),
    reference_no VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS stg_customers (
    customer_id INT,
    customer_code VARCHAR(50),
    full_name VARCHAR(100),
    gender VARCHAR(1),
    birth_date DATE,
    email VARCHAR(100),
    phone VARCHAR(30),
    segment VARCHAR(20),
    job_segment VARCHAR(50),
    city VARCHAR(50),
    province VARCHAR(50),
    registration_date DATE,
    branch_id INT,
    is_active BOOLEAN,
    credit_score INT,
    estimated_salary NUMERIC(15, 2)
);

CREATE TABLE IF NOT EXISTS stg_fraud_labels (
    transaction_id INT,
    transaction_code VARCHAR(50),
    is_fraud BOOLEAN,
    fraud_type VARCHAR(50),
    fraud_score NUMERIC(5, 4),
    flagged_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS stg_branches (
    branch_id INT,
    branch_code VARCHAR(50),
    branch_name VARCHAR(100),
    city VARCHAR(50),
    province VARCHAR(50),
    region VARCHAR(50),
    branch_type VARCHAR(20),
    open_date DATE,
    is_active BOOLEAN
);

CREATE TABLE IF NOT EXISTS stg_channels (
    channel_id INT,
    channel_code VARCHAR(50),
    channel_name VARCHAR(50),
    channel_category VARCHAR(50),
    is_digital BOOLEAN,
    description TEXT
);

CREATE TABLE IF NOT EXISTS stg_accounts (
    account_id INT,
    account_no VARCHAR(50),
    account_type VARCHAR(50),
    product_name VARCHAR(100),
    currency VARCHAR(10),
    open_date DATE,
    close_date DATE,
    status VARCHAR(20),
    interest_rate NUMERIC(5, 2),
    customer_id INT,
    branch_id INT
);

CREATE TABLE IF NOT EXISTS stg_date (
    date_id INT,
    full_date DATE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    week_of_year INT,
    day_of_month INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN
);

-- ============================================================================
-- 2. STAR SCHEMA LAYER (DIMENSIONAL DATA WAREHOUSE)
-- ============================================================================
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_key SERIAL PRIMARY KEY,
    customer_id INT UNIQUE,
    full_name VARCHAR(100),
    segment VARCHAR(20),
    city VARCHAR(50),
    job_segment VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_channels (
    channel_key SERIAL PRIMARY KEY,
    channel_id INT UNIQUE,
    channel_name VARCHAR(50),
    is_digital BOOLEAN,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_branches (
    branch_key SERIAL PRIMARY KEY,
    branch_id INT UNIQUE,
    branch_name VARCHAR(100),
    region VARCHAR(50),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_accounts (
    account_key SERIAL PRIMARY KEY,
    account_id INT UNIQUE,
    customer_id INT,
    account_type VARCHAR(50),
    product_name VARCHAR(100),
    status VARCHAR(20),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE UNIQUE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    week_of_year INT,
    day_of_month INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekend BOOLEAN,
    is_holiday BOOLEAN
);

CREATE TABLE IF NOT EXISTS fact_transactions (
    transaction_key SERIAL PRIMARY KEY,
    transaction_id INT UNIQUE,
    account_key INT REFERENCES dim_accounts(account_key),
    customer_key INT REFERENCES dim_customers(customer_key),
    branch_key INT REFERENCES dim_branches(branch_key),
    channel_key INT REFERENCES dim_channels(channel_key),
    date_key INT REFERENCES dim_date(date_key),
    amount NUMERIC(15, 2),
    balance_after NUMERIC(15, 2),
    transaction_type VARCHAR(50),
    status VARCHAR(20),
    is_fraud BOOLEAN DEFAULT FALSE,
    fraud_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);