export default {
  async fetch(request, env) {
    const cors = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405, cors);

    try {
      const contentType = request.headers.get('content-type') || '';
      let body;

      if (contentType.includes('multipart/form-data')) {
        const form = await request.formData();
        const image = form.get('image');
        if (!(image instanceof File)) return json({ error: 'Imagem não enviada.' }, 400, cors);
        const bytes = new Uint8Array(await image.arrayBuffer());
        let binary = '';
        const chunk = 0x8000;
        for (let i = 0; i < bytes.length; i += chunk) binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
        const base64 = btoa(binary);
        const mime = image.type || 'image/jpeg';
        body = await callOpenAI(env.OPENAI_API_KEY, [{
          role: 'user',
          content: [
            { type: 'input_text', text: prompt() },
            { type: 'input_image', image_url: `data:${mime};base64,${base64}` },
          ],
        }]);
      } else {
        const input = await request.json();
        const text = String(input?.text || '').trim();
        if (!text) return json({ error: 'Texto vazio.' }, 400, cors);
        body = await callOpenAI(env.OPENAI_API_KEY, [{ role: 'user', content: `${prompt()}\n\nAlimentos informados pelo usuário: ${text}` }]);
      }

      const result = parseOutput(body);
      return json(result, 200, cors);
    } catch (error) {
      return json({ error: error instanceof Error ? error.message : 'Erro ao analisar alimento.' }, 500, cors);
    }
  },
};

function prompt() {
  return `Você é um analisador nutricional para um aplicativo pessoal brasileiro. Identifique os alimentos, estime a quantidade e calcule calorias, proteína, carboidratos e gorduras. Seja conservador: se não souber, estime e deixe claro que é uma estimativa. Responda SOMENTE JSON válido, sem markdown, neste formato: {"items":[{"name":"arroz","grams":200,"calories":260,"protein":5.4,"carbs":56,"fat":0.6}],"note":"Valores estimados; confirme as porções."}. Nunca invente que uma foto contém um alimento com certeza; use nomes como “possível” quando houver incerteza.`;
}

async function callOpenAI(apiKey, input) {
  if (!apiKey) throw new Error('OPENAI_API_KEY não configurada no backend.');
  const response = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
    body: JSON.stringify({ model: 'gpt-5-mini', input, max_output_tokens: 900 }),
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`OpenAI HTTP ${response.status}: ${text.slice(0, 300)}`);
  return JSON.parse(text);
}

function parseOutput(response) {
  const text = response?.output_text || response?.output?.flatMap(x => x.content || []).map(x => x.text || '').join('') || '';
  const clean = text.replace(/^```json\s*/i, '').replace(/```\s*$/i, '').trim();
  const parsed = JSON.parse(clean);
  if (!Array.isArray(parsed.items)) throw new Error('Resposta de IA inválida.');
  return {
    items: parsed.items.map(x => ({
      name: String(x.name || 'Alimento'),
      grams: Number(x.grams) || 0,
      calories: Number(x.calories) || 0,
      protein: Number(x.protein) || 0,
      carbs: Number(x.carbs) || 0,
      fat: Number(x.fat) || 0,
    })),
    note: String(parsed.note || 'Valores estimados; confira as porções.'),
  };
}

function json(data, status, extra = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...extra },
  });
}
