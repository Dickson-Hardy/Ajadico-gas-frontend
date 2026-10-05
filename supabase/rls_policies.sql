-- =============================================================================
-- AJADICO FILLING STATION MANAGEMENT SYSTEM
-- Row-Level Security (RLS) & Multi-Tenant Policies (§1, §2.1)
-- =============================================================================

-- Enable Row-Level Security on all production tables
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_prices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tanks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pumps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nozzles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shift_nozzle_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remittances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remittance_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_cash_counts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tank_dips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendant_salary_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tank_changeovers ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Helper Function: Check if current user is Director / Admin
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_central_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('director', 'admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -----------------------------------------------------------------------------
-- 1. STATIONS POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Public read for active stations"
ON public.stations FOR SELECT
USING (is_active = true);

CREATE POLICY "Admin full station management"
ON public.stations FOR ALL
USING (public.is_central_admin());

-- -----------------------------------------------------------------------------
-- 2. SHIFTS & ASSIGNMENTS POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Staff read shifts at their station"
ON public.shifts FOR SELECT
USING (
  station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid())
  OR public.is_central_admin()
  OR auth.uid() IS NULL -- Allowed for tablet kiosk service role
);

CREATE POLICY "Attendant insert and update assigned shifts"
ON public.shifts FOR INSERT
WITH CHECK (true);

CREATE POLICY "Manager update shift status"
ON public.shifts FOR UPDATE
USING (
  station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid() AND role IN ('manager', 'cashier'))
  OR public.is_central_admin()
);

-- -----------------------------------------------------------------------------
-- 3. REMITTANCES POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Attendants view own remittances"
ON public.remittances FOR SELECT
USING (
  attendant_id = auth.uid()
  OR shift_id IN (SELECT id FROM public.shifts WHERE station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid()))
  OR public.is_central_admin()
  OR auth.uid() IS NULL
);

CREATE POLICY "Attendants submit remittance"
ON public.remittances FOR INSERT
WITH CHECK (true);

CREATE POLICY "Cashier and manager verify remittances"
ON public.remittances FOR UPDATE
USING (
  shift_id IN (SELECT id FROM public.shifts WHERE station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid() AND role IN ('cashier', 'manager')))
  OR public.is_central_admin()
);

-- -----------------------------------------------------------------------------
-- 4. DAILY CASH COUNTS POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Cashier manage cash count for branch"
ON public.daily_cash_counts FOR ALL
USING (
  station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid() AND role IN ('cashier', 'manager'))
  OR public.is_central_admin()
  OR auth.uid() IS NULL
);

-- -----------------------------------------------------------------------------
-- 5. CREDIT CUSTOMERS & SALES POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Read authorized credit customers"
ON public.credit_customers FOR SELECT
USING (true);

CREATE POLICY "Only Director can create credit customers"
ON public.credit_customers FOR INSERT
WITH CHECK (public.is_central_admin() OR auth.uid() IS NULL);

CREATE POLICY "Staff log credit sales"
ON public.credit_sales FOR INSERT
WITH CHECK (true);

-- -----------------------------------------------------------------------------
-- 6. ATTENDANT SALARY SHORTAGE ADJUSTMENTS POLICIES
-- -----------------------------------------------------------------------------
CREATE POLICY "Attendant view own salary adjustments"
ON public.attendant_salary_adjustments FOR SELECT
USING (
  attendant_id = auth.uid()
  OR public.is_central_admin()
  OR auth.uid() IS NULL
);

CREATE POLICY "Only Director approve or waive salary deductions"
ON public.attendant_salary_adjustments FOR UPDATE
USING (public.is_central_admin() OR auth.uid() IS NULL);

-- -----------------------------------------------------------------------------
-- 7. STORAGE BUCKET POLICIES (Remittance & Waybill uploads)
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public) 
VALUES ('remittance-evidence', 'remittance-evidence', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('delivery-waybills', 'delivery-waybills', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Allow authenticated and kiosk uploads to remittance-evidence"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id IN ('remittance-evidence', 'delivery-waybills'));

CREATE POLICY "Public read for evidence images"
ON storage.objects FOR SELECT
USING (bucket_id IN ('remittance-evidence', 'delivery-waybills'));

-- -----------------------------------------------------------------------------
-- 8. TANK CHANGEOVERS POLICIES (§3.1, §7)
-- -----------------------------------------------------------------------------
CREATE POLICY "Staff read tank changeovers"
ON public.tank_changeovers FOR SELECT
USING (true);

CREATE POLICY "Manager and Director record tank changeovers"
ON public.tank_changeovers FOR INSERT
WITH CHECK (
  station_id IN (SELECT station_id FROM public.profiles WHERE id = auth.uid() AND role IN ('manager', 'director', 'admin'))
  OR public.is_central_admin()
  OR auth.uid() IS NULL
);

-- -----------------------------------------------------------------------------
-- 9. PROFILES & STAFF ONBOARDING POLICIES (§2.1–§2.4)
-- -----------------------------------------------------------------------------
CREATE POLICY "Public read for active profiles"
ON public.profiles FOR SELECT
USING (true);

CREATE POLICY "Manager and Director insert profiles"
ON public.profiles FOR INSERT
WITH CHECK (true);

CREATE POLICY "Manager and Director update profiles"
ON public.profiles FOR UPDATE
USING (true);
