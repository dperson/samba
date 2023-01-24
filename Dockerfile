FROM debian:11-slim
LABEL org.opencontainers.image.authors="Joe Block <jpb@unixorn.net>"
LABEL description="Samba on debian bullseye-slim"

EXPOSE 137/udp 138/udp
EXPOSE 139 445

RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y apt-utils ca-certificates tzdata tini \
      --no-install-recommends && \
		update-ca-certificates && \
    apt-get install -y --no-install-recommends samba smbclient samba-vfs-modules && \
		rm -fr /tmp/* /var/lib/apt/lists/*

RUN addgroup smb && adduser --home /tmp \
      --shell /sbin/nologin \
      --ingroup smb \
      --disabled-login --disabled-password \
      --gecos 'Samba User' smbuser

COPY configurator samba.sh /usr/bin/
RUN /usr/bin/configurator

HEALTHCHECK --interval=60s --timeout=15s \
            CMD smbclient -L \\localhost -U % -m SMB3

VOLUME ["/etc", \
  "/var/cache/samba", \
  "/var/lib/samba", \
  "/var/log/samba", \
  "/run/samba"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/samba.sh"]
