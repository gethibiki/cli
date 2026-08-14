# hibiki CLI — installer and releases

Drive **[Hibiki](https://www.gethibiki.com)**'s brand and content agent from a
terminal: draft posts, plan content, run analyses, see what the agent is working
on.

```bash
curl -fsSL https://cli.gethibiki.com | sh
```

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

Releases are tagged `v<version>` and carry four assets plus `SHA256SUMS`:

```
hibiki-linux-x64  hibiki-linux-arm64  hibiki-darwin-x64  hibiki-darwin-arm64
```

## Licence

MIT.
