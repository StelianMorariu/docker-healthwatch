# docker-healthwatch

Listens to Docker containers `health_status` events and posts a Markdown message to a Discord webhook with container name, image, status, local-TZ timestamp, and an **Environment** line so multiple hosts can share a channel without confusion.

---

## How it works

- Subscribes to `docker events --filter event=health_status`.
- Extracts `name`, `image`, and `health` from each event.
- Optional regex filters include/exclude containers.
- Formats a Discord message with real line breaks and emojis.
- Timestamps use the watcher container’s `TZ` (alpine/musl compatible).
- Sends to `DISCORD_WEBHOOK_URL`.

**Example message**
```
🟥 Container Unhealthy
Environment: homelab
Container: fake-app
Image: busybox:1.36
Status: unhealthy
Time: 22:25:14 01/10/2025 BST
```
---

## Requirements

- Mount Docker socket read-only: `/var/run/docker.sock:/var/run/docker.sock:ro`.
- A Discord **channel webhook URL**.
- Target containers should define a Docker **HEALTHCHECK**.

---

## Quick start

### Docker (single host)
```bash
docker run -d --name docker-healthwatch --restart unless-stopped \
  -e DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."\
  -e TZ="Europe/London" \
  -e ALERT_TAG="homelab" \
  -e WATCH_INCLUDE= \
  -e WATCH_EXCLUDE= \
  -e NOTIFY_HEALTHY=true \
  -e EMOJI_HEALTHY=✅ -e EMOJI_UNHEALTHY=🚨 -e EMOJI_STARTING=⏳ -e EMOJI_UNKNOWN=❔ \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  ghcr.io/<your-gh-user>/docker-healthwatch:<tag>
# or: <dockerhub-user>/docker-healthwatch:<tag>
```

PS: emoji parameters are optional

### Portainer (stack snippet)
```yaml
services:
  docker-healthwatch:
    image: ghcr.io/<your-gh-user>/docker-healthwatch:<tag>
    restart: unless-stopped
    environment:
      - DISCORD_WEBHOOK_URL=${DISCORD_WEBHOOK_URL}
      - TZ=Europe/London
      - ALERT_TAG=homelab
      - WATCH_INCLUDE=
      - WATCH_EXCLUDE=
      - NOTIFY_HEALTHY=true
      - EMOJI_HEALTHY=✅
      - EMOJI_UNHEALTHY=🚨
      - EMOJI_STARTING=⏳
      - EMOJI_UNKNOWN=❔
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

In Portainer, set `DISCORD_WEBHOOK_URL` in the Variables panel.

### Build locally 
```bash
docker build -t ghcr.io/<your-gh-user>/docker-healthwatch:dev .
docker run --rm -e DISCORD_WEBHOOK_URL=... -e TZ=Europe/London \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  ghcr.io/<your-gh-user>/docker-healthwatch:dev
```



### Configuration (environment variables)

| Variable              | Required | Default                 | Description                                                             |
| --------------------- | :------: | ----------------------- | ----------------------------------------------------------------------- |
| `DISCORD_WEBHOOK_URL` |  **Yes** | —                       | Discord webhook to post alerts. Treat as secret.                        |
| `TZ`                  |    No    | Image default           | Time zone (e.g., `Europe/London`). Controls timestamp.                  |
| `ALERT_TAG`           |    No    | Docker daemon/host name | Shown as **Environment** to identify the sender.                        |
| `WATCH_INCLUDE`       |    No    | *(empty)*               | Regex; only matching container names are included. Empty = include all. |
| `WATCH_EXCLUDE`       |    No    | *(empty)*               | Regex; matching container names are excluded.                           |
| `NOTIFY_HEALTHY`      |    No    | `true`                  | If `false`, only send alerts when containers are **unhealthy**.         |
| `EMOJI_HEALTHY`       |    No    | ✅                      | Emoji for healthy recoveries.                                           |
| `EMOJI_UNHEALTHY`     |    No    | 🚨                      | Emoji for unhealthy events.                                             |
| `EMOJI_STARTING`      |    No    | ⏳                      | Emoji for `starting`.                                                   |
| `EMOJI_UNKNOWN`       |    No    | ❔                     | Emoji for other/unknown.                                                |


Timestamp format: `"%H:%M:%S %d/%m/%Y %Z"` (uses the watcher container’s `TZ`).

### Testing with the bundled fake-app
If you also deploy a simple test container:

Make it **UNHEALTHY**:

```bash
sudo docker exec fake-app sh -c 'rm -f /tmp/healthy'
```

Make it **HEALTHY** again:

```bash
sudo docker exec fake-app sh -c 'touch /tmp/healthy'
```

Expected: Discord receives alerts for both transitions, with your Environment tag and local-TZ timestamp.

## Logs & troubleshooting
```bash
docker logs -f docker-healthwatch
```

#### No alerts? 
 - Check `DISCORD_WEBHOOK_URL`, 
 - ensure targets have a HEALTHCHECK, 
 - set WATCH_INCLUDE= empty while testing.

#### Wrong time? 
- Set TZ (e.g., Europe/London). 

Image includes tzdata and initializes musl’s TZ correctly.



## Security
Treat `DISCORD_WEBHOOK_URL` as a secret. Anyone with it can post to your channel.






