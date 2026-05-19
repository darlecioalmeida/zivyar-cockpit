# Bootstrap manual sugerido

## 1. Banco local
```bash
docker compose -f infra/compose/docker-compose.local.yml up -d
```

## 2. Spider
```bash
cd apps/cockpit-spider
cp .env.example .env
zig fetch --save git+https://github.com/llllOllOOll/spider#main
zig build run
```

## 3. Tauri
Em outro terminal:
```bash
cd apps/desktop-tauri
npm install
npm run dev
```
