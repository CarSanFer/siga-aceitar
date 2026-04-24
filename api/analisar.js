// ============================================================
// SIGA — API de análise IA
// POST /api/analisar
// Body: { type: 'concurso' | 'inspect', record: {...} }
// ============================================================

export const config = { runtime: 'nodejs' };

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const MODEL = 'claude-sonnet-4-6';

// ---------- PROMPTS POR TIPO ----------
function buildPrompt(type, record) {
  if (type === 'concurso') {
    return `És um analista sénior de uma empresa portuguesa de consultoria em fiscalização, coordenação de segurança e gestão de projetos de construção (Aceitar Sucessos, Lda).

Analisa este concurso público e dá uma avaliação estruturada em 4 blocos curtos:

1. **Avaliação sumária** (2-3 linhas): vale a pena concorrer? enquadramento estratégico?
2. **Pontos fortes**: aspetos favoráveis (valor, prazo, adequação ao perfil da empresa)
3. **Riscos e alertas**: prazos apertados, plataforma pouco comum, valor base baixo, localização distante, etc.
4. **Recomendação**: avançar / avançar com reservas / não avançar, e próximos passos concretos

Sê direto, objetivo e orientado para a decisão. Usa bullet points curtos. Valores em euros com separador de milhares.

### Dados do concurso:
- Entidade: ${record.entidade || '(n/d)'}
- Nome: ${record.nome || '(n/d)'}
- Localização: ${record.localizacao || '(n/d)'}
- Plataforma: ${record.plataforma || '(n/d)'}
- Tipo: ${record.tipo || '(n/d)'}
- Valor Base: ${record.valor_base ? record.valor_base + ' €' : '(n/d)'}
- Duração: ${record.duracao || '(n/d)'}
- Entrega: ${record.entrega || '(n/d)'}
- Status atual: ${record.status || '(n/d)'}
- Notas internas: ${record.notas || '(nenhuma)'}`;
  }

  if (type === 'inspect') {
    return `És um analista sénior da Aceitar Inspect, serviço de inspeção técnica a imóveis (pré-compra, pré-venda, patologias, due diligence urbanística) da Aceitar Sucessos, Lda, em Portugal.

Analisa esta proposta a cliente e dá uma avaliação estruturada em 4 blocos curtos:

1. **Perfil do cliente**: tipo de cliente aparente, canal, maturidade do lead
2. **Adequação do serviço**: o tipo de serviço proposto faz sentido para o perfil/localização?
3. **Alertas comerciais**: valor alinhado com mercado? sinais de churn? dúvidas no brief?
4. **Próximos passos**: 2-3 ações concretas (follow-up, upsell, validação, etc.)

Sê direto, objetivo, prático. Usa bullet points curtos. Valores em euros com separador de milhares.

### Dados da proposta:
- Cliente: ${record.cliente || '(n/d)'}
- Email: ${record.email || '(n/d)'}
- Telefone: ${record.telefone || '(n/d)'}
- Localização: ${record.localizacao || '(n/d)'}
- Morada: ${record.morada_completa || '(n/d)'}
- Data da Proposta: ${record.data_proposta || '(n/d)'}
- Tipo de Serviço: ${record.tipo_servico || '(n/d)'}
- Valor s/ IVA: ${record.valor_sem_iva ? record.valor_sem_iva + ' €' : '(n/d)'}
- Estado: ${record.estado || '(n/d)'}
- Canal de Origem: ${record.canal_origem || '(n/d)'}
- Notas internas: ${record.notas || '(nenhuma)'}`;
  }

  if (type === 'inspect_global') {
    return `És um analista sénior da Aceitar Inspect, serviço de inspeção técnica a imóveis da Aceitar Sucessos, Lda, em Portugal (pré-compra, pré-venda, receções, patologias, due diligence urbanística).

Analisa estes dados agregados do portfólio de propostas e produz insights accionáveis em 4 blocos curtos:

1. **Leitura do estado**: em 2-3 linhas, o que é que os números dizem sobre a saúde comercial? (taxa de conversão, ticket médio, pipeline em aberto vs adjudicado)
2. **Padrões detetados**: o que se destaca por estado, tipo de serviço e canal? Há serviços com taxa de aceite muito superior/inferior?
3. **Alertas**: propostas muito antigas ainda pendentes, canais com baixa conversão, concentração excessiva num tipo/canal, pipeline desequilibrado
4. **Ações recomendadas**: 3 ações concretas e priorizadas para melhorar conversão, ticket médio ou volume

Sê direto, prático, objetivo. Usa bullet points curtos. Valores em euros com separador de milhares. Percentagens com 1 casa decimal.

### Dados agregados do portfólio:
${JSON.stringify(record, null, 2)}`;
  }

  return 'Analisa este registo: ' + JSON.stringify(record);
}

// ---------- HANDLER ----------
export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  if (!ANTHROPIC_API_KEY) {
    return res.status(500).json({ error: 'ANTHROPIC_API_KEY não configurada' });
  }

  try {
    const { type, record } = req.body || {};
    if (!type || !record) {
      return res.status(400).json({ error: 'type e record são obrigatórios' });
    }

    const prompt = buildPrompt(type, record);

    const resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1200,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    if (!resp.ok) {
      const err = await resp.text();
      console.error('Anthropic error:', err);
      return res.status(resp.status).json({ error: 'Erro Anthropic: ' + err.slice(0, 200) });
    }

    const data = await resp.json();
    const analysis = (data.content || [])
      .filter(b => b.type === 'text')
      .map(b => b.text)
      .join('\n');

    return res.status(200).json({ analysis });
  } catch (e) {
    console.error(e);
    return res.status(500).json({ error: e.message || 'Erro interno' });
  }
}
