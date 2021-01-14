# https://pimylifeup.com/raspberry-pi-plex-media-player/

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
RUN git clone https://github.com/FFmpeg/FFmpeg.git .

FROM git AS libass-source
WORKDIR /libass
RUN git clone https://github.com/libass/libass.git .

FROM git AS mpv-source
WORKDIR /mpv
RUN git clone https://github.com/mpv-player/mpv.git .

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
RUN set -x \
    && echo --enable-libmpv-shared >> mpv_options \
    && echo --disable-cplayer >> mpv_options \
    && ./use-mpv-release \
    && ./use-ffmpeg-release \
    && exit 0

# libass
FROM mpv-build-base AS libass-build
RUN --mount=type=cache,id=libass-build,target=/ccache \
    scripts/libass-config \
        --cache-file=/ccache/libass.config \
    && scripts/libass-build -j$(nproc)

RUN --mount=type=cache,id=libass-build,target=/ccache \
    ccache -s > ccache.txt && cp /ccache/libass.config .

# ffmpeg
FROM mpv-build-base AS ffmpeg-build
COPY --from=libass-build /build/build_libs/ /build/build_libs/
RUN --mount=type=cache,id=ffmpeg-build,target=/ccache \
    scripts/ffmpeg-config && scripts/ffmpeg-build -j$(nproc)

RUN --mount=type=cache,id=ffmpeg-build,target=/ccache \
    ccache -s > ccache.txt

# mpv
FROM mpv-build-base AS mpv-build
COPY --from=ffmpeg-build /build/build_libs/ /build/build_libs/
RUN \
    --mount=type=cache,id=mpv-build,target=/ccache \
    scripts/mpv-config && scripts/mpv-build -j$(nproc)

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
