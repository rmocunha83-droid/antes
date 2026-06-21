import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
loadEnv(resolve(root, ".env.local"));
loadEnv(resolve(root, ".env"));

const port = Number(process.env.PORT || 8787);
const model = process.env.OPENAI_MODEL || "gpt-5.5";

const ritualSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "category", "durationMinutes", "unlockMinutes", "summary", "steps", "completionAction"],
  properties: {
    title: { type: "string" },
    category: { type: "string" },
    durationMinutes: { type: "integer", minimum: 1, maximum: 30 },
    unlockMinutes: { type: "integer", minimum: 1, maximum: 120 },
    summary: { type: "string" },
    completionAction: { type: "string" },
    steps: {
      type: "array",
      minItems: 2,
      maxItems: 4,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "detail", "kind", "target"],
        properties: {
          title: { type: "string" },
          detail: { type: "string" },
          kind: {
            type: "string",
            enum: ["read", "write", "timer", "counter", "quiz", "check"]
          },
          target: { type: "string" }
        }
      }
    }
  }
};

const server = createServer(async (request, response) => {
  setCorsHeaders(response);

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }

  if (request.method === "GET" && request.url === "/health") {
    sendJson(response, 200, { ok: true, model });
    return;
  }

  if (request.method !== "POST" || request.url !== "/api/generate-ritual") {
    sendJson(response, 404, { error: "Not found" });
    return;
  }

  try {
    const body = await readJson(request);
    const habit = String(body.habit || "").trim();
    const apps = Array.isArray(body.apps) ? body.apps.map(String).slice(0, 8) : [];

    if (habit.length < 3) {
      sendJson(response, 400, { error: "Descreva um hábito para gerar o ritual." });
      return;
    }

    const ritual = await generateRitual({ habit, apps });
    sendJson(response, 200, { ritual });
  } catch (error) {
    sendJson(response, 500, {
      error: "Não foi possível gerar o ritual agora.",
      detail: error instanceof Error ? error.message : "Erro desconhecido"
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Antes AI backend running at http://127.0.0.1:${port}`);
});

async function generateRitual({ habit, apps }) {
  if (!process.env.OPENAI_API_KEY) {
    return localFallbackRitual(habit);
  }

  const apiResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      store: false,
      instructions: [
        "Voce cria micro-rituais positivos antes de desbloquear apps distrativos.",
        "Responda em portugues do Brasil.",
        "A interface deve ser curta, pratica e respeitosa com religioes diferentes.",
        "Nunca prometa bloqueio real de sistema; descreva o ritual de desbloqueio do app."
      ].join(" "),
      input: `Habito solicitado: ${habit}\nApps bloqueados: ${apps.join(", ") || "nao informado"}\nCrie uma interface ritual curta.`,
      text: {
        format: {
          type: "json_schema",
          name: "antes_ritual",
          strict: true,
          schema: ritualSchema
        }
      }
    })
  });

  if (!apiResponse.ok) {
    const errorText = await apiResponse.text();
    throw new Error(`OpenAI API ${apiResponse.status}: ${errorText.slice(0, 240)}`);
  }

  const result = await apiResponse.json();
  const outputText = result.output_text || extractOutputText(result);
  return JSON.parse(outputText);
}

function extractOutputText(result) {
  const text = result?.output
    ?.flatMap((item) => item?.content || [])
    ?.filter((content) => content?.type === "output_text")
    ?.map((content) => content?.text)
    ?.join("");

  if (!text) {
    throw new Error("Resposta da OpenAI sem texto estruturado.");
  }

  return text;
}

function localFallbackRitual(habit) {
  const lowered = habit.toLocaleLowerCase("pt-BR");

  if (lowered.includes("gratid")) {
    return {
      title: "Gratidao antes do app",
      category: "Journaling",
      durationMinutes: 3,
      unlockMinutes: 15,
      summary: "Escreva tres coisas concretas pelas quais voce e grato hoje.",
      completionAction: "Salvar reflexao",
      steps: [
        { title: "Respire", detail: "Faça uma pausa curta antes de escrever.", kind: "timer", target: "20 segundos" },
        { title: "Escreva", detail: "Liste 3 gratidoes especificas.", kind: "write", target: "3 itens" },
        { title: "Conclua", detail: "Leia sua lista uma vez.", kind: "check", target: "1 leitura" }
      ]
    };
  }

  if (lowered.includes("ora") || lowered.includes("bib") || lowered.includes("escrit")) {
    return {
      title: "Oracao e leitura breve",
      category: "Espiritualidade",
      durationMinutes: 2,
      unlockMinutes: 15,
      summary: "Faça uma oração curta e leia um pequeno texto antes de desbloquear.",
      completionAction: "Marcar como orado",
      steps: [
        { title: "Oração", detail: "Diga uma intenção simples para o dia.", kind: "timer", target: "45 segundos" },
        { title: "Leitura", detail: "Leia um parágrafo de escritura.", kind: "read", target: "1 parágrafo" },
        { title: "Fechamento", detail: "Escolha uma atitude prática.", kind: "check", target: "1 ação" }
      ]
    };
  }

  return {
    title: "Flexoes antes do app",
    category: "Forca",
    durationMinutes: 2,
    unlockMinutes: 15,
    summary: "Complete uma serie curta para desbloquear com intenção.",
    completionAction: "Marcar treino concluido",
    steps: [
      { title: "Execucao", detail: "Faça 10 flexões completas.", kind: "counter", target: "10" },
      { title: "Descanso", detail: "Recupere a respiração.", kind: "timer", target: "30 segundos" },
      { title: "Conclusao", detail: "Marque o ritual como concluido.", kind: "check", target: "1 toque" }
    ]
  };
}

function readJson(request) {
  return new Promise((resolveJson, reject) => {
    let body = "";
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1_000_000) {
        request.destroy();
        reject(new Error("Payload muito grande."));
      }
    });
    request.on("end", () => {
      try {
        resolveJson(body ? JSON.parse(body) : {});
      } catch {
        reject(new Error("JSON invalido."));
      }
    });
    request.on("error", reject);
  });
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function setCorsHeaders(response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
}

function loadEnv(path) {
  if (!existsSync(path)) return;

  const lines = readFileSync(path, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) continue;
    const key = trimmed.slice(0, separatorIndex).trim();
    const value = trimmed.slice(separatorIndex + 1).trim().replace(/^['"]|['"]$/g, "");
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}
