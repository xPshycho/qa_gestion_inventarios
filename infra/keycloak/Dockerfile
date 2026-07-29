FROM quay.io/keycloak/keycloak:26.6.3@sha256:9b0330756022422149aa6502eb2def8cd47c6e1b000c7c65cdb13e7c0133e992

# The realm contract contains environment placeholders, not secret values.
# Runtime values are injected from Secret Manager by Cloud Run.
COPY inventory-realm.json /opt/keycloak/data/import/inventory-realm.json

# Keycloak's published image is prepared for the non-root account with UID 1000.
# Declare it explicitly so the runtime contract and static security scanners agree.
USER 1000
