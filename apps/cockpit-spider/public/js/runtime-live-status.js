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

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
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

  function refreshPaneSessionActions(data) {
    const paneCards = document.querySelectorAll(".workspace-pane-card");

    paneCards.forEach((card) => {
      const paneId = card.dataset.paneId;
      const sessionId = card.dataset.sessionId || "";
      const actionsEl = card.querySelector(".workspace-pane-actions");

      if (!actionsEl || !paneId || !workspaceId) {
        return;
      }

      // Pane já possui sessão aberta: não alterar este bloco.
      if (sessionId.length > 0) {
        return;
      }

      if (data.is_running) {
        actionsEl.innerHTML = `
          <form method="post" action="/workspaces/${workspaceId}/panes/${paneId}/session/open" class="inline-form">
            <button class="primary-button compact" type="submit">Abrir sessão</button>
          </form>
        `;
      } else {
        actionsEl.innerHTML = `
          <button class="ghost-mini" type="button" disabled>Runtime parado</button>
        `;
      }
    });
  }

  async function refreshRuntimeStatus() {
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
      refreshPaneSessionActions(data);

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
      // Silencioso para não poluir a interface em falhas transitórias.
    }
  }

  refreshRuntimeStatus();
  window.setInterval(refreshRuntimeStatus, 3000);
})();
