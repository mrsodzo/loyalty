-- Migration: V1__init.sql
-- Description: Initial schema for MVP Rewards Platform

CREATE SCHEMA IF NOT EXISTS mvp;

-- Events table
CREATE TABLE mvp.events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name VARCHAR(100) NOT NULL,
    source_system VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    user_id UUID,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);

-- Loyalty rules
CREATE TABLE mvp.loyalty_rules (
    rule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    conditions JSONB NOT NULL,
    reward_type VARCHAR(50) NOT NULL,
    reward_value JSONB NOT NULL,
    active BOOLEAN DEFAULT true,
    priority INT DEFAULT 0
);

-- Accounts (Rewards Bank Account)
CREATE TABLE mvp.accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(15,2) DEFAULT 0,
    currency VARCHAR(10) DEFAULT 'VIRTUAL_RUB',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Rewards
CREATE TABLE mvp.rewards (
    reward_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    event_id UUID,
    type VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Transactions (Ledger)
CREATE TABLE mvp.transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES mvp.accounts(account_id),
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    balance_after DECIMAL(15,2) NOT NULL,
    reference_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Fulfillment requests
CREATE TABLE mvp.fulfillment_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reward_id UUID NOT NULL,
    user_id UUID NOT NULL,
    provider_id VARCHAR(100) DEFAULT 'MOCK_PROVIDER',
    status VARCHAR(20) DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT NOW(),
    fulfilled_at TIMESTAMP
);

-- Seed data: initial loyalty rules
INSERT INTO mvp.loyalty_rules (name, event_type, conditions, reward_type, reward_value, active, priority) VALUES
('New Subscriber Bonus', 'subscription.activated', '{}', 'POINTS', '{"fixed": 100}', true, 100),
('Recharge Cashback', 'subscription.recharged', '{"field": "amount", "operator": "gte", "value": 100}', 'CASHBACK', '{"percentage": 5, "max": 500}', true, 50),
('Package Bonus', 'package.purchased', '{}', 'POINTS', '{"fixed": 50}', true, 50);
