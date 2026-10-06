-- =============================================================================
-- AJADICO FILLING STATION MANAGEMENT SYSTEM
-- Supabase / PostgreSQL Production Schema (BRD v3 Compliant)
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean drop if recreating (for fresh installations)
-- DROP SCHEMA public CASCADE; CREATE SCHEMA public;

-- -----------------------------------------------------------------------------
-- 1. STATIONS & BRANCHES (§1, §2.1)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(20) UNIQUE NOT NULL, -- e.g. 'LEKKI-01'
    name VARCHAR(100) NOT NULL,        -- e.g. 'Lekki Road Station'
    address TEXT,
    state VARCHAR(50) DEFAULT 'Lagos',
    manager_name VARCHAR(100),
    phone VARCHAR(30),
    is_active BOOLEAN DEFAULT true,
    has_interlocked_tanks BOOLEAN DEFAULT false, -- True for the 2 stations with interlocked tanks (§3.1)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 2. FUEL PRODUCTS & PRICES (§1, §2.8–§2.10)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fuel_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(10) UNIQUE NOT NULL, -- 'PMS' (Petrol), 'AGO' (Diesel)
    name VARCHAR(50) NOT NULL,
    unit VARCHAR(10) DEFAULT 'Litres',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial products
INSERT INTO public.fuel_products (code, name) VALUES 
('PMS', 'Premium Motor Spirit (Petrol)'),
('AGO', 'Automotive Gas Oil (Diesel)')
ON CONFLICT (code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.fuel_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.fuel_products(id) ON DELETE RESTRICT,
    price_per_litre NUMERIC(10, 2) NOT NULL CHECK (price_per_litre > 0),
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMPTZ, -- NULL means currently active
    authorised_by VARCHAR(100) NOT NULL, -- Authorized by Director (§2.8)
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fuel_prices_active 
ON public.fuel_prices(station_id, product_id, effective_from DESC);

-- -----------------------------------------------------------------------------
-- 3. TANKS & PUMPS/NOZZLES (§3.1–§3.4)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tanks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL, -- e.g. 'T1', 'T2', 'T3'
    product_id UUID NOT NULL REFERENCES public.fuel_products(id) ON DELETE RESTRICT,
    capacity_litres NUMERIC(12, 2) NOT NULL,
    current_dip_litres NUMERIC(12, 2) DEFAULT 0.00,
    calculated_stock_litres NUMERIC(12, 2) DEFAULT 0.00,
    is_interlocked BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(station_id, code)
);

CREATE TABLE IF NOT EXISTS public.pumps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL, -- e.g. 'PUMP-1', 'PUMP-2'
    name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(station_id, code)
);

CREATE TABLE IF NOT EXISTS public.nozzles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pump_id UUID NOT NULL REFERENCES public.pumps(id) ON DELETE CASCADE,
    nozzle_number INT NOT NULL, -- 1, 2, 3, 4
    product_id UUID NOT NULL REFERENCES public.fuel_products(id) ON DELETE RESTRICT,
    supplying_tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE RESTRICT,
    latest_meter_reading NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(pump_id, nozzle_number)
);

-- -----------------------------------------------------------------------------
-- 4. USER PROFILES & PIN AUTHENTICATION (§2.1–§2.4)
-- -----------------------------------------------------------------------------
CREATE TYPE public.user_role AS ENUM ('attendant', 'cashier', 'manager', 'director', 'admin');

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL, -- NULL for Director with all-branch access
    full_name VARCHAR(100) NOT NULL,
    display_name VARCHAR(50) NOT NULL, -- e.g. 'Amaka O.'
    role public.user_role NOT NULL DEFAULT 'attendant',
    pin_hash TEXT NOT NULL, -- Salted SHA256 / bcrypt hash for shared tablet login
    phone VARCHAR(30),
    address TEXT, -- Residential home address
    surety_name VARCHAR(100), -- Guarantor / Shortee full name (§2.2)
    surety_phone VARCHAR(30), -- Guarantor / Shortee contact phone number
    surety_address TEXT, -- Guarantor / Shortee address
    base_salary NUMERIC(12, 2) DEFAULT 0.00, -- Monthly base salary authorized by Director
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 5. WORK SHIFTS (§2.6, §2.7)
-- -----------------------------------------------------------------------------
CREATE TYPE public.shift_type AS ENUM ('morning', 'afternoon_evening');
CREATE TYPE public.shift_status AS ENUM ('open', 'closing_pending', 'closed', 'verified');

CREATE TABLE IF NOT EXISTS public.shifts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    shift_type public.shift_type NOT NULL,
    status public.shift_status DEFAULT 'open',
    opened_by UUID REFERENCES public.profiles(id),
    opened_at TIMESTAMPTZ DEFAULT NOW(),
    closed_by UUID REFERENCES public.profiles(id),
    closed_at TIMESTAMPTZ,
    verified_by UUID REFERENCES public.profiles(id),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(station_id, business_date, shift_type)
);

-- -----------------------------------------------------------------------------
-- 6. SHIFT NOZZLE ASSIGNMENTS & METER READINGS (§2.5, §2.6, §2.10)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.shift_nozzle_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
    nozzle_id UUID NOT NULL REFERENCES public.nozzles(id) ON DELETE RESTRICT,
    attendant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    opening_reading NUMERIC(14, 2) NOT NULL, -- Carried forward from previous closing
    closing_reading NUMERIC(14, 2),
    price_per_litre NUMERIC(10, 2) NOT NULL,
    litres_sold NUMERIC(12, 2) GENERATED ALWAYS AS (
        CASE WHEN closing_reading IS NOT NULL AND closing_reading >= opening_reading 
             THEN closing_reading - opening_reading 
             ELSE 0.00 END
    ) STORED,
    expected_sales_value NUMERIC(14, 2) GENERATED ALWAYS AS (
        CASE WHEN closing_reading IS NOT NULL AND closing_reading >= opening_reading 
             THEN (closing_reading - opening_reading) * price_per_litre 
             ELSE 0.00 END
    ) STORED,
    is_opening_confirmed BOOLEAN DEFAULT false,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shift_id, nozzle_id)
);

-- -----------------------------------------------------------------------------
-- 7. REMITTANCE & DISCREPANCY RECONCILIATION (§4.1–§4.7)
-- -----------------------------------------------------------------------------
CREATE TYPE public.remittance_status AS ENUM ('draft', 'submitted', 'verified', 'flagged_unresolved');

CREATE TABLE IF NOT EXISTS public.remittances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE CASCADE,
    attendant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    expected_sales_value NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    cash_declared NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    pos_card_declared NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    pos_transfer_declared NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    bank_transfer_declared NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    credit_sales_declared NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_declared NUMERIC(14, 2) GENERATED ALWAYS AS (
        cash_declared + pos_card_declared + pos_transfer_declared + bank_transfer_declared + credit_sales_declared
    ) STORED,
    variance NUMERIC(14, 2) GENERATED ALWAYS AS (
        (cash_declared + pos_card_declared + pos_transfer_declared + bank_transfer_declared + credit_sales_declared) - expected_sales_value
    ) STORED,
    status public.remittance_status DEFAULT 'submitted',
    verified_by UUID REFERENCES public.profiles(id),
    verified_at TIMESTAMPTZ,
    cashier_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shift_id, attendant_id)
);

CREATE TABLE IF NOT EXISTS public.remittance_evidence (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    remittance_id UUID NOT NULL REFERENCES public.remittances(id) ON DELETE CASCADE,
    payment_channel VARCHAR(30) NOT NULL, -- 'pos_card', 'pos_transfer', 'bank_transfer'
    storage_path TEXT NOT NULL,
    file_name TEXT,
    amount NUMERIC(14, 2),
    reference_number VARCHAR(100),
    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 7b. INTRA-SHIFT CASH DROPS & POS TRANSACTIONS (§2.6, §4.1, §4.4)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.interim_cash_drops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID,
    station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
    attendant_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    amount NUMERIC(14, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'acknowledged'
    acknowledged_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shift_pos_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID,
    station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
    attendant_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    payment_channel VARCHAR(30) NOT NULL, -- 'pos_card', 'pos_transfer', 'bank_transfer'
    amount NUMERIC(14, 2) NOT NULL,
    terminal_name VARCHAR(50),
    reference_number VARCHAR(100),
    storage_path TEXT,
    customer_vehicle VARCHAR(30),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 8. ATTENDANT SALARY SHORTAGE/EXCESS ADJUSTMENTS (§4.6, §4.7)
-- -----------------------------------------------------------------------------
CREATE TYPE public.adjustment_type AS ENUM ('shortage', 'excess');
CREATE TYPE public.adjustment_status AS ENUM ('pending_review', 'salary_deduction_approved', 'recovered', 'waived');

CREATE TABLE IF NOT EXISTS public.attendant_salary_adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attendant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    remittance_id UUID NOT NULL REFERENCES public.remittances(id) ON DELETE CASCADE,
    shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE RESTRICT,
    amount NUMERIC(14, 2) NOT NULL,
    adjustment_type public.adjustment_type NOT NULL,
    status public.adjustment_status DEFAULT 'pending_review',
    decided_by UUID REFERENCES public.profiles(id), -- Approved by Director (§4.7)
    decision_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 8b. MONTHLY ATTENDANT PAYROLL SETTLEMENTS (§4.7)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.monthly_payroll_settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attendant_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    month_year VARCHAR(30) NOT NULL,
    base_salary NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_shortages_deducted NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_excesses_credited NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    net_payable NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    carried_deficit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    shortfall_shift_count INT DEFAULT 0,
    settled_by UUID REFERENCES public.profiles(id),
    settled_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(30) DEFAULT 'settled',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 9. REGISTERED CREDIT CUSTOMERS & LEDGER (§4.8–§4.10)
-- -----------------------------------------------------------------------------
CREATE TYPE public.credit_status AS ENUM ('current', 'overdue', 'settled');

CREATE TABLE IF NOT EXISTS public.credit_customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID REFERENCES public.stations(id) ON DELETE SET NULL,
    company_name VARCHAR(120) NOT NULL,
    contact_person VARCHAR(100),
    phone VARCHAR(30),
    credit_limit NUMERIC(14, 2) DEFAULT 0.00,
    outstanding_balance NUMERIC(14, 2) DEFAULT 0.00,
    payment_terms_days INT DEFAULT 14,
    status public.credit_status DEFAULT 'current',
    authorised_by VARCHAR(100) NOT NULL, -- Authorised by Director (§4.10)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.credit_sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shift_id UUID NOT NULL REFERENCES public.shifts(id) ON DELETE RESTRICT,
    attendant_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    customer_id UUID NOT NULL REFERENCES public.credit_customers(id) ON DELETE RESTRICT,
    nozzle_id UUID NOT NULL REFERENCES public.nozzles(id) ON DELETE RESTRICT,
    litres NUMERIC(12, 2) NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    vehicle_number VARCHAR(30),
    driver_name VARCHAR(100),
    signed_requisition_url TEXT,
    verified_by_manager UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.credit_repayments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID NOT NULL REFERENCES public.credit_customers(id) ON DELETE RESTRICT,
    station_id UUID REFERENCES public.stations(id),
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    payment_method VARCHAR(30) NOT NULL, -- 'cash', 'bank_transfer', 'cheque'
    bank_reference VARCHAR(100),
    proof_url TEXT,
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    confirmed_by_director BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 10. DAILY PHYSICAL CASH DENOMINATION COUNT (§5.3–§5.5)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.daily_cash_counts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    cashier_id UUID NOT NULL REFERENCES public.profiles(id),
    
    -- Cash flow breakdown formula: Opening + Receipts - Expenses - HandedOver
    opening_cash NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    cash_receipts NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    cash_expenses NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    handed_over_for_deposit NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    expected_closing_cash NUMERIC(14, 2) NOT NULL,
    
    -- Denomination breakdown (Nigerian Naira)
    count_1000 INT DEFAULT 0,
    count_500  INT DEFAULT 0,
    count_200  INT DEFAULT 0,
    count_100  INT DEFAULT 0,
    count_50   INT DEFAULT 0,
    count_20   INT DEFAULT 0,
    count_10   INT DEFAULT 0,
    
    physical_total_counted NUMERIC(14, 2) NOT NULL,
    variance NUMERIC(14, 2) GENERATED ALWAYS AS (
        physical_total_counted - expected_closing_cash
    ) STORED,
    
    -- Handed over deposit tracking (§5.4, §5.5)
    deposit_status VARCHAR(30) DEFAULT 'awaiting_bank', -- 'awaiting_bank', 'confirmed_by_director'
    deposit_bank_name VARCHAR(100),
    deposit_slip_url TEXT,
    confirmed_by_director_id UUID REFERENCES public.profiles(id),
    confirmed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(station_id, business_date)
);

-- -----------------------------------------------------------------------------
-- 10b. BANK DEPOSITS & DUAL-CUSTODY AUDIT TRAIL (§4.3, §5.4, §5.5)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bank_deposits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID REFERENCES public.stations(id) ON DELETE CASCADE,
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(14, 2) NOT NULL CHECK (amount > 0),
    bank_name VARCHAR(100) NOT NULL,
    bearer_name VARCHAR(100) NOT NULL,
    teller_number VARCHAR(100),
    slip_url TEXT,
    notes TEXT,
    status VARCHAR(30) DEFAULT 'awaiting_bank', -- 'awaiting_bank', 'confirmed', 'discrepancy'
    confirmed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    confirmed_at TIMESTAMPTZ,
    director_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 11. BRANCH EXPENSES (§5.1, §5.2)
-- -----------------------------------------------------------------------------
CREATE TYPE public.payment_source AS ENUM ('sales_cash', 'bank_transfer');

CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    business_date DATE NOT NULL DEFAULT CURRENT_DATE,
    category VARCHAR(50) NOT NULL, -- 'generator_diesel', 'cleaning', 'utilities', 'stationery'
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    payment_source public.payment_source NOT NULL DEFAULT 'sales_cash',
    description TEXT NOT NULL,
    receipt_url TEXT,
    status VARCHAR(30) DEFAULT 'approved', -- 'approved', 'pending_approval', 'rejected'
    recorded_by_role VARCHAR(20) DEFAULT 'manager', -- 'cashier', 'manager', 'director'
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    approved_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 12. TANK DIPS & FUEL DELIVERIES (§3.3, §3.7–§3.9)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tank_dips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    dip_litres NUMERIC(12, 2) NOT NULL,
    calculated_litres NUMERIC(12, 2) NOT NULL,
    variance NUMERIC(12, 2) GENERATED ALWAYS AS (dip_litres - calculated_litres) STORED,
    recorded_by UUID NOT NULL REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.fuel_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    receiving_tank_id UUID NOT NULL REFERENCES public.tanks(id) ON DELETE RESTRICT,
    supplier_name VARCHAR(100) NOT NULL,
    waybill_number VARCHAR(50),
    stated_litres NUMERIC(12, 2) NOT NULL,
    dip_before_litres NUMERIC(12, 2) NOT NULL,
    dip_after_litres NUMERIC(12, 2) NOT NULL,
    received_litres NUMERIC(12, 2) NOT NULL,
    discrepancy_litres NUMERIC(12, 2) GENERATED ALWAYS AS (received_litres - stated_litres) STORED,
    purchase_price_per_litre NUMERIC(10, 2),
    transport_cost NUMERIC(12, 2) DEFAULT 0.00,
    waybill_image_url TEXT,
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    delivery_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 12B. INTERLOCKED TANK CHANGEOVERS (§3.1, §7)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tank_changeovers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    product_code VARCHAR(10) NOT NULL,
    from_tank_code VARCHAR(20) NOT NULL,
    to_tank_code VARCHAR(20) NOT NULL,
    switch_readings JSONB NOT NULL DEFAULT '{}'::jsonb,
    from_tank_dip_litres NUMERIC(12, 2),
    to_tank_dip_litres NUMERIC(12, 2),
    notes TEXT,
    switched_by UUID REFERENCES public.profiles(id),
    switched_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- 13. PIN AUTHENTICATION RPC FUNCTION (§2.3)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.attendant_pin_login(
    p_station_id UUID,
    p_profile_id UUID,
    p_pin TEXT
) RETURNS JSONB AS $$
DECLARE
    v_profile public.profiles%ROWTYPE;
BEGIN
    SELECT * INTO v_profile 
    FROM public.profiles 
    WHERE id = p_profile_id 
      AND (station_id = p_station_id OR station_id IS NULL)
      AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Attendant profile not found or inactive');
    END IF;

    -- Verify PIN (supports raw test PIN matching or crypt/sha256)
    IF v_profile.pin_hash = crypt(p_pin, v_profile.pin_hash) OR v_profile.pin_hash = encode(digest(p_pin, 'sha256'), 'hex') OR v_profile.pin_hash = p_pin THEN
        RETURN jsonb_build_object(
            'success', true,
            'user', jsonb_build_object(
                'id', v_profile.id,
                'full_name', v_profile.full_name,
                'display_name', v_profile.display_name,
                'role', v_profile.role,
                'station_id', v_profile.station_id
            )
        );
    ELSE
        RETURN jsonb_build_object('success', false, 'message', 'Incorrect 6-digit PIN');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 14. SEED SAMPLE TEST DATA (Lekki Road Station + Attendants)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_station_id UUID;
    v_pms_id UUID;
    v_ago_id UUID;
    v_tank_t1 UUID;
    v_tank_t2 UUID;
    v_tank_t3 UUID;
    v_pump_1 UUID;
    v_pump_2 UUID;
    v_attendant_amaka UUID;
    v_cashier_chidi UUID;
    v_manager_bello UUID;
    v_director UUID;
BEGIN
    -- 1. Create Lekki Road Station
    INSERT INTO public.stations (code, name, address, manager_name, phone)
    VALUES ('LEKKI-01', 'Lekki Road Station', 'Lekki Expressway, Lagos', 'Bello S.', '08012345678')
    RETURNING id INTO v_station_id;

    -- Retrieve products
    SELECT id INTO v_pms_id FROM public.fuel_products WHERE code = 'PMS';
    SELECT id INTO v_ago_id FROM public.fuel_products WHERE code = 'AGO';

    -- 2. Fuel Prices
    INSERT INTO public.fuel_prices (station_id, product_id, price_per_litre, authorised_by)
    VALUES 
    (v_station_id, v_pms_id, 1050.00, 'Director'),
    (v_station_id, v_ago_id, 1320.00, 'Director');

    -- 3. Tanks
    INSERT INTO public.tanks (station_id, code, product_id, capacity_litres, current_dip_litres, calculated_stock_litres)
    VALUES 
    (v_station_id, 'T1', v_pms_id, 45000, 32100, 32100) RETURNING id INTO v_tank_t1;

    INSERT INTO public.tanks (station_id, code, product_id, capacity_litres, current_dip_litres, calculated_stock_litres)
    VALUES 
    (v_station_id, 'T2', v_pms_id, 45000, 28400, 28520) RETURNING id INTO v_tank_t2;

    INSERT INTO public.tanks (station_id, code, product_id, capacity_litres, current_dip_litres, calculated_stock_litres)
    VALUES 
    (v_station_id, 'T3', v_ago_id, 33000, 14200, 14200) RETURNING id INTO v_tank_t3;

    -- 4. Pumps & Nozzles
    INSERT INTO public.pumps (station_id, code, name) VALUES (v_station_id, 'PUMP-1', 'Island 1 - Dual') RETURNING id INTO v_pump_1;
    INSERT INTO public.pumps (station_id, code, name) VALUES (v_station_id, 'PUMP-2', 'Island 2 - Dual') RETURNING id INTO v_pump_2;

    INSERT INTO public.nozzles (pump_id, nozzle_number, product_id, supplying_tank_id, latest_meter_reading)
    VALUES 
    (v_pump_1, 1, v_pms_id, v_tank_t1, 412380.50),
    (v_pump_1, 2, v_pms_id, v_tank_t1, 388102.00),
    (v_pump_2, 3, v_ago_id, v_tank_t3, 201775.50);

    -- 5. Profiles (PIN: 1234 for testing)
    INSERT INTO public.profiles (station_id, full_name, display_name, role, pin_hash, phone)
    VALUES 
    (v_station_id, 'Amaka Okonkwo', 'Amaka O.', 'attendant', '1234', '08011112222') RETURNING id INTO v_attendant_amaka;

    INSERT INTO public.profiles (station_id, full_name, display_name, role, pin_hash, phone)
    VALUES 
    (v_station_id, 'Bello Salami', 'Bello S.', 'manager', '1234', '08033334444') RETURNING id INTO v_manager_bello;

    INSERT INTO public.profiles (station_id, full_name, display_name, role, pin_hash, phone)
    VALUES 
    (v_station_id, 'Chidi Eze', 'Chidi E.', 'cashier', '1234', '08055556666') RETURNING id INTO v_cashier_chidi;

    INSERT INTO public.profiles (station_id, full_name, display_name, role, pin_hash, phone)
    VALUES 
    (NULL, 'Dickson Hardy (Managing Director)', 'Director', 'director', '1234', '08099990000') RETURNING id INTO v_director;

    -- 6. Credit Customers
    INSERT INTO public.credit_customers (station_id, company_name, contact_person, credit_limit, outstanding_balance, payment_terms_days, status, authorised_by)
    VALUES 
    (v_station_id, 'Sample Haulage Ltd', 'Capt. Danladi', 5000000.00, 1240000.00, 30, 'current', 'Director'),
    (v_station_id, 'Sample Farms', 'Mallam Musa', 1000000.00, 310000.00, 14, 'overdue', 'Director'),
    (v_station_id, 'Sample Clinic', 'Dr. Adeyemi', 500000.00, 0.00, 14, 'settled', 'Director');
END $$;
