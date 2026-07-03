-- 1. Load Dimensi Date
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, week_of_year, day_of_month, day_of_week, day_name, is_weekend, is_holiday)
SELECT date_id, full_date, year, quarter, month, month_name, week_of_year, day_of_month, day_of_week, day_name, is_weekend, is_holiday
FROM stg_date
ON CONFLICT (date_key) DO NOTHING;

-- 2. Load Dimensi Customers
INSERT INTO dim_customers (customer_id, full_name, segment, city, job_segment, updated_at)
SELECT customer_id, full_name, segment, city, job_segment, NOW()
FROM stg_customers
ON CONFLICT (customer_id) DO UPDATE 
SET full_name = EXCLUDED.full_name,
    segment = EXCLUDED.segment,
    city = EXCLUDED.city,
    job_segment = EXCLUDED.job_segment,
    updated_at = NOW();

-- 3. Load Dimensi Channels
INSERT INTO dim_channels (channel_id, channel_name, is_digital, updated_at)
SELECT channel_id, channel_name, is_digital, NOW()
FROM stg_channels
ON CONFLICT (channel_id) DO UPDATE 
SET channel_name = EXCLUDED.channel_name,
    is_digital = EXCLUDED.is_digital,
    updated_at = NOW();

-- 4. Load Dimensi Branches
INSERT INTO dim_branches (branch_id, branch_name, region, updated_at)
SELECT branch_id, branch_name, region, NOW()
FROM stg_branches
ON CONFLICT (branch_id) DO UPDATE 
SET branch_name = EXCLUDED.branch_name,
    region = EXCLUDED.region,
    updated_at = NOW();

-- 5. Load Dimensi Accounts
INSERT INTO dim_accounts (account_id, customer_id, account_type, product_name, status, updated_at)
SELECT account_id, customer_id, account_type, product_name, status, NOW()
FROM stg_accounts
ON CONFLICT (account_id) DO UPDATE 
SET customer_id = EXCLUDED.customer_id,
    account_type = EXCLUDED.account_type,
    product_name = EXCLUDED.product_name,
    status = EXCLUDED.status,
    updated_at = NOW();

-- 6. Load Tabel Fakta: fact_transactions (Join dengan staging)
INSERT INTO fact_transactions (
    transaction_id, account_key, customer_key, branch_key, channel_key, 
    date_key, amount, balance_after, transaction_type, status, is_fraud, fraud_type, created_at
)
SELECT 
    stg.transaction_id,
    da.account_key,
    dc.customer_key,
    db.branch_key,
    dch.channel_key,
    TO_CHAR(stg.transaction_date, 'YYYYMMDD')::INT,
    stg.amount,
    stg.balance_after,
    stg.transaction_type,
    stg.status,
    COALESCE(frd.is_fraud, FALSE) as is_fraud,
    frd.fraud_type,
    NOW()
FROM stg_transaction stg
LEFT JOIN stg_fraud_labels frd ON stg.transaction_id = frd.transaction_id
LEFT JOIN dim_accounts da ON stg.account_id = da.account_id
LEFT JOIN dim_customers dc ON stg.customer_id = dc.customer_id
LEFT JOIN dim_branches db ON stg.branch_id = db.branch_id
LEFT JOIN dim_channels dch ON stg.channel_id = dch.channel_id
ON CONFLICT (transaction_id) DO UPDATE
SET account_key = EXCLUDED.account_key,
    customer_key = EXCLUDED.customer_key,
    branch_key = EXCLUDED.branch_key,
    channel_key = EXCLUDED.channel_key,
    date_key = EXCLUDED.date_key,
    amount = EXCLUDED.amount,
    balance_after = EXCLUDED.balance_after,
    transaction_type = EXCLUDED.transaction_type,
    status = EXCLUDED.status,
    is_fraud = EXCLUDED.is_fraud,
    fraud_type = EXCLUDED.fraud_type,
    created_at = NOW();