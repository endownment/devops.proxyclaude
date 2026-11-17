# claude-vpn

A container for working with Claude Code from the console: Java 25 (Temurin), Maven, Gradle,
SDKMAN, git, curl, jq and zsh (oh-my-zsh with autosuggestions and syntax highlighting).
It works on its own, and when needed all of its traffic can be sent through a separate
VPN container.

## Layout

```
claude-vpn/
├── docker-compose.yml                   # main Compose file
├── docker-compose.override.example.yml  # template for the local override (VPN network mode)
├── Dockerfile                           # the image: Java, Maven, Gradle, SDKMAN, zsh (Claude Code is not baked in)
├── start.sh                             # on start: fills the empty SDKMAN folder, installs or updates Claude Code
├── .env                                 # container user UID/GID (tracked by git, no secrets)
├── fill-user-env-with-current-user.sh   # writes the current user's UID/GID to .env
├── .env.local.example                   # template for .env.local (secrets)
├── .gitignore
├── .dockerignore
├── projects/                            # your projects, one subfolder per context (contents not tracked)
└── data/                                # container data (contents not tracked)
    ├── .sdkman/                         # SDKMAN: JDKs, Maven, Gradle
    ├── .m2/                             # Maven dependency cache
    ├── .gradle/                         # Gradle cache
    ├── .zsh_data/                       # zsh command history
    ├── .local/                          # Claude Code binaries and their updates (~/.local in the container)
    ├── .claude/                         # Claude Code login, settings and sessions (~/.claude in the container)
    └── distr/                           # Claude Code archives claude-<version>-linux-x64.zst (/distr, read-only)
```

The empty folders are kept in git with `.gitkeep` files, so no directories have to be created
by hand after cloning.

## Quick start

```
git clone <repository url> claude-vpn
cd claude-vpn
docker compose up -d --build
docker compose exec claude-vpn zsh
```

The first build takes a few minutes. On the first start of the container, SDKMAN is copied from
the image into `data/.sdkman` (visible in `docker compose logs`).

## Claude Code installation and updates

The image does not contain Claude Code. `start.sh` installs it when the container starts:

1. It reads the installed version from `~/.local/bin/claude`.
2. It looks for `claude-<version>-<platform>.zst` archives in `data/distr` (mounted read-only as `/distr`) and picks the newest one.
3. If Claude Code is not installed, it unpacks that archive. If there is no archive, it runs the standard online installer (`https://claude.ai/install.sh`, 15 minute timeout).
4. If Claude Code is installed and the archive is newer, it installs the archive over it. If the installed version is the same or newer, it does nothing.

The archive is unpacked by hand into `~/.local/share/claude/versions/<version>` and `~/.local/bin/claude` is pointed at it. `claude install` is not used: it ignores the local file and downloads the latest build from the network.

### Updating Claude Code offline

1. Download the new `claude-<version>-linux-x64.zst` on the host and put it into `data/distr`.
2. Run `docker compose restart`. The log should say `Installing Claude Code <version> from /distr/...`.

The background auto-updater of Claude Code stays enabled. If it installs a newer version on its own, `start.sh` sees that the installed version is not older than the archive and leaves it alone. If it leaves a broken binary, `claude --version` prints nothing and `start.sh` reinstalls from the archive.

### Rolling back

Older versions stay in `data/.local/share/claude/versions`. The `~/.local/bin/claude` symlink uses an absolute path inside the container, so switch it with `docker exec`:

```sh
docker exec claude-vpn ln -sfn /home/ubuntu/.local/share/claude/versions/<old-version> /home/ubuntu/.local/bin/claude
```

Also remove the newer archive from `data/distr`, otherwise the next container start installs it again.

### Reinstalling from scratch

```sh
find data/.local -mindepth 1 ! -name .gitkeep -delete
docker compose up -d --force-recreate
```

## Two env files

- `.env`: tracked by git, no secrets. Docker Compose reads it automatically and substitutes the
  values into `docker-compose.yml` (image build arguments). It holds `HOST_UID` and `HOST_GID`.
- `.env.local`: not tracked by git, for secrets (the Claude Code token). It is passed into the
  container through `env_file` and is optional.

## UID and GID

The `ubuntu` user inside the container gets `HOST_UID`/`HOST_GID` from `.env`. The committed
values fit the most common setup (the first regular user on the system), so usually there is
nothing to do.

If `id -u` / `id -g` on your machine differ from the values in `.env`:

1. Run `./fill-user-env-with-current-user.sh` (or edit `.env` by hand).
2. Run `docker compose up -d --build`.

The script changes a file that is tracked by git, so `git status` will show `.env` as modified.
To hide that local change: `git update-index --skip-worktree .env`
(if `.env` ever changes in the repository, remove the flag first:
`git update-index --no-skip-worktree .env`).

## Claude Code token

1. `cp .env.local.example .env.local`
2. Inside the container run `claude setup-token` and open the printed link in a browser.
3. Put the token into `.env.local` as `CLAUDE_CODE_OAUTH_TOKEN=...` (use an editor, not echo:
   otherwise the token ends up in the shell history).
4. `docker compose up -d --force-recreate`, then run `claude` inside the container and check `/status`.

Claude Code's own settings and sessions inside the container are not kept when the container is recreated.

## Local override (traffic through the VPN)

Docker Compose merges `docker-compose.override.yml` into `docker-compose.yml` automatically.
That file is not tracked by git: it holds machine-specific settings. The template
`docker-compose.override.example.yml` attaches the container to the network of the VPN container
`awg-vpn` (a separate project, AmneziaWG), which must be running.

1. `cp docker-compose.override.example.yml docker-compose.override.yml`
2. Run `docker compose up -d` (the container is recreated, the data in `projects/` and `data/` is kept).
3. Check: `docker compose config | grep network_mode` shows the merged setting, and
   `curl -s https://ipinfo.io | grep country` inside the container shows the country of the tunnel.

To go back to the normal network, delete `docker-compose.override.yml` and run `docker compose up -d`.
If `awg-vpn` was restarted, run `docker compose restart` in this folder.
While the override is in place, the container does not start unless `awg-vpn` is running.
With `network_mode: container:...` the `ports` and `networks` options cannot be used in this service.

## Java, Maven, Gradle (SDKMAN)

In zsh inside the container:

- `sdk list java | grep tem`, then `sdk install java <identifier>`
- `sdk use java <id>` applies to the current shell; `sdk default java <id>` applies to all new shells
- `.sdkmanrc` in a project folder: `sdk env init`, `sdk env`

Everything is stored in `data/.sdkman` and survives container recreation.

## Updating

`docker compose build --no-cache` and `docker compose up -d` pull fresh Claude Code, Maven and
Gradle. JDKs and caches in `data/` are kept.

## Troubleshooting

- The container exits right away and `docker compose logs` mentions missing write access:
  the owner of `data/` does not match the UID/GID of the container user. Check `.env`
  (see "UID and GID") and rebuild the image, or fix the owner:
  `sudo chown -R "$(id -u):$(id -g)" data`.
- The build fails with "HOST_UID is not set", or Compose warns that a variable is not set:
  `.env` is missing (`git checkout .env` or `./fill-user-env-with-current-user.sh`). Build the image
  with `docker compose`, not with `docker build`.
- An `env_file`/`required` error means Compose is too old: create `.env.local`
  (`cp .env.local.example .env.local`).
- If `docker compose build` complains about buildx, install the buildx plugin.

## Security

- `.env.local` is not tracked by git. Everything in `.env.local` is visible to Claude Code inside the container.
- Keep secrets out of `.env`: it is tracked by git.
- The zsh history and Claude Code sessions are stored as plain text. `data/` and `projects/` are not tracked by git.
