# defer

A minimal, idiomatic Haskell web app scaffold using **Cabal + WAI/Warp**.

## Why this setup

- `wai` gives a simple, composable web application interface.
- `warp` is the production-grade HTTP server commonly used in Haskell.
- View rendering (`Defer.Frontend`) is kept pure and separate from request handling (`Defer.App`).

## Project structure

- `src/Defer/Frontend.hs`: simple server-rendered HTML frontend.
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

- `GET /` -> HTML homepage with sample article summaries
- `GET /health` -> JSON status payload

Set a custom port:

```bash
PORT=8080 cabal run defer-web
```

Run tests:

```bash
cabal test defer-test
```

## Learn-next roadmap

1. Add routing (e.g. `wai-routing` or `servant`).
2. Add structured config (env + defaults).
3. Add logging (`fast-logger`, `co-log` or `katip`).
4. Add persistence (`persistent`/`beam`/`postgresql-simple`).
5. Add integration tests (`wai-extra` / `hspec-wai`).
