document.addEventListener("DOMContentLoaded", () => {
  const selectButton = document.getElementById("select-workspace-folder");
  const pathInput = document.getElementById("workspace-local-path");

  if (!selectButton || !pathInput) return;

  selectButton.addEventListener("click", async () => {
    try {
      if (!window.__TAURI__?.dialog?.open) {
        console.warn("Tauri Dialog indisponível. Esta ação funciona no app desktop.");
        return;
      }

      const selected = await window.__TAURI__.dialog.open({
        directory: true,
        multiple: false,
        title: "Selecionar pasta do workspace"
      });

      if (typeof selected === "string" && selected.length > 0) {
        pathInput.value = selected;
      }
    } catch (error) {
      console.error("Erro ao selecionar pasta:", error);
    }
  });
});
