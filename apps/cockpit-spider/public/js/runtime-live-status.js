(() => {
  const panel = document.getElementById("workspace-runtime-panel");

  if (!panel) {
    return;
  }

  const workspaceId = panel.dataset.workspaceId;

  if (!workspaceId) {
    return;
  }

  const stateEl = document.getElementById("runtime-live-state");
  const messageEl = document.getElementById("runtime-live-message");
  const containerEl = document.getElementById("runtime-live-container");
  const portEl = document.getElementById("runtime-live-port");
  const serverEl = document.getElementById("runtime-live-server");

  const eventCountEl = document.getElementById("runtime-live-event-count");
  const historyBodyEl = document.getElementById("runtime-live-history-body");

  const logCountEl = document.getElementById("runtime-live-log-count");
  const logsBodyEl = document.getElementById("runtime-live-logs-body");

  const overlay = document.getElementById("runtime-loading-overlay");
  const overlayTitle = document.getElementById("runtime-loading-title");
  const overlayMessage = document.getElementById("runtime-loading-message");
  const overlayStep = document.getElementById("runtime-loading-step");
  const overlayHint = document.getElementById("runtime-loading-hint");

  let refreshInFlight = false;

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function showPaneSessionOverlay(roleName) {
    if (!overlay || !overlayTitle || !overlayMessage || !overlayStep || !overlayHint) {
      return;
    }

    overlayTitle.textContent = `Abrindo sessão do pane ${roleName}`;
    overlayMessage.textContent =
      "O Zivyar está criando uma sessão real no OpenCode Server e vinculando-a ao workspace.";
    overlayStep.textContent = "Criando sessão no OpenCode";
    overlayHint.textContent =
      "Aguarde a conclusão. O card será atualizado automaticamente.";

    overlay.hidden = false;
    document.body.classList.add("runtime-operation-active");
  }

  function hidePaneSessionOverlay() {
    if (!overlay) {
      return;
    }

    overlay.hidden = true;
    document.body.classList.remove("runtime-operation-active");
  }

  function renderHistory(events, count) {
    if (eventCountEl) {
      eventCountEl.textContent = `${count} eventos`;
    }

    if (!historyBodyEl) {
      return;
    }

    if (!count) {
      historyBodyEl.innerHTML = `
        <div class="empty-inline-state">
          <strong>Nenhum evento registrado.</strong>
          <p>Prepare ou inicie o runtime para gerar o histórico operacional deste workspace.</p>
        </div>
      `;
      return;
    }

    historyBodyEl.innerHTML = `
      <div class="runtime-event-list">
        ${events.map((event) => `
          <article class="runtime-event-card">
            <span class="runtime-event-type">${escapeHtml(event.event_type)}</span>
            <div>
              <strong>${escapeHtml(event.title)}</strong>
              <p>${escapeHtml(event.message)}</p>
            </div>
          </article>
        `).join("")}
      </div>
    `;
  }

  function renderLogs(logs, count) {
    if (logCountEl) {
      logCountEl.textContent = `${count} registros`;
    }

    if (!logsBodyEl) {
      return;
    }

    if (!count) {
      logsBodyEl.innerHTML = `
        <div class="empty-inline-state">
          <strong>Nenhum log técnico registrado.</strong>
          <p>Os comandos Docker executados pelo runtime aparecerão aqui.</p>
        </div>
      `;
      return;
    }

    logsBodyEl.innerHTML = `
      <div class="runtime-log-list">
        ${logs.map((log) => `
          <details class="runtime-log-card">
            <summary>
              <div>
                <strong>${escapeHtml(log.action)}</strong>
                <span>${escapeHtml(log.command_label)}</span>
              </div>

              <span class="runtime-log-status ${log.succeeded ? "ok" : "error"}">
                ${log.succeeded ? "OK" : "ERRO"}
              </span>
            </summary>

            <div class="runtime-log-body">
              <div class="runtime-log-meta">
                <span>Exit code</span>
                <strong>${escapeHtml(log.exit_code)}</strong>
              </div>

              ${log.stdout_excerpt ? `
                <div class="runtime-log-output">
                  <span>STDOUT</span>
                  <pre>${escapeHtml(log.stdout_excerpt)}</pre>
                </div>
              ` : ""}

              ${log.stderr_excerpt ? `
                <div class="runtime-log-output danger">
                  <span>STDERR</span>
                  <pre>${escapeHtml(log.stderr_excerpt)}</pre>
                </div>
              ` : ""}
            </div>
          </details>
        `).join("")}
      </div>
    `;
  }

  function renderPaneAction(card, pane, runtimeData) {
    const actionsEl = card.querySelector(".workspace-pane-actions");

    if (!actionsEl) {
      return;
    }

    if (pane.session_external_id) {
      actionsEl.innerHTML = `
        <a class="ghost-mini" href="${escapeHtml(runtimeData.server_url)}" target="_blank" rel="noreferrer">
          Abrir Server
        </a>
      `;
      return;
    }

    if (runtimeData.is_running) {
      actionsEl.innerHTML = `
        <form
          method="post"
          action="/workspaces/${workspaceId}/panes/${pane.id}/session/open"
          class="inline-form pane-session-open-form"
        >
          <button class="primary-button compact" type="submit">Abrir sessão</button>
        </form>
      `;
      return;
    }

    actionsEl.innerHTML = `
      <button class="ghost-mini" type="button" disabled>Runtime parado</button>
    `;
  }

  function renderPanes(panes, runtimeData) {
    panes.forEach((pane) => {
      const card = document.querySelector(`.workspace-pane-card[data-pane-id="${pane.id}"]`);

      if (!card) {
        return;
      }

      card.dataset.paneState = pane.pane_state;
      card.dataset.sessionId = pane.session_external_id || "";

      const statusEl = card.querySelector(".workspace-pane-status-row strong");
      if (statusEl) {
        statusEl.textContent = pane.pane_state;
      }

      let sessionBox = card.querySelector(".workspace-pane-session");

      if (pane.session_external_id) {
        if (!sessionBox) {
          sessionBox = document.createElement("div");
          sessionBox.className = "workspace-pane-session";

          const actionsEl = card.querySelector(".workspace-pane-actions");
          if (actionsEl) {
            card.insertBefore(sessionBox, actionsEl);
          }
        }

        sessionBox.innerHTML = `
          <span>Sessão OpenCode</span>
          <strong>${escapeHtml(pane.session_external_id)}</strong>
        `;
      } else if (sessionBox) {
        sessionBox.remove();
      }

      renderPaneAction(card, pane, runtimeData);
    });
  }

  async function refreshRuntimeStatus() {
    if (refreshInFlight) {
      return;
    }

    refreshInFlight = true;

    try {
      const response = await fetch(`/workspaces/${workspaceId}/runtime/live`, {
        headers: {
          "Accept": "application/json"
        }
      });

      if (!response.ok) {
        return;
      }

      const data = await response.json();

      if (!data.ok) {
        return;
      }

      if (stateEl) {
        stateEl.textContent = data.state;
      }

      if (messageEl) {
        messageEl.textContent = data.status_message;
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

      renderHistory(data.runtime_events || [], data.runtime_event_count || 0);
      renderLogs(data.runtime_logs || [], data.runtime_log_count || 0);
      renderPanes(data.workspace_panes || [], data);

      const buttonsArea = panel.querySelector(".runtime-actions, .runtime-prepare-form");

      if (!buttonsArea) {
        return;
      }

      if (data.is_running) {
        buttonsArea.innerHTML = `
          <a class="primary-button" href="${escapeHtml(data.server_url)}" target="_blank" rel="noreferrer">Abrir Server</a>

          <form method="post" action="/workspaces/${workspaceId}/runtime/stop" class="inline-form runtime-action-form" data-runtime-action="stop">
            <button class="danger-button" type="submit">Parar Runtime</button>
          </form>
        `;
      } else if (data.is_prepared) {
        buttonsArea.innerHTML = `
          <form method="post" action="/workspaces/${workspaceId}/runtime/start" class="inline-form runtime-action-form" data-runtime-action="start">
            <button class="primary-button" type="submit">Iniciar Runtime</button>
          </form>
        `;
      }
    } catch (_) {
      // Falha transitória silenciosa.
    } finally {
      refreshInFlight = false;
    }
  }

  document.addEventListener("submit", async (event) => {
    const form = event.target.closest(".pane-session-open-form");

    if (!form) {
      return;
    }

    event.preventDefault();

    const card = form.closest(".workspace-pane-card");
    const roleName =
      card?.querySelector(".workspace-pane-head strong")?.textContent?.trim() || "agente";

    const button = form.querySelector("button[type='submit']");

    if (button) {
      button.disabled = true;
      button.textContent = "Criando sessão...";
    }

    showPaneSessionOverlay(roleName);

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: {
          "Accept": "text/html"
        }
      });

      if (!response.ok) {
        throw new Error("Falha ao abrir sessão.");
      }

      await refreshRuntimeStatus();
    } catch (_) {
      if (button) {
        button.disabled = false;
        button.textContent = "Abrir sessão";
      }
    } finally {
      hidePaneSessionOverlay();
    }
  });

  refreshRuntimeStatus();
  window.setInterval(refreshRuntimeStatus, 3000);
})();
