FROM alpine:3.4
MAINTAINER David Personette <dperson@gmail.com>

# Install samba
RUN apk add --no-cache samba bash && \
    adduser -h /tmp -H -S smbuser && \
    rm -rf /tmp/*
COPY samba.sh /usr/bin/
COPY smb.conf /etc/samba

VOLUME ["/etc/samba"]

EXPOSE 137 139 445

ENTRYPOINT ["samba.sh"]
