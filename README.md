# SIGA — Sistema Integrado de Gestão Aceitar

Aplicação interna da Aceitar Sucessos, Lda. para gestão centralizada de concursos públicos, propostas Aceitar Inspect, afetações, frota, equipamentos e comunicações — com análise IA por registo.

## Stack

| Camada | Tecnologia |
|---|---|
| Frontend | Single-file HTML + vanilla JS |
| Bibliotecas CDN | Supabase JS, SheetJS (xlsx), Chart.js |
| Backend | Supabase (Auth + PostgreSQL + RLS) |
| IA | Anthropic API (Claude Sonnet 4.6) via Vercel serverless |
| Hosting | Vercel |
| DNS | Amen (CNAME `siga` → Vercel) |

## Módulos (v1.0)

| Módulo | Estado | Funcionalidades |
|---|---|---|
| **Dashboard** | ✅ | KPIs globais, entregas próximas, gráficos de status |
| **Concursos** | ✅ | CRUD + listagem ordenável + filtros + import/export XLSX + análise IA |
| **Aceitar Inspect** | ✅ | CRUD + listagem ordenável + filtros + import/export XLSX + análise IA |
| **Afetações** | 🔧 Placeholder | Estrutura BD pronta; a integrar MCA |
| **Frota** | 🔧 Placeholder | Estrutura BD pronta; campos a detalhar |
| **Equipamentos** | 🔧 Placeholder | Estrutura BD pronta; licenças e custos |
| **Comunicações** | 🔧 Placeholder | Estrutura BD pronta; números e custos |

## Papéis de utilizador

| Papel | Permissões |
|---|---|
| `superadmin` | CRUD completo em todos os módulos, incluindo gestão de utilizadores |
| `leitor` | Apenas leitura (listagens, detalhes, export XLSX). Não pode criar/editar/eliminar |

Os utilizadores são geridos na tabela `siga_users`. Podem ser sincronizados a partir do SID conforme parametrização existente.

## Setup

### 1. Criar projeto Supabase

1. Ir a [supabase.com](https://supabase.com) → **New project**
2. Region: `eu-west-3 (Paris)` ou `eu-central-1 (Frankfurt)` (recomendado)
3. Password forte para a BD
4. Aguardar provisionamento

### 2. Aplicar schema

1. No Supabase, ir a **SQL Editor**
2. Abrir `schema.sql` e colar
3. Editar a linha do superadmin inicial se necessário (`carlos@aceitar.pt`)
4. Executar (Run)

### 3. Criar utilizadores

Para cada utilizador:

1. **Supabase → Authentication → Users → Add user → Create new user**
2. Introduzir email + password temporária
3. Depois, no SQL Editor:
   ```sql
   insert into siga_users (email, nome, papel)
   values ('utilizador@aceitar.pt', 'Nome Completo', 'leitor')
   on conflict (email) do update set
     nome = excluded.nome,
     papel = excluded.papel,
     ativo = true;
   ```

### 4. Configurar o frontend

Editar `index.html` e substituir:

```js
const CONFIG = {
  SUPABASE_URL: 'REPLACE_WITH_SUPABASE_URL',
  SUPABASE_ANON_KEY: 'REPLACE_WITH_SUPABASE_ANON_KEY',
  ...
};
```

Pelos valores em **Supabase → Project Settings → API**:
- `SUPABASE_URL` → Project URL
- `SUPABASE_ANON_KEY` → `anon` / `public` key

### 5. GitHub

```bash
cd siga
git init
git add .
git commit -m "Initial commit: SIGA v1.0"
git branch -M main
git remote add origin https://github.com/CarSanFer/siga.git
git push -u origin main
```

### 6. Vercel

1. Ir a [vercel.com](https://vercel.com) → **New Project** → Import `CarSanFer/siga`
2. Framework preset: **Other**
3. Build command: (vazio)
4. Output directory: (vazio — usa a raiz)
5. **Environment Variables**:
   - `ANTHROPIC_API_KEY` = (a tua chave da Anthropic, a partir de console.anthropic.com)
6. Deploy

### 7. Domínio personalizado

1. Vercel → Project → **Settings → Domains** → Add `siga.aceitar.pt`
2. No Amen (DNS de aceitar.pt), criar CNAME:
   ```
   siga  CNAME  cname.vercel-dns.com.
   ```
3. Aguardar propagação (alguns minutos)
4. Vercel emite certificado SSL automaticamente

## Funcionalidades

### Importação XLSX

Cada módulo aceita import XLSX. Os cabeçalhos das colunas devem corresponder aos nomes exportados (faz primeiro um export de exemplo para veres o formato esperado).

**Concursos** — colunas: Entidade, Nome, Localização, Plataforma, Tipo, Valor Base (€), Duração, Entrega, Status, Notas

**Aceitar Inspect** — colunas: Cliente, Email, Telefone, Localização, Morada Completa, Data da Proposta, Tipo de Serviço, Valor s/ IVA (€), Estado, Canal de Origem, Notas

### Análise IA

- Acionada por registo no detalhe (Concurso / Proposta)
- Usa Claude Sonnet 4.6 via `/api/analisar`
- Resultado guardado em `analise_ia` e `analise_ia_data` na BD
- Regenerável; cada regeneração substitui a anterior

### Permissões

- **Leitores** veem tudo (exceto gestão de utilizadores) e conseguem exportar
- **Superadmin** tem acesso total, incluindo criar/editar/eliminar e gerar análises IA

## Estrutura de ficheiros

```
siga/
├── index.html          # Aplicação completa (UI + JS)
├── schema.sql          # Schema Supabase (tabelas + RLS)
├── api/
│   └── analisar.js     # Serverless function Anthropic API
├── vercel.json         # Config Vercel
├── package.json
└── README.md
```

## Roadmap v1.1 → v2.0

- [ ] **Afetações**: integração do MCA (Mapa de Cargas de Afetação)
- [ ] **Frota**: definição de campos finais (manutenções, seguros, inspeções)
- [ ] **Equipamentos**: ciclo de licenças com alertas de renovação
- [ ] **Comunicações**: ligação a tarifários e análise de custos mensais
- [ ] **Sincronização com SID**: import automático de utilizadores
- [ ] **Análise IA global**: dashboards com insights agregados
- [ ] **Notificações**: alertas email para entregas próximas de concursos

## Padrões visuais (herdados de SID/SIGO)

- Navbar: `#1a3a5c` com borda inferior dourada `#c9a24a`
- Fundo: bege claro `#f7f2e8`
- Cards: branco com sombra suave
- Fonte: "Segoe UI", Tahoma, system-ui
- Botões: Primary navy, Gold para ações principais, Ghost para secundárias

## Contacto técnico

Carlos Sanfilippo Fernandes
Aceitar Sucessos, Lda.
