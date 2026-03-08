FROM ghcr.io/spiffe/spire-server:1.8.0

# SPIRE server image is distroless, so we can't run shell commands like mkdir.
# We will rely on volume mounts for the config and data directories.

ENTRYPOINT ["/opt/spire/bin/spire-server", "run", "-config", "/run/spire/config/server.conf"]
