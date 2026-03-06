# defer

A minimal, idiomatic Haskell web app scaffold using **Cabal + WAI/Warp**.

Now includes a simple **SQLite** integration using **Persistent + Esqueleto**.

## Why this setup

- `wai` gives a simple, composable web application interface.
- `warp` is the production-grade HTTP server commonly used in Haskell.
- View rendering (`Defer.Frontend`) is kept pure and separate from request handling (`Defer.App`).

## Project structure

- `src/Defer/Frontend.hs`: simple server-rendered HTML frontend.
- `src/Defer/Database.hs`: Persistent schema/migrations + Esqueleto queries.
- `src/Defer/App.hs`: WAI application and runtime config (port).
- `app/Main.hs`: executable entrypoint.
- `test/Main.hs`: integration-style tests against the WAI app.

## Run it

```bash
cabal update
cabal run defer-web
```

Then open: <http://localhost:3000>

Available endpoints:

- `GET /` -> HTML homepage rendered from SQLite articles
- `GET /health` -> JSON status payload
- `GET /api/articles` -> JSON list of seeded articles from SQLite
- `POST /api/articles` -> import article from URL and persist title/summary/content

Homepage integration:

- `/` now includes an **Import article** form.
- Paste a URL and submit to call `POST /api/articles` from the browser.
- On success, the page reloads and shows the newly imported article.

Set a custom port:

```bash
PORT=8080 cabal run defer-web
```

Set a custom SQLite database path:

```bash
DB_PATH=./data/defer.sqlite3 cabal run defer-web
```

Run tests:

```bash
cabal test defer-test
```

## Learn-next roadmap

1. Add routing (e.g. `wai-routing` or `servant`).
2. Add structured config (env + defaults).
3. Add logging (`fast-logger`, `co-log` or `katip`).
4. Add richer query features (filters, paging, search with Esqueleto).
5. Add integration tests (`wai-extra` / `hspec-wai`).

## Newcomer tips

- Keep IO at the edges (`Main`, DB wiring) and keep rendering/domain logic pure.
- Favor explicit types on top-level functions; it helps both compiler guidance and readability.
- Use `Maybe` for optional values (`lookupEnv`) rather than sentinel values.
- Start with small modules (`App`, `Database`, `Frontend`) and grow boundaries deliberately.
