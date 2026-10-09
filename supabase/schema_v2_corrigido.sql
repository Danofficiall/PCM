-- Clean up & Base Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. TABELA DE PERFIS E NÍVEIS DE ACESSO
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'admin', 'operator', 'viewer')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABELA DE LOCADORES E FORNECEDORES
CREATE TABLE IF NOT EXISTS public.partners (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  partner_type TEXT NOT NULL CHECK (partner_type IN ('lessor', 'supplier', 'both')),
  document TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. REGISTROS OPERACIONAIS PCM
CREATE TABLE IF NOT EXISTS public.pcm_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  module_id TEXT NOT NULL,
  vehicle_plate TEXT NOT NULL,
  lessor_id UUID REFERENCES public.partners(id),
  supplier_id UUID REFERENCES public.partners(id),
  payload JSONB NOT NULL,
  notes TEXT, -- Único campo opcional
  created_by UUID NOT NULL REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. EVENTOS DE AUDITORIA
CREATE TABLE IF NOT EXISTS public.audit_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id),
  action TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HABILITAÇÃO DO ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pcm_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

-- FUNÇÃO AUXILIAR SECURITY DEFINER (EVITA RECURSÃO)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid() AND status = 'active';
$$;

-- POLÍTICAS RLS SECURE (PROFILES)
DROP POLICY IF EXISTS "Leitura de Perfis" ON public.profiles;
DROP POLICY IF EXISTS "Leitura de Perfis Segura" ON public.profiles;
CREATE POLICY "Leitura de Perfis Segura" ON public.profiles 
  FOR SELECT TO authenticated 
  USING (id = auth.uid() OR public.get_user_role() IN ('super_admin', 'admin'));

CREATE POLICY "Gestão de Perfis por Admin/Dono" ON public.profiles 
  FOR ALL TO authenticated 
  USING (public.get_user_role() IN ('super_admin', 'admin'));

-- POLÍTICAS RLS (PARTNERS - LOCADORES/FORNECEDORES)
CREATE POLICY "Leitura de Parceiros" ON public.partners 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Escrita de Parceiros por Admins" ON public.partners 
  FOR ALL TO authenticated 
  USING (public.get_user_role() IN ('super_admin', 'admin'));

-- POLÍTICAS RLS (PCM RECORDS)
CREATE POLICY "Leitura de Registros" ON public.pcm_records 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Inserção por Operadores e Admins" ON public.pcm_records 
  FOR INSERT TO authenticated 
  WITH CHECK (public.get_user_role() IN ('super_admin', 'admin', 'operator'));

-- POLÍTICAS RLS SECURE (AUDIT EVENTS)
DROP POLICY IF EXISTS "Leitura de Audit por Admins" ON public.audit_events;
CREATE POLICY "Leitura de Audit por Admins" ON public.audit_events 
  FOR SELECT TO authenticated 
  USING (public.get_user_role() IN ('super_admin', 'admin'));

-- TRIGGER DE IMUTABILIDADE PARA PCM RECORDS
CREATE OR REPLACE FUNCTION public.prevent_immutable_pcm_fields_change()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'Não é permitido alterar o criador original do registro.';
  END IF;
  IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Não é permitido alterar a data de criação.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_protect_pcm_records
BEFORE UPDATE ON public.pcm_records
FOR EACH ROW EXECUTE FUNCTION public.prevent_immutable_pcm_fields_change();

-- TRIGGER DE AUDITORIA AUTOMÁTICA EM PCM RECORDS
CREATE OR REPLACE FUNCTION public.audit_pcm_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.audit_events (user_id, action, details)
  VALUES (
    auth.uid(),
    TG_OP,
    jsonb_build_object('table', TG_TABLE_NAME, 'record_id', COALESCE(NEW.id, OLD.id))
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_pcm
AFTER INSERT OR UPDATE OR DELETE ON public.pcm_records
FOR EACH ROW EXECUTE FUNCTION public.audit_pcm_changes();

-- PRIVILÉGIOS DML SEGUROS
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.partners TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pcm_records TO authenticated;

-- AUDIT_EVENTS É EXCLUSIVO DE LEITURA PARA USUÁRIOS; APENAS TRIGGERS GRAVAM
REVOKE INSERT, UPDATE, DELETE ON public.audit_events FROM authenticated;
GRANT SELECT ON public.audit_events TO authenticated;
