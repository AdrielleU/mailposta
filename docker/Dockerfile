# MailPostA (mailposta): sync + tools image, also used by the web UI.
# Bundles the unmodified himalaya release binary (https://github.com/pimalaya/himalaya, MIT or Apache-2.0)
# with its license files in /usr/share/doc/himalaya/; mbsync (isync) and notmuch come from Debian.
FROM docker.io/library/debian:trixie-slim

LABEL org.opencontainers.image.title="MailPostA" \
      org.opencontainers.image.description="AI email helper: local mail copies, drafts only, read-only web UI"

ARG HIMALAYA_VERSION=v2.2.1
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl isync libsasl2-modules-kdexoauth2 notmuch python3 python3-yaml tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH:-amd64}" in \
      amd64) arch=x86_64 ;; \
      arm64) arch=aarch64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/pimalaya/himalaya/releases/download/${HIMALAYA_VERSION}/himalaya.${arch}-linux.tgz" \
    | tar xz -C /usr/local/bin himalaya \
 && mkdir -p /usr/share/doc/himalaya \
 && for f in LICENSE-MIT LICENSE-APACHE; do \
      curl -fsSL "https://raw.githubusercontent.com/pimalaya/himalaya/${HIMALAYA_VERSION}/$f" -o "/usr/share/doc/himalaya/$f"; \
    done \
 && himalaya --version

COPY LICENSE NOTICE /usr/share/doc/mailposta/
COPY config/ /templates/
COPY scripts/ /opt/emailassist/
# Gmail and Outlook icons for the web UI's account cards (served by it; the page loads nothing from outside).
COPY assets/providers/ /usr/share/mailposta/icons/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /opt/emailassist/*

ENV HOME=/root PATH="/opt/emailassist:${PATH}"
ENTRYPOINT ["entrypoint.sh"]
CMD ["sync-loop"]
