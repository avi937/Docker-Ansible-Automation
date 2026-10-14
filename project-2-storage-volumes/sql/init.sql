-- ==============================================================================
-- PROJECT 2: DOCKER PERSISTENT STORAGE & VOLUME LAB
-- File: sql/init.sql
-- Mounted into: /docker-entrypoint-initdb.d/init.sql
-- ==============================================================================

-- 1. Create Customer Accounts Table
CREATE TABLE IF NOT EXISTS customer_accounts (
    account_id SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    balance_usd NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Create Transaction Audit Log Table
CREATE TABLE IF NOT EXISTS transaction_audit_log (
    log_id SERIAL PRIMARY KEY,
    account_id INT REFERENCES customer_accounts(account_id) ON DELETE CASCADE,
    operation_type VARCHAR(50) NOT NULL,
    amount_usd NUMERIC(12, 2) NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);

-- 3. Seed Initial Production Records
INSERT INTO customer_accounts (customer_name, email, balance_usd, status)
VALUES 
    ('Avi Arora', 'avi.arora@devops-corp.internal', 150000.00, 'ACTIVE'),
    ('DevOps Team Lead', 'lead@devops-corp.internal', 85000.50, 'ACTIVE'),
    ('Cloud Architect', 'architect@devops-corp.internal', 120500.75, 'ACTIVE')
ON CONFLICT (email) DO NOTHING;

-- 4. Seed Audit History
INSERT INTO transaction_audit_log (account_id, operation_type, amount_usd, details)
VALUES 
    (1, 'INITIAL_DEPOSIT', 150000.00, 'Initial seed balance to verify Docker volume persistence'),
    (2, 'INITIAL_DEPOSIT', 85000.50, 'Initial seed balance to verify Docker volume persistence'),
    (3, 'INITIAL_DEPOSIT', 120500.75, 'Initial seed balance to verify Docker volume persistence');
