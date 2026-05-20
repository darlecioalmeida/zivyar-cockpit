(() => {
  const cards = [...document.querySelectorAll(".workspace-live-card")];
  const runningCountEl = document.getElementById("workspace-runtime-running-count");

  if (!cards.length) {
    return;
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function buildRuntimeAction(workspaceId, data) {
    if (!data.is_prepared) {
      return `
        <form
          method="post"
          action="/workspaces/${workspaceId}/runtime/prepare"
          class="inline-form runtime-action-form"
          data-runtime-action="prepare"
        >
          <button class="primary-button compact" type="submit">Preparar Runtime</button>
        </form>
      `;
    }

    if (data.is_running) {
      return `
        <form
          method="post"
          action="/workspaces/${workspaceId}/runtime/stop"
          class="inline-form runtime-action-form"
          data-runtime-action="stop"
        >
          <button class="danger-button" type="submit">Parar Runtime</button>
        </form>
      `;
    }

    return `
      <form
        method="post"
        action="/workspaces/${workspaceId}/runtime/start"
        class="inline-form runtime-action-form"
        data-runtime-action="start"
      >
        <button class="primary-button compact" type="submit">Iniciar Runtime</button>
      </form>
    `;
  }

  function updateCard(card, data) {
    const stateEl = card.querySelector(".workspace-live-runtime-state");
    const containerEl = card.querySelector(".workspace-live-runtime-container");
    const portEl = card.querySelector(".workspace-live-runtime-port");
    const serverEl = card.querySelector(".workspace-live-runtime-server");
    const actionsEl = card.querySelector(".workspace-live-runtime-actions");

    if (stateEl) {
      stateEl.textContent = data.state;
    }

    if (containerEl) {
      containerEl.textContent = data.container_name;
    }

    if (portEl) {
      portEl.textContent = data.opencode_port;
    }

    if (serverEl) {
      serverEl.textContent = data.server_url;
    }

    if (actionsEl) {
      const openCockpit = actionsEl.querySelector('a[href^="/workspaces/"]');
      const editLink = actionsEl.querySelector('a[href$="/edit"]');
      const deleteForm = actionsEl.querySelector('form[action$="/delete"]');

      const openHtml = openCockpit ? openCockpit.outerHTML : "";
      const editHtml = editLink ? editLink.outerHTML : "";
      const deleteHtml = deleteForm ? deleteForm.outerHTML : "";

      actionsEl.innerHTML = `
        ${openHtml}
        ${editHtml}
        ${buildRuntimeAction(card.dataset.workspaceId, data)}
        ${deleteHtml}
      `;
    }
  }

  async function refreshCard(card) {
    const workspaceId = card.dataset.workspaceId;

    if (!workspaceId) {
      return null;
    }

    try {
      const response = await fetch(`/workspaces/${workspaceId}/runtime/live`, {
        headers: {
          "Accept": "application/json"
        }
      });

      if (!response.ok) {
        return null;
      }

      const data = await response.json();

      if (!data.ok) {
        return null;
      }

      updateCard(card, data);
      return data;
    } catch (_) {
      return null;
    }
  }

  async function refreshAllCards() {
    const results = await Promise.all(cards.map((card) => refreshCard(card)));

    if (runningCountEl) {
      const totalRunning = results.filter((item) => item && item.is_running).length;
      runningCountEl.textContent = String(totalRunning);
    }
  }

  refreshAllCards();
  window.setInterval(refreshAllCards, 3000);
})();
