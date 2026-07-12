# Oneira — dream knowledge base + `/explain` API (Phase 0)

_"Oneira" is a working name (Greek **ὄνειρα**, "dreams" — the root of Artemidorus' Oneirocritica). Rename freely._

Phase 0 of the dream‑logger app: the **backend magic**, proven before any UI exists.
Give it a dream in plain language; it retrieves relevant passages from a
**public‑domain** dream‑interpretation library and returns a grounded,
**quoted, attributed** interpretation.

```
dream text ──▶ embed ──▶ retrieve top‑K passages ──▶ interpret (grounded in + quoting them)
                              │                              │
                     public‑domain KB                 Claude  (or offline stub)
              (Freud · Miller's dictionary)
```

It runs **fully offline** out of the box (deterministic stub providers, no API
key), and flips to **Claude + real embeddings** by setting two env vars.

---

## Quickstart

```bash
cd oneira
npm install                      # only needed for the Claude path; stub runs without it
npm run download                 # fetch public-domain texts from Project Gutenberg → data/raw/
npm run ingest                   # chunk + index → data/index.json
npm run explain -- "I dreamt my teeth were crumbling and falling out into my hands."
npm run serve                    # POST http://localhost:8787/explain  {"dream":"..."}
```

Example (`npm run explain`) returns a grounded reading quoting Miller's **Teeth**,
**Dentist**, and **Fall** entries verbatim, plus structured `symbols`, `quotes`,
and a reflective question.

---

## Providers (stub → real)

Everything is env‑driven (see `.dev.vars.example`). Defaults are offline stubs.

| Variable | Default | Options |
|---|---|---|
| `EMBEDDINGS_PROVIDER` | `stub` | `openai`, `voyage` — **re‑run `npm run ingest` after changing** |
| `LLM_PROVIDER` | `stub` | `claude` |
| `ANTHROPIC_API_KEY` | — | required for `LLM_PROVIDER=claude` |
| `CLAUDE_MODEL` | `claude-opus-4-8` | any current Claude model |
| `OPENAI_API_KEY` / `OPENAI_EMBED_MODEL` | — / `text-embedding-3-small` | |
| `VOYAGE_API_KEY` / `VOYAGE_EMBED_MODEL` | — / `voyage-3.5-lite` | |
| `TOP_K` | `6` | passages retrieved per dream |
| `PORT` | `8787` | server port |

Turn on the real stack:

```bash
export LLM_PROVIDER=claude ANTHROPIC_API_KEY=sk-ant-...
export EMBEDDINGS_PROVIDER=voyage VOYAGE_API_KEY=...   # optional; then re-ingest
npm run ingest        # only needed if you changed EMBEDDINGS_PROVIDER
npm run serve
```

### stub vs. real — a concrete example

The stub embedding is **lexical** (IDF‑weighted sparse TF‑IDF). It handles
literal overlap well (a "teeth" dream → Miller's **Teeth**/**Dentist**/**Fall**),
but it cannot bridge synonyms. Miller files snakes under the headword
**"Reptile"** — there is no "Snake" entry — so a dream about a *snake* never
matches lexically. **Semantic** embeddings (Voyage / OpenAI) close exactly that
gap. The stub is for offline dev; ship on a semantic provider.

---

## Prompt caching (cost lever)

The interpreter **system prompt is frozen** (`src/prompt.mjs`) and carries
`cache_control` (`src/llm.mjs`), so it's a cacheable prefix reused across every
request — while the volatile per‑dream content (the dream + retrieved passages)
sits *after* it and is never cached. At steady traffic this is ~90% off the
system‑prompt tokens.

> Caching only triggers once the stable prefix clears the model minimum
> (~4,096 tokens on Opus 4.8). The current interpreter prompt is shorter than
> that, so grow the stable prefix (house style, few‑shot examples, richer
> framework guidance) to get over the line before relying on cache savings.

---

## Legal & positioning (commercial‑ready)

- **Public domain only.** Every source in `src/sources.mjs` is PD (Project
  Gutenberg). The app quotes these verbatim to users, which is lawful *only*
  for PD works — **do not add copyrighted / in‑print dream books.** The
  downloader enforces provenance (author/title must appear in the file).
- **Reflective, not medical.** The system prompt forbids medical, psychiatric,
  diagnostic, and predictive claims and frames output as journaling insight —
  keeping clear of App Store health‑claim rules and liability.

---

## How it works

| File | Role |
|---|---|
| `src/sources.mjs` | PD book manifest (Gutenberg IDs, provenance, license) |
| `scripts/download.mjs` | fetch raw texts → `data/raw/` (provenance‑checked) |
| `src/gutenberg.mjs` | strip PG boilerplate, normalize paragraphs |
| `src/chunk.mjs` | Miller → one chunk per symbol entry; Freud → paragraph windows |
| `src/embeddings.mjs` | pluggable embeddings (stub sparse TF‑IDF / openai / voyage) |
| `scripts/ingest.mjs` | chunk + embed + compute IDF → `data/index.json` |
| `src/retriever.mjs` | load index, cosine top‑K (handles sparse + dense) |
| `src/prompt.mjs` | frozen interpreter system prompt + output schema |
| `src/llm.mjs` | Claude call (SDK, cached prefix, structured output) + offline stub |
| `src/explain.mjs` | orchestration: embed → retrieve → interpret |
| `src/server.mjs` | `GET /health`, `POST /explain` |

**Vector store:** the index is a JSON file scanned in memory — perfect for a
small, static, shared corpus. At full‑corpus scale on a semantic provider, move
to **pgvector** or **Cloudflare Vectorize**; `retrieve()` ports over unchanged.

**Add a source:** append to `src/sources.mjs` (must be public domain), then
`npm run download && npm run ingest`. Artemidorus' *Oneirocritica* (PD, on
archive.org, not Gutenberg) is a natural next addition.

---

## Roadmap

- **Phase 0 (this):** PD knowledge base + `/explain` RAG API. ✅
- **Phase 1:** Flutter app — record → on‑device transcribe → `/explain` → render
  explanation + quotes; local‑first storage.
- **Phase 2:** journal history, recurring‑symbol insights, "chat with your dreams".
- **Phase 3:** accounts + paywall, deploy the API as a Cloudflare Worker, ship.
