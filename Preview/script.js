const apps = [
  { name: "TikTok", icon: "♪", className: "tiktok", locked: true },
  { name: "Instagram", icon: "◎", className: "instagram", locked: true },
  { name: "YouTube", icon: "▶", className: "youtube", locked: true },
  { name: "X", icon: "X", className: "x", locked: true },
  { name: "Discord", icon: "☁", className: "discord", locked: true }
];

const state = {
  pushups: 0,
  rest: 30,
  active: false
};

const appsNode = document.querySelector("#apps");
const habitInput = document.querySelector("#habitInput");
const ritualMeta = document.querySelector("#ritualMeta");
const pushupCount = document.querySelector("#pushupCount");
const restCount = document.querySelector("#restCount");
const doneState = document.querySelector("#doneState");
const activateButton = document.querySelector("#activateButton");

renderApps();

document.querySelector("#editApps").addEventListener("click", () => {
  const index = Math.floor(Math.random() * apps.length);
  apps[index].locked = !apps[index].locked;
  renderApps();
});

document.querySelector("#clearHabit").addEventListener("click", () => {
  habitInput.value = "";
  habitInput.focus();
});

document.querySelectorAll("[data-habit]").forEach((button) => {
  button.addEventListener("click", () => {
    habitInput.value = button.dataset.habit;
    generateRitual();
  });
});

document.querySelector("#pushupStep").addEventListener("click", () => {
  state.pushups = Math.min(10, state.pushups + 1);
  updateCounters();
});

document.querySelector("#restStep").addEventListener("click", () => {
  state.rest = Math.max(0, state.rest - 5);
  updateCounters();
});

document.querySelector("#doneStep").addEventListener("click", () => {
  state.pushups = 10;
  state.rest = 0;
  updateCounters();
});

activateButton.addEventListener("click", async () => {
  if (!state.active) {
    await generateRitual();
  }

  state.active = !state.active;
  activateButton.classList.toggle("active", state.active);
  activateButton.textContent = state.active ? "✓ Ritual ativo para apps bloqueados" : "▣ Ativar ritual e bloquear apps";
});

habitInput.addEventListener("change", generateRitual);

function renderApps() {
  appsNode.innerHTML = "";

  for (const app of apps) {
    const button = document.createElement("button");
    button.className = "app-button";
    button.type = "button";
    button.innerHTML = `
      <span class="app-icon-wrap">
        <span class="app-icon ${app.className}">${app.icon}</span>
        ${app.locked ? '<span class="lock-dot" aria-hidden="true">🔒</span>' : ""}
      </span>
      <strong>${app.name}</strong>
      <small>${app.locked ? "Bloqueado" : "Livre"}</small>
    `;
    button.addEventListener("click", () => {
      app.locked = !app.locked;
      renderApps();
    });
    appsNode.append(button);
  }
}

async function generateRitual() {
  const habit = habitInput.value.trim();
  if (!habit) return;

  const previous = activateButton.textContent;
  activateButton.textContent = "Gerando ritual com IA...";
  activateButton.disabled = true;

  try {
    const response = await fetch("http://127.0.0.1:8790/api/generate-ritual", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        habit,
        apps: apps.filter((app) => app.locked).map((app) => app.name)
      })
    });

    if (!response.ok) {
      throw new Error("Resposta inválida do backend");
    }

    const payload = await response.json();
    applyRitual(payload.ritual);
  } catch {
    applyRitual(localPreviewRitual(habit));
  } finally {
    activateButton.disabled = false;
    if (!state.active) {
      activateButton.textContent = previous.includes("Gerando") ? "▣ Ativar ritual e bloquear apps" : previous;
    }
  }
}

function applyRitual(ritual) {
  const heading = document.querySelector(".preview-heading h2");
  heading.textContent = ritual.title || "Prévia do ritual gerado pela IA";
  ritualMeta.textContent = `${ritual.category} • ${ritual.summary} • ~${ritual.durationMinutes} min`;

  const stepButtons = document.querySelectorAll(".step");
  ritual.steps.slice(0, 3).forEach((step, index) => {
    const button = stepButtons[index];
    button.querySelector("strong").textContent = `${index + 1}. ${step.title}`;
    button.querySelector("small").textContent = step.detail;
    button.querySelector("b").textContent = step.target;
  });

  state.pushups = 0;
  state.rest = 30;
  updateCounters();
}

function updateCounters() {
  pushupCount.textContent = `${state.pushups}/10`;
  restCount.textContent = `00:${String(state.rest).padStart(2, "0")}`;
  doneState.textContent = state.pushups >= 10 && state.rest === 0 ? "OK" : "";
}

function localPreviewRitual(habit) {
  const lower = habit.toLocaleLowerCase("pt-BR");

  if (lower.includes("gratid")) {
    return {
      title: "Gratidão antes do app",
      category: "Journaling",
      durationMinutes: 3,
      summary: "3 coisas concretas",
      steps: [
        { title: "Respire", detail: "Faça uma pausa curta.", target: "20s" },
        { title: "Escreva", detail: "Liste 3 gratidões específicas.", target: "3" },
        { title: "Conclua", detail: "Leia sua lista uma vez.", target: "OK" }
      ]
    };
  }

  return {
    title: "Flexões antes do app",
    category: "Força",
    durationMinutes: 2,
    summary: "10 flexões completas",
    steps: [
      { title: "Execução", detail: "10 flexões completas", target: "0/10" },
      { title: "Descanso", detail: "30 segundos", target: "00:30" },
      { title: "Conclusão", detail: "Marque como concluído", target: "" }
    ]
  };
}
