# Bootstrap manual sugerido

## 1. Banco local
```bash
scripts/ensure-local-postgres.sh
```

## 2. Spider
```bash
cd apps/cockpit-spider
cp .env.example .env
zig fetch --save git+https://github.com/llllOllOOll/spider#main
zig build run
```

Os passos `zig build` e `zig build run` também executam `scripts/ensure-local-postgres.sh` automaticamente. Se o Docker Desktop estiver instalado no macOS, o script tenta abri-lo e aguarda o daemon ficar pronto. Para compilar sem subir infra local, use `zig build -Dskip-db=true`.

## 3. Tauri
Em outro terminal:
```bash
cd apps/desktop-tauri
npm install
npm run dev
```
