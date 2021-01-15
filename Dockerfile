# syntax=docker/dockerfile:1.2
# Needs BuildKit to enabled to build
# https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md
#
# https://pimylifeup.com/raspberry-pi-plex-media-player/

ARG FFMPEG_CHECKOUT=n4.3.1
ARG MPV_CHECKOUT=v0.33.0
ARG LIBASS_CHECKOUT=0.15.0

FROM debian:buster AS base

FROM base AS git
RUN apt update && apt install -y git

FROM base AS wget
RUN apt update && apt install -y wget

## Clone repos
FROM git AS mpv-build-source
WORKDIR /mpv-build
RUN git clone https://github.com/mpv-player/mpv-build.git .

FROM git AS ffmpeg-source
WORKDIR /ffmpeg
ARG FFMPEG_CHECKOUT
RUN git clone https://github.com/FFmpeg/FFmpeg.git --depth=1 -b $FFMPEG_CHECKOUT .

FROM git AS libass-source
WORKDIR /libass
ARG LIBASS_CHECKOUT
RUN git clone https://github.com/libass/libass.git --depth=1 -b $LIBASS_CHECKOUT .

FROM git AS mpv-source
WORKDIR /mpv
ARG MPV_CHECKOUT
RUN git clone https://github.com/mpv-player/mpv.git --depth=1 -b $MPV_CHECKOUT .

FROM wget AS qt5-source
WORKDIR /qt5
RUN wget https://files.pimylifeup.com/plexmediaplayer/qt5-opengl-dev_5.12.5_armhf.deb

FROM wget AS waf-source
RUN wget https://waf.io/waf-2.0.20
RUN mv waf-* waf && chmod a+rx waf

FROM wget AS raspberrypi-key
WORKDIR /gpg
RUN wget https://archive.raspberrypi.org/debian/raspberrypi.gpg.key

FROM base AS build-base
RUN apt update && apt install -y autoconf make automake build-essential gperf yasm gnutls-dev libv4l-dev libtool libtool-bin libharfbuzz-dev libfreetype6-dev libfontconfig1-dev libx11-dev libcec-dev libxrandr-dev libvdpau-dev libva-dev mesa-common-dev libegl1-mesa-dev yasm libasound2-dev libpulse-dev libbluray-dev libdvdread-dev libcdio-paranoia-dev libsmbclient-dev libcdio-cdda-dev libjpeg-dev libluajit-5.1-dev libuchardet-dev zlib1g-dev libfribidi-dev git libgnutls28-dev libgl1-mesa-dev libgles2-mesa-dev libsdl2-dev cmake python3 python python-minimal git mpv libmpv-dev
RUN apt update && apt install -y ccache

# Enable ccache
ENV PATH="/usr/lib/ccache:${PATH}"
ENV CCACHE_DIR="/ccache"

## Build mpv
FROM build-base AS mpv-build-base
WORKDIR /build
COPY --from=mpv-build-source /mpv-build .
COPY --from=ffmpeg-source /ffmpeg ./ffmpeg
COPY --from=libass-source /libass ./libass
COPY --from=mpv-source /mpv ./mpv
COPY --from=waf-source /waf ./mpv/waf

ENV LC_ALL=C
ARG FFMPEG_CHECKOUT
ARG MPV_CHECKOUT
ARG LIBASS_CHECKOUT
RUN set -x \
    && echo --enable-libmpv-shared >> mpv_options \
    && echo --disable-cplayer >> mpv_options \
    && scripts/switch-branch libass @$LIBASS_CHECKOUT \
    && scripts/switch-branch mpv @$MPV_CHECKOUT \
    && scripts/switch-branch ffmpeg @$FFMPEG_CHECKOUT \
    && exit 0

# libass
FROM mpv-build-base AS libass-build
RUN --mount=type=cache,id=libass-build,target=/ccache \
    scripts/libass-config --cache-file=/ccache/libass.config
RUN --mount=type=cache,id=libass-build,target=/ccache \
    scripts/libass-build -j$(nproc)
RUN --mount=type=cache,id=libass-build,target=/ccache \
    ccache -s > ccache.txt && cp /ccache/libass.config .

# ffmpeg
FROM mpv-build-base AS ffmpeg-build
COPY --from=libass-build /build/build_libs/ /build/build_libs/
RUN scripts/ffmpeg-config
RUN --mount=type=cache,id=ffmpeg-build,target=/ccache \
    scripts/ffmpeg-build -j$(nproc)
RUN --mount=type=cache,id=ffmpeg-build,target=/ccache \
    ccache -s > ccache.txt

# mpv
FROM mpv-build-base AS mpv-build
COPY --from=ffmpeg-build /build/build_libs/ /build/build_libs/
RUN ln -sf python3 /usr/bin/python
RUN scripts/mpv-config
RUN --mount=type=cache,id=mpv-build,target=/ccache \
    scripts/mpv-build -j$(nproc)
RUN --mount=type=cache,id=mpv-build,target=/ccache \
    ccache -s > ccache.txt

RUN rm -rf /usr/local/include /usr/local/lib && ./install

## Build qt
FROM build-base AS qt-build
RUN apt update && apt install -y gnupg
COPY --from=raspberrypi-key /gpg/raspberrypi.gpg.key /
RUN apt-key add /raspberrypi.gpg.key
RUN echo "deb http://archive.raspberrypi.org/debian/ buster main" > /etc/apt/sources.list.d/raspberrypi.list && apt update
COPY --from=qt5-source /qt5 /
RUN apt-get install -y ./qt5-opengl-dev_5.12.5_armhf.deb
