FROM debian:stretch-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gphoto2 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* 

COPY fuji_timelapse.sh /

