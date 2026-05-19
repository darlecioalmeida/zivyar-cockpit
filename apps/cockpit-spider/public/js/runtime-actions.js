(() => {
  const overlay = document.getElementById("runtime-loading-overlay");
  const title = document.getElementById("runtime-loading-title");
  const message = document.getElementById("runtime-loading-message");
  const step = document.getElementById("runtime-loading-step");
  const hint = document.getElementById("runtime-loading-hint");

  if (!overlay || !title || !message || !step || !hint) {
    return;
  }

  const contentByAction = {
    prepare: {
      title: "Preparando o runtime do workspace",
      message: "O Zivyar está registrando a estrutura operacional deste workspace.",
      hint: "Esta etapa é rápida e deixa o projeto pronto para iniciar o OpenCode Server.",
      steps: [
        "Validando workspace",
        "Criando estado persistido do runtime",
        "Finalizando preparação"
      ]
    },
    start: {
      title: "Iniciando OpenCode Server",
      message: "O Zivyar está verificando a imagem Docker, subindo o container e validando o servidor.",
      hint: "Na primeira execução, a preparação da imagem pode levar mais tempo.",
      steps: [
        "Verificando imagem do runtime",
        "Construindo ou reutilizando imagem Docker",
        "Criando ou iniciando container",
        "Validando healthcheck do OpenCode",
        "Atualizando painel do workspace"
      ]
    },
    stop: {
      title: "Parando o runtime do workspace",
      message: "O Zivyar está encerrando o container com segurança e atualizando o estado do runtime.",
      hint: "O container poderá ser iniciado novamente quando necessário.",
      steps: [
        "Enviando comando de parada",
        "Aguardando confirmação do Docker",
        "Atualizando status do runtime"
      ]
    }
  };

  let activeInterval = null;

  function startStepAnimation(steps) {
    let index = 0;
    step.textContent = steps[index];

    if (activeInterval) {
      window.clearInterval(activeInterval);
    }

    activeInterval = window.setInterval(() => {
      index = (index + 1) % steps.length;
      step.textContent = steps[index];
    }, 1800);
  }

  document.addEventListener("submit", (event) => {
    const form = event.target.closest(".runtime-action-form");

    if (!form) {
      return;
    }

    const action = form.dataset.runtimeAction || "start";
    const content = contentByAction[action] || contentByAction.start;
    const button = form.querySelector("button[type='submit']");

    if (button) {
      button.disabled = true;
      button.dataset.originalText = button.textContent || "";
      button.textContent = "Processando...";
    }

    title.textContent = content.title;
    message.textContent = content.message;
    hint.textContent = content.hint;

    overlay.hidden = false;
    document.body.classList.add("runtime-operation-active");

    startStepAnimation(content.steps);
  });
})();
