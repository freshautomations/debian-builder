FROM debian:bullseye-slim
ENV VERSION=11.6.0
ENV NAME=custom

RUN apt-get update && apt-get install -y wget xorriso cpio gnupg

COPY --chown=0:0 entrypoint.sh /usr/bin

VOLUME ["/mnt"]

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
