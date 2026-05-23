(() => {
  const panel = document.getElementById("war-room-panel");

  if (!panel) {
    return;
  }

  const workspaceId = panel.dataset.workspaceId;

  if (!workspaceId) {
    return;
  }

  const stateEl = document.getElementById("war-room-runtime-state");
  const containerEl = document.getElementById("war-room-runtime-container");
  const portEl = document.getElementById("war-room-runtime-port");
  const serverEl = document.getElementById("war-room-runtime-server");
  const messageEl = document.getElementById("war-room-runtime-message");
  const missionBodyEl = document.getElementById("war-room-mission-body");
  const missionCountEl = document.getElementById("war-room-mission-count");
  const paneGridEl = document.getElementById("war-room-pane-grid");
  const paneCountEl = document.getElementById("war-room-pane-count");
  const eventListEl = document.getElementById("war-room-event-list");
  const eventCountEl = document.getElementById("war-room-event-count");

  function escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function renderMission(mission) {
    if (!missionBodyEl || !missionCountEl) {
      return;
    }

    missionCountEl.textContent = mission ? "1" : "0";

    if (!mission) {
      missionBodyEl.innerHTML = `
        <div class="empty-inline-state">
          <strong>Nenhuma missão ativa.</strong>
          <p>Ative uma missão para acompanhar a cadeia Piloto, Planner, Scout, Builder, Reviewer e Executor.</p>
        </div>
      `;
      return;
    }

    missionBodyEl.innerHTML = `
      <div class="war-room-active-mission">
        <strong>${escapeHtml(mission.title)}</strong>
        <p>${escapeHtml(mission.objective)}</p>

        <div class="war-room-kv-grid compact">
          <div><span>Status</span><strong>${escapeHtml(mission.status)}</strong></div>
          <div><span>Modo</span><strong>${escapeHtml(mission.execution_mode)}</strong></div>
          <div><span>Próximo passo</span><strong>${escapeHtml(mission.next_step_detected_code || "Aguardando")}</strong></div>
        </div>

        ${mission.next_step_detected_route ? `
          <form method="post" action="${escapeHtml(mission.next_step_detected_route)}" class="inline-form">
            <button class="primary-button" type="submit">Executar próximo passo</button>
          </form>
        ` : ""}
      </div>
    `;
  }

  function renderPanes(panes) {
    if (!paneGridEl || !paneCountEl) {
      return;
    }

    paneCountEl.textContent = `${panes.length} panes`;

    if (!panes.length) {
      paneGridEl.innerHTML = `
        <div class="empty-inline-state">
          <strong>Nenhum pane materializado.</strong>
          <p>Vincule uma squad ao workspace para criar os assentos operacionais.</p>
        </div>
      `;
      return;
    }

    paneGridEl.innerHTML = panes.map((pane) => `
      <article class="war-room-pane-card" data-pane-state="${escapeHtml(pane.pane_state)}" data-context-state="${escapeHtml(pane.context_state)}">
        <div>
          <strong>${escapeHtml(pane.role_name)}</strong>
          <span>${escapeHtml(pane.agent_name)} · ${escapeHtml(pane.agent_handle)}</span>
        </div>

        <div class="war-room-pane-meta">
          <span>${escapeHtml(pane.stack_name)}</span>
          <strong>${escapeHtml(pane.pane_state)}</strong>
        </div>

        <small>${pane.session_external_id ? escapeHtml(pane.session_external_id) : "Sem sessão vinculada"}</small>
      </article>
    `).join("");
  }

  function renderEvents(events, count) {
    if (!eventListEl || !eventCountEl) {
      return;
    }

    eventCountEl.textContent = `${count} eventos`;

    if (!events.length) {
      eventListEl.innerHTML = `
        <div class="empty-inline-state">
          <strong>Nenhum evento de missão registrado.</strong>
          <p>A timeline será preenchida quando a missão começar a circular entre os agentes.</p>
        </div>
      `;
      return;
    }

    eventListEl.innerHTML = `
      <div class="runtime-event-list">
        ${events.map((event) => `
          <article class="runtime-event-card">
            <span class="runtime-event-type">${escapeHtml(event.event_type)}</span>
            <div>
              <strong>${escapeHtml(event.title)}</strong>
              <p>${escapeHtml(event.message)}</p>
              <small>${escapeHtml(event.created_at_label)}</small>
            </div>
          </article>
        `).join("")}
      </div>
    `;
  }

  async function refreshWarRoom() {
    try {
      const response = await fetch(`/workspaces/${workspaceId}/war-room/live`, {
        headers: { "Accept": "application/json" }
      });

      if (!response.ok) {
        return;
      }

      const data = await response.json();

      if (!data.ok) {
        return;
      }

      if (stateEl) stateEl.textContent = data.runtime?.state || "missing";
      if (containerEl) containerEl.textContent = data.runtime?.container_name || "";
      if (portEl) portEl.textContent = data.runtime?.opencode_port_label || "Não alocado";
      if (serverEl) serverEl.textContent = data.runtime?.server_url_label || "Servidor não iniciado";
      if (messageEl) messageEl.textContent = data.runtime?.status_message || "Runtime ainda não preparado.";

      renderMission(data.active_mission || null);
      renderPanes(data.panes || []);
      renderEvents(data.mission_events || [], data.mission_event_count || 0);
    } catch (_) {
      // Atualização silenciosa: a próxima rodada tenta novamente.
    }
  }

  refreshWarRoom();
  window.setInterval(refreshWarRoom, 3000);
})();
