# DESIGN.md — Zivyar Cockpit

## Direção visual

O Zivyar Cockpit deve comunicar:
- precisão técnica;
- sensação de cockpit operacional;
- densidade visual controlada;
- foco em estado, panes, agentes e fluxo de missão.

## Estética

- Base escura.
- Superfícies com leve contraste.
- Bordas discretas.
- Destaques com tons ciano, verde, âmbar e vermelho.
- Tipografia monospace para indicadores técnicos e labels operacionais.
- Tipografia sans para texto de leitura.

## Layout

### Estrutura principal
- Topbar com workspaces, status e ações globais.
- Sidebar com módulos.
- Área central com panes.
- Coluna lateral opcional para Mission Room / Activity Stream.

### Grades
- Cards em grid.
- Painéis com cantos arredondados.
- Gaps generosos, mas compactos.

## Componentes-chave

- Workspace tab.
- Mission stepper.
- Agent card.
- Squad role slot.
- Runtime status badge.
- Provider card.
- Pane terminal header.
- Timeline event item.
- Graph/map teaser card.

## Tokens iniciais

```css
:root {
  --bg: #0a0f16;
  --panel: #111827;
  --panel-2: #172033;
  --border: #263043;
  --text: #e5edf7;
  --muted: #9fb0c7;
  --cyan: #43d6ff;
  --green: #35e09b;
  --amber: #f7bd4f;
  --red: #ff6b6b;
  --violet: #a78bfa;
}
```

## Estados

- Online: verde
- Atenção: âmbar
- Falha: vermelho
- Informação: ciano
- Inativo: cinza

## Princípio de produto

> A interface deve parecer uma sala de controle para desenvolvimento multiagente, não um chat genérico.

## Referências de design e operação

- [awesome-design-md](https://github.com/voltagent/awesome-design-md): biblioteca de DESIGN.md para manter tokens, atmosfera e regras visuais consistentes.
- [UI UX Pro Max Skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): referência de inteligência de design para escolher estilos, escalas e padrões visuais.
- [GSD](https://github.com/gsd-build/get-shit-done): referência operacional para o ciclo de execução, verificação e entrega.
- [ECC](https://github.com/affaan-m/ECC): referência de harness, skills, hooks e segurança para a camada de agente.

Essas referências devem guiar o cockpit sem alterar o domínio do produto.
O Zivyar continua sendo o sistema de orquestração, missão e contexto.
