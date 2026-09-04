const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

// چانک‌های SSE را به یک پاسخ استاندارد OpenAI تبدیل می‌کند
function aggregateSse(text: string) {
  let content = "";
  let model = "";
  let finish = "stop";
  for (const rawLine of text.split("\n")) {
    const line = rawLine.trim();
    if (!line.startsWith("data:")) continue;
    const payload = line.slice(5).trim();
    if (!payload || payload === "[DONE]") continue;
    try {
      const chunk = JSON.parse(payload);
      model = chunk.model ?? model;
      const c = chunk.choices?.[0];
      finish = c?.finish_reason ?? finish;
      const piece = c?.delta?.content ?? c?.message?.content;
      if (typeof piece === "string") content += piece;
    } catch {
      /* چانک ناقص را رد کن */
    }
  }
  return {
    model,
    choices: [{ index: 0, message: { role: "assistant", content }, finish_reason: finish }],
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: { message: "Method not allowed" } }, 405);

  try {
    const body = await req.json();
    body.stream = false; // هرگز استریم نخواه

    const baseUrl = Deno.env.get("AI_BASE_URL") ?? "https://9router-production-94cd.up.railway.app/v1";
    const apiKey = Deno.env.get("AI_API_KEY") ?? "sk-6e26defd4d317d82-gblxln-0646a8bb";
    if (!baseUrl || !apiKey) {
      return json({ error: { message: "AI_BASE_URL یا AI_API_KEY تنظیم نشده است" } }, 500);
    }

    const cleanBaseUrl = baseUrl.replace(/\/+$/, "");
    const upstream = await fetch(`${cleanBaseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(body),
    });

    const text = await upstream.text();
    const ctype = upstream.headers.get("content-type") ?? "";

    if (ctype.includes("text/event-stream") || text.trimStart().startsWith("data:")) {
      return json(aggregateSse(text), upstream.status);
    }

    try {
      return json(JSON.parse(text), upstream.status);
    } catch {
      return json(
        { error: { message: "پاسخ نامعتبر از سرور بالادست", status: upstream.status, raw: text.slice(0, 500) } },
        502,
      );
    }
  } catch (e) {
    return json({ error: { message: String(e) } }, 500);
  }
});
