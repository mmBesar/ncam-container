# ncam-container

Multi-arch Docker container for **NCam** — the actively maintained OSCam/EMU fork by [fairbird](https://github.com/fairbird/NCam).

Compiled from source on every upstream commit. Images published to GitHub Container Registry.

| Architecture | Runner |
|---|---|
| `linux/amd64` | GitHub-hosted `ubuntu-24.04` |
| `linux/arm64` | GitHub-hosted `ubuntu-24.04-arm` (native, no QEMU) |
| `linux/riscv64` | RISE RISC-V Runner `ubuntu-24.04-riscv` (native, no QEMU) |

---

## Pull

```bash
docker pull ghcr.io/mmbesar/ncam-container:latest
```

---

## Usage

### docker run

```bash
docker run -d \
  --name ncam \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Africa/Cairo \
  -p 8888:8888 \
  -v /your/config/path:/etc/ncam \
  --restart unless-stopped \
  ghcr.io/mmbesar/ncam-container:latest
```

### docker-compose

```yaml
services:
  ncam:
    image: ghcr.io/mmbesar/ncam-container:latest
    container_name: ncam
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Africa/Cairo
    ports:
      - 8888:8888
    volumes:
      - ./config:/etc/ncam
    restart: unless-stopped
```

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PUID` | `2000` | UID to run NCam as |
| `PGID` | `2000` | GID to run NCam as |
| `TZ` | `UTC` | Timezone (e.g. `Africa/Cairo`, `Europe/Berlin`) |

---

## Config Directory

Mount your NCam config files to `/etc/ncam`:

```
/etc/ncam/
├── ncam.conf       ← main config
├── ncam.server     ← reader/server definitions
├── ncam.user       ← user accounts
└── SoftCam.Key     ← EMU key file
```

The web interface is available at `http://<host>:8888`.

---

## How it works

- **`upstream` branch** — mirrors `fairbird/NCam:master` exactly (`.github/` stripped). Updated automatically every 6 hours by the sync workflow.
- **`main` branch** — contains `Dockerfile`, `entrypoint.sh`, workflows, and `built-tags.txt`.
- Images are built from the `upstream` branch source and tagged by the upstream commit SHA short hash + `latest`.

---

## Connecting to TVHeadend

NCam communicates with TVHeadend via **CAPMT Linux Network DVBAPI**:

1. In NCam (`ncam.conf`), enable the DVBAPI module and set `boxtype = pc`.
2. In TVHeadend → Configuration → CAs → add a new CA pointing to NCam's DVBAPI port (default `9000`).

---

## License

NCam is licensed under GPL-2.0. This container repo is also GPL-2.0.
