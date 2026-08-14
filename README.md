# hibiki CLI — installer and releases

Drive **[Hibiki](https://www.gethibiki.com)**'s brand and content agent from a
terminal: draft posts, plan content, run analyses, see what the agent is working
on.

```bash
curl -fsSL https://raw.githubusercontent.com/gethibiki/cli/main/install.sh | sh
```

> **`https://cli.gethibiki.com` is the intended address** and every example
> below uses it. It starts answering the moment the Worker in
> `infra/cli-installer/` is first deployed — the route creates the hostname —
> and until then the raw URL above is the same script from the same branch.
> See [#1](https://github.com/gethibiki/cli/issues/1).

```bash
hibiki login              # paste an API key from Settings → API Keys
hibiki brand use <id>     # pin a brand to this directory, in .hibiki.json
hibiki draft "the release notes for 2.1, as a LinkedIn post"
```

The binaries are single files with no dependencies — no Node, no npm. Linux and
macOS, x64 and arm64. Installs to `/usr/local/bin` by default:

```bash
curl -fsSL https://cli.gethibiki.com | sh -s -- --dir ~/.local/bin
curl -fsSL https://cli.gethibiki.com | sh -s -- --version v0.1.0
```

Every release publishes `SHA256SUMS`, and the installer verifies the download
against it before installing. A mismatch is a hard failure.

## Using it from a coding agent

There is a skill for that — Claude Code, pi, Codex and the rest:

```bash
npx skills add gethibiki/skill
```

It teaches an agent both of Hibiki's lanes and, importantly, that the agent
judges while the CLI transports. See [gethibiki/skill](https://github.com/gethibiki/skill).

## What is in this repository

This repo is **distribution only** — the CLI's source lives with the rest of
Hibiki, and CI publishes built binaries here.

| Path                       |                                                                      |
| -------------------------- | -------------------------------------------------------------------- |
| `install.sh`               | The installer. Detects platform, resolves the latest release, verifies the checksum, installs. |
| `infra/cli-installer/`     | The Cloudflare Worker serving `cli.gethibiki.com`, which proxies `install.sh` from this repo's main branch. |

### Deploying the Worker

Once, so `cli.gethibiki.com` starts answering. Either from a terminal:

```bash
cd infra/cli-installer
npx wrangler@latest login
npx wrangler@latest deploy
```

…or by setting the `CLOUDFLARE_API_TOKEN` repository secret — scoped to the
`gethibiki.com` zone with **Workers Scripts: Edit** and **Account Workers
Routes: Edit** — and running the *Deploy CLI installer Worker* workflow. After
that it redeploys on any push to `main` touching the Worker or `install.sh`, and
smoke-tests the live URL afterwards.

Releases are tagged `v<version>` and carry four assets plus `SHA256SUMS`:

```
hibiki-linux-x64  hibiki-linux-arm64  hibiki-darwin-x64  hibiki-darwin-arm64
```

## Licence

MIT.
