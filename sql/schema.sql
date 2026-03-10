-- ──────────────────────────────────────────
-- Enable UUID generation
-- ──────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ──────────────────────────────────────────
-- ENUM types
-- ──────────────────────────────────────────
CREATE TYPE fund_type_enum AS ENUM ('VC', 'PE', 'SPV', 'RealEstate', 'Infrastructure', 'Other');
CREATE TYPE fund_status_enum AS ENUM ('Active', 'Closed', 'Liquidated');

CREATE TYPE investor_type_enum AS ENUM ('Individual', 'Institution', 'FamilyOffice', 'Corporate', 'Government');

CREATE TYPE commitment_status_enum AS ENUM ('Active', 'Defaulted', 'FullyCalled', 'Terminated');

CREATE TYPE call_status_enum AS ENUM ('Draft', 'Sent', 'PartiallyPaid', 'FullyPaid', 'Overdue', 'Cancelled');

CREATE TYPE allocation_status_enum AS ENUM ('Pending', 'Paid', 'PartiallyPaid', 'Defaulted', 'Waived');

CREATE TYPE payment_method_enum AS ENUM ('Wire', 'SEPA', 'ACH', 'Cheque', 'Other');

-- ──────────────────────────────────────────
-- fund
-- ──────────────────────────────────────────
CREATE TABLE fund (
    fund_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_name        VARCHAR(255)     NOT NULL,
    fund_type        fund_type_enum   NOT NULL,
    currency         CHAR(3)          NOT NULL,   -- ISO 4217 e.g. EUR, USD
    total_size       DECIMAL(20, 4),              -- target fund size
    vintage_year     SMALLINT,
    status           fund_status_enum NOT NULL DEFAULT 'Active',
    created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- investor
-- ──────────────────────────────────────────
CREATE TABLE investor (
    investor_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    investor_name    VARCHAR(255)        NOT NULL,
    investor_type    investor_type_enum  NOT NULL,
    email            VARCHAR(320)        NOT NULL UNIQUE,
    country          CHAR(2)             NOT NULL,  -- ISO 3166-1 alpha-2
    created_at       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────
-- commitment  (fund ←→ investor bridge)
-- ──────────────────────────────────────────
CREATE TABLE commitment (
    commitment_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id            UUID                   NOT NULL REFERENCES fund(fund_id),
    investor_id        UUID                   NOT NULL REFERENCES investor(investor_id),
    committed_amount   DECIMAL(20, 4)         NOT NULL CHECK (committed_amount > 0),
    called_amount      DECIMAL(20, 4)         NOT NULL DEFAULT 0
                           CHECK (called_amount >= 0),
    currency           CHAR(3)                NOT NULL,
    commitment_date    DATE                   NOT NULL,
    status             commitment_status_enum NOT NULL DEFAULT 'Active',
    created_at         TIMESTAMPTZ            NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ            NOT NULL DEFAULT NOW(),

    UNIQUE (fund_id, investor_id),  -- one commitment per investor per fund
    CONSTRAINT called_lte_committed CHECK (called_amount <= committed_amount)
);

CREATE INDEX idx_commitment_fund_id     ON commitment(fund_id);
CREATE INDEX idx_commitment_investor_id ON commitment(investor_id);

-- ──────────────────────────────────────────
-- capital_call
-- ──────────────────────────────────────────
CREATE TABLE capital_call (
    capital_call_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fund_id           UUID             NOT NULL REFERENCES fund(fund_id),
    call_number       SMALLINT         NOT NULL CHECK (call_number > 0),
    call_date         DATE             NOT NULL,
    due_date          DATE             NOT NULL CHECK (due_date >= call_date),
    total_amount      DECIMAL(20, 4)   NOT NULL CHECK (total_amount > 0),
    call_percentage   DECIMAL(6, 4)    CHECK (call_percentage > 0 AND call_percentage <= 1),
    purpose           VARCHAR(500),
    status            call_status_enum NOT NULL DEFAULT 'Draft',
    created_at        TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ      NOT NULL DEFAULT NOW(),

    UNIQUE (fund_id, call_number)  -- call numbers are sequential per fund
);

CREATE INDEX idx_capital_call_fund_id ON capital_call(fund_id);
CREATE INDEX idx_capital_call_status  ON capital_call(status);
CREATE INDEX idx_capital_call_due_date ON capital_call(due_date);

-- ──────────────────────────────────────────
-- capital_call_allocation
-- ──────────────────────────────────────────
CREATE TABLE capital_call_allocation (
    allocation_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capital_call_id    UUID                    NOT NULL REFERENCES capital_call(capital_call_id),
    commitment_id      UUID                    NOT NULL REFERENCES commitment(commitment_id),
    allocated_amount   DECIMAL(20, 4)          NOT NULL CHECK (allocated_amount > 0),
    paid_amount        DECIMAL(20, 4)          NOT NULL DEFAULT 0
                           CHECK (paid_amount >= 0),
    status             allocation_status_enum  NOT NULL DEFAULT 'Pending',
    created_at         TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ             NOT NULL DEFAULT NOW(),

    UNIQUE (capital_call_id, commitment_id),  -- one allocation per LP per call
    CONSTRAINT paid_lte_allocated CHECK (paid_amount <= allocated_amount)
);

CREATE INDEX idx_allocation_capital_call_id ON capital_call_allocation(capital_call_id);
CREATE INDEX idx_allocation_commitment_id   ON capital_call_allocation(commitment_id);
CREATE INDEX idx_allocation_status          ON capital_call_allocation(status);

-- ──────────────────────────────────────────
-- payment_instruction
-- ──────────────────────────────────────────
CREATE TABLE payment_instruction (
    instruction_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    allocation_id    UUID         NOT NULL REFERENCES capital_call_allocation(allocation_id),
    bank_name        VARCHAR(255) NOT NULL,
    iban             VARCHAR(34),              -- max IBAN length per ISO 13616
    bic_swift        VARCHAR(11),              -- 8 or 11 char BIC
    reference_code   VARCHAR(100) NOT NULL UNIQUE,
    sent_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_instruction_allocation_id ON payment_instruction(allocation_id);
CREATE INDEX idx_payment_instruction_reference     ON payment_instruction(reference_code);

-- ──────────────────────────────────────────
-- payment
-- ──────────────────────────────────────────
CREATE TABLE payment (
    payment_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    allocation_id     UUID                NOT NULL REFERENCES capital_call_allocation(allocation_id),
    amount_received   DECIMAL(20, 4)      NOT NULL CHECK (amount_received > 0),
    received_at       TIMESTAMPTZ         NOT NULL,
    payment_method    payment_method_enum NOT NULL DEFAULT 'Wire',
    reference_code    VARCHAR(100),                -- LP-provided wire reference
    notes             TEXT,
    created_at        TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_payment_allocation_id  ON payment(allocation_id);
CREATE INDEX idx_payment_received_at    ON payment(received_at);
CREATE INDEX idx_payment_reference_code ON payment(reference_code);

-- ──────────────────────────────────────────
-- Auto-update updated_at via trigger
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fund_updated_at
    BEFORE UPDATE ON fund
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_investor_updated_at
    BEFORE UPDATE ON investor
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_commitment_updated_at
    BEFORE UPDATE ON commitment
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_capital_call_updated_at
    BEFORE UPDATE ON capital_call
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_allocation_updated_at
    BEFORE UPDATE ON capital_call_allocation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();