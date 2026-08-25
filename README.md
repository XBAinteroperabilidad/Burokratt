# Bürokratt (hub) — XBA fork, local dev

Consolida los tres repos que hacen falta para levantar Bürokratt localmente con la
traducción al español ya aplicada, como submódulos de un solo repositorio:

- **`Chat-Widget/`** — widget de chat, rama `feature/es-translation`
- **`Customer-service/`** — backoffice/agente, rama `feature/local-build`
- **`Installation-Guides/`** — stack de infraestructura (docker-compose, config), rama `feature/local-dev-setup`

Todo apunta a los forks privados de `XBAinteroperabilidad`, no al repo público de Bürokratt.

## Requisitos

- Docker + Docker Compose
- `openssl` (para los certificados autofirmados)

## Cómo levantarlo (primera vez)

```bash
git clone --recurse-submodules https://github.com/XBAinteroperabilidad/Burokratt.git
cd Burokratt
cp .env.example .env   # ajustar si hace falta, los defaults ya sirven para localhost

# 1. Certificados TLS autofirmados para todos los servicios (idempotente)
./scripts/generate-certs.sh

# 2. Imágenes locales de los frontends traducidos (no están publicadas en ningún registry)
./scripts/build-frontends.sh

# 3. Bases de datos (Postgres para TIM y para el bot/backoffice)
docker compose -f Installation-Guides/default-setup/backoffice-and-bykstack/sql-db/docker-compose.yml up -d

# 4. Stack principal (ruuter, dmapper, tim, resql, widget, customer-service, monitoring...)
docker compose -f Installation-Guides/default-setup/backoffice-and-bykstack/docker-compose.yml up -d

# 5. Keycloak (reemplaza a TARA para el login local — no hace falta cuenta real)
docker compose -f keycloak/docker-compose.yml up -d

# 6. Seed de la base de datos del bot (una sola vez)
./scripts/seed-db.sh
```

El orden de 3→5 importa poco entre sí (todos comparten la red `bykstack`, que crea
el primero que se levante), pero **certs y las imágenes locales tienen que existir
antes** de levantar cualquier compose, y **seed-db.sh necesita `users-db` corriendo**.

## URLs una vez levantado

| Servicio | URL |
|---|---|
| Chat-Widget | https://localhost:3000 |
| Customer-service (backoffice) | https://localhost:3001 |
| Monitoring | https://localhost:8444 |
| Analytics (OpenSearch Dashboards) | https://localhost:5601 |
| Keycloak admin console | http://localhost:9080 (`admin`/`admin` por defecto) |

Login de prueba (usuario Keycloak pre-cargado, hace de TARA): **`testuser` / `testuser`**.

Todos los certs de los servicios `byk-*` son autofirmados — el navegador va a marcar
advertencia de seguridad la primera vez en cada puerto, hay que aceptarla manualmente.

## Volver a levantar / apagar

```bash
docker compose -f Installation-Guides/default-setup/backoffice-and-bykstack/docker-compose.yml down
docker compose -f Installation-Guides/default-setup/backoffice-and-bykstack/sql-db/docker-compose.yml down
docker compose -f keycloak/docker-compose.yml down
```

Agregar `-v` a cualquiera de esos si además querés borrar los volúmenes (bases de datos, etc).

## Actualizar los submódulos

```bash
git submodule update --remote --merge
```

## Qué NO está acá

- La integración con X-Road/XTR está en pausa (todavía no forma parte de este flujo de arranque). El scaffolding que existe hasta ahora quedó en el checkout viejo `/home/tito/Burokratt/Installation-Guides/`, no en este submódulo — falta portarlo acá cuando se retome (ver `~/.claude/projects/-home-tito/memory/burokratt-xroad-integration.md`).

## Nota: checkout viejo en paralelo

Además de este hub, sigue existiendo `/home/tito/Burokratt/` (frontends/Chat-Widget,
frontends/Customer-service, Installation-Guides sueltos, sin submódulos) — es el checkout
original de antes de armar este hub. Por ahora están sincronizados en los mismos commits,
pero pueden divergir si se edita uno sin el otro. Este hub (`Burokratt-hub/`) es el que
tiene el flujo de arranque simple; conviene decidir en algún momento si `/home/tito/Burokratt/`
se borra o se sigue usando para otra cosa.
