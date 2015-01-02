FROM ubuntu:trusty
MAINTAINER David Personette <dperson@dperson.com>

ENV DEBIAN_FRONTEND noninteractive

# Install samba
COPY samba.sh /usr/bin/
RUN apt-get update -qq && \
    apt-get install -qqy --no-install-recommends samba && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/*

VOLUME ["/etc/samba"]

EXPOSE 139 445

ENTRYPOINT ["samba.sh"]
