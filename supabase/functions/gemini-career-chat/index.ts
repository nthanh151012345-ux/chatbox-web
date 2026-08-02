import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

type ChatTurn = {
  role: 'user' | 'model';
  text: string;
};

const vietnamesePrompt = `Bạn là tư vấn viên hướng nghiệp thân thiện cho học sinh THPT Việt Nam.
Chỉ hỗ trợ: khám phá sở thích/năng lực/tính cách; gợi ý ngành học; trường đại học/cao đẳng; thông tin tuyển sinh; kế hoạch học tập.
Nếu câu hỏi ngoài hướng nghiệp, từ chối ngắn gọn và mời quay lại chủ đề hướng nghiệp.
Khi chưa đủ thông tin, chỉ hỏi MỘT câu quan trọng nhất về sở thích, môn mạnh, điểm dự kiến, tính cách hoặc hoàn cảnh.
Chỉ khi đã đủ thông tin mới gợi ý 2-3 ngành, nêu lý do ngắn và khối thi/tổ hợp phù hợp. Có thể gợi ý tối đa 2 trường nếu người dùng yêu cầu.
Trả lời bằng tiếng Việt, tối đa 120 từ, dễ hiểu, dùng gạch đầu dòng khi cần. Không tự lặp lại lời chào.`;

const englishPrompt = `You are a friendly career guidance counselor for Vietnamese high-school students.
Only help with interests, abilities and personality; major suggestions; suitable colleges; admissions information; and study plans.
For off-topic requests, politely decline and redirect to career guidance.
When information is insufficient, ask exactly ONE most important question about interests, strong subjects, expected score, personality, or circumstances.
Only after enough information, suggest 2-3 majors with brief reasons and suitable subject combinations. Suggest at most 2 schools when asked.
Reply in English, under 120 words, plainly and with bullets when useful. Do not repeat a greeting.`;

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const isChatTurn = (value: unknown): value is ChatTurn => {
  if (typeof value !== 'object' || value === null) return false;
  const turn = value as Record<string, unknown>;
  return (
    (turn.role === 'user' || turn.role === 'model') &&
    typeof turn.text === 'string' &&
    turn.text.trim().length > 0
  );
};

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    console.error('GEMINI_API_KEY is not configured.');
    return json({ error: 'Trợ lý AI chưa được cấu hình.' }, 500);
  }

  const payload = await request.json().catch(() => null);
  if (typeof payload !== 'object' || payload === null) {
    return json({ error: 'Yêu cầu không hợp lệ.' }, 400);
  }
  const body = payload as Record<string, unknown>;
  const turns = Array.isArray(body.contents) ? body.contents.filter(isChatTurn) : [];
  const contents = turns.slice(-20).map((turn) => ({
    role: turn.role,
    parts: [{ text: turn.text.trim().slice(0, 4000) }],
  }));
  if (contents.length === 0 || contents[0].role !== 'user') {
    return json({ error: 'Hãy nhập câu hỏi hướng nghiệp trước nhé.' }, 400);
  }

  const languageCode = body.languageCode === 'en' ? 'en' : 'vi';
  const model = Deno.env.get('GEMINI_MODEL') ?? 'gemini-3.1-flash-lite';
  const geminiResponse = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify({
        system_instruction: {
          parts: [{ text: languageCode === 'en' ? englishPrompt : vietnamesePrompt }],
        },
        contents,
      }),
    },
  );
  const geminiBody = await geminiResponse.json().catch(() => ({}));
  if (!geminiResponse.ok) {
    console.error('Gemini request failed:', geminiResponse.status);
    if (geminiResponse.status === 429) {
      return json({ error: 'AI đang quá tải. Bạn hãy thử lại sau ít phút.' }, 429);
    }
    return json({ error: 'AI chưa thể phản hồi. Bạn hãy thử lại sau nhé.' }, 502);
  }

  const text = (geminiBody as { candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }> })
    .candidates?.[0]?.content?.parts
    ?.map((part) => part.text ?? '')
    .join('\n')
    .trim();
  if (!text) {
    return json({ error: 'AI chưa tạo được câu trả lời. Hãy thử diễn đạt lại nhé.' }, 502);
  }
  return json({ text });
});
