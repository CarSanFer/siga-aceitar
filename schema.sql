-- ============================================================
-- SIGA — Sistema Integrado de Gestão Aceitar
-- Schema Supabase
-- ============================================================

-- ============================================================
-- 1. UTILIZADORES E PAPÉIS
-- ============================================================
create table if not exists siga_users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  nome text,
  papel text not null default 'leitor' check (papel in ('superadmin', 'leitor')),
  ativo boolean default true,
  sincronizado_sid boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Superadmin inicial (substituir email se necessário)
insert into siga_users (email, nome, papel)
values ('carlos@aceitar.pt', 'Carlos Sanfilippo Fernandes', 'superadmin')
on conflict (email) do nothing;

-- ============================================================
-- 2. CONCURSOS
-- ============================================================
create table if not exists concursos (
  id uuid primary key default gen_random_uuid(),
  entidade text,
  nome text,
  localizacao text,
  plataforma text,
  tipo text,
  valor_base numeric,
  duracao text,
  entrega date,
  status text default 'Pendente' check (status in (
    'Pendente', 'Em preparação', 'Submetido', 'Adjudicado',
    'Não adjudicado', 'Cancelado'
  )),
  notas text,
  analise_ia text,
  analise_ia_data timestamptz,
  criado_por uuid references siga_users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_concursos_status on concursos(status);
create index if not exists idx_concursos_entrega on concursos(entrega);

-- ============================================================
-- 3. ACEITAR INSPECT — PROPOSTAS
-- ============================================================
create table if not exists inspect_propostas (
  id uuid primary key default gen_random_uuid(),
  cliente text not null,
  email text,
  telefone text,
  localizacao text,
  data_proposta date not null default current_date,
  morada_completa text,
  tipo_servico text,
  valor_sem_iva numeric,
  estado text default 'Pendente' check (estado in (
    'Pendente', 'Enviada', 'Aceite', 'Rejeitada', 'Em execução', 'Concluída', 'Cancelada'
  )),
  canal_origem text,
  notas text,
  analise_ia text,
  analise_ia_data timestamptz,
  criado_por uuid references siga_users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_inspect_estado on inspect_propostas(estado);
create index if not exists idx_inspect_data on inspect_propostas(data_proposta);

-- ============================================================
-- 4. AFETAÇÕES (placeholder — a detalhar com base no MCA)
-- ============================================================
create table if not exists afetacoes (
  id uuid primary key default gen_random_uuid(),
  utilizador text,
  obra_sigla text,
  percentagem numeric,
  periodo_inicio date,
  periodo_fim date,
  dados jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 5. FROTA (placeholder)
-- ============================================================
create table if not exists frota (
  id uuid primary key default gen_random_uuid(),
  matricula text,
  marca text,
  modelo text,
  tipo text,
  ano int,
  km numeric,
  utilizador text,
  data_aquisicao date,
  custo_aquisicao numeric,
  dados jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 6. EQUIPAMENTOS (placeholder — licenças e custos)
-- ============================================================
create table if not exists equipamentos (
  id uuid primary key default gen_random_uuid(),
  designacao text,
  tipo text,
  utilizador text,
  licenca text,
  data_inicio date,
  data_fim date,
  custo_mensal numeric,
  custo_anual numeric,
  dados jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 7. COMUNICAÇÕES (placeholder — números e custos)
-- ============================================================
create table if not exists comunicacoes (
  id uuid primary key default gen_random_uuid(),
  numero text,
  tipo text,
  utilizador text,
  operador text,
  tarifario text,
  custo_mensal numeric,
  data_inicio date,
  data_fim date,
  dados jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================
-- 8. ROW LEVEL SECURITY
-- ============================================================

alter table siga_users enable row level security;
alter table concursos enable row level security;
alter table inspect_propostas enable row level security;
alter table afetacoes enable row level security;
alter table frota enable row level security;
alter table equipamentos enable row level security;
alter table comunicacoes enable row level security;

-- Função helper: verifica se o utilizador autenticado é superadmin
create or replace function is_superadmin() returns boolean as $$
  select exists (
    select 1 from siga_users
    where email = auth.jwt() ->> 'email'
      and papel = 'superadmin'
      and ativo = true
  );
$$ language sql stable security definer;

-- Função helper: verifica se o utilizador autenticado está ativo
create or replace function is_active_user() returns boolean as $$
  select exists (
    select 1 from siga_users
    where email = auth.jwt() ->> 'email'
      and ativo = true
  );
$$ language sql stable security definer;

-- ============================================================
-- 9. POLÍTICAS RLS
-- ============================================================

-- siga_users: utilizadores ativos leem; só superadmin escreve
drop policy if exists "users_select" on siga_users;
create policy "users_select" on siga_users for select using (is_active_user());

drop policy if exists "users_admin_all" on siga_users;
create policy "users_admin_all" on siga_users for all using (is_superadmin());

-- Aplica políticas padrão às tabelas de dados
-- (leitura para ativos, escrita só superadmin)
do $$
declare
  tbl text;
begin
  for tbl in
    select unnest(array[
      'concursos', 'inspect_propostas', 'afetacoes',
      'frota', 'equipamentos', 'comunicacoes'
    ])
  loop
    execute format('drop policy if exists "%s_select" on %s', tbl, tbl);
    execute format('create policy "%s_select" on %s for select using (is_active_user())', tbl, tbl);

    execute format('drop policy if exists "%s_admin_all" on %s', tbl, tbl);
    execute format('create policy "%s_admin_all" on %s for all using (is_superadmin())', tbl, tbl);
  end loop;
end $$;

-- ============================================================
-- 10. TRIGGERS updated_at
-- ============================================================
create or replace function set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

do $$
declare
  tbl text;
begin
  for tbl in
    select unnest(array[
      'siga_users', 'concursos', 'inspect_propostas',
      'afetacoes', 'frota', 'equipamentos', 'comunicacoes'
    ])
  loop
    execute format('drop trigger if exists trg_%s_updated on %s', tbl, tbl);
    execute format('create trigger trg_%s_updated before update on %s
                    for each row execute function set_updated_at()', tbl, tbl);
  end loop;
end $$;
