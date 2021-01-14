# https://pimylifeup.com/raspberry-pi-plex-media-player/

FROM debian:buster AS base

FROM base AS git
RUN apt update && apt install -y git

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

## Build mpv
FROM base AS mpv-build
RUN apt update && apt install -y autoconf make automake build-essential gperf yasm gnutls-dev libv4l-dev libtool libtool-bin libharfbuzz-dev libfreetype6-dev libfontconfig1-dev libx11-dev libcec-dev libxrandr-dev libvdpau-dev libva-dev mesa-common-dev libegl1-mesa-dev yasm libasound2-dev libpulse-dev libbluray-dev libdvdread-dev libcdio-paranoia-dev libsmbclient-dev libcdio-cdda-dev libjpeg-dev libluajit-5.1-dev libuchardet-dev zlib1g-dev libfribidi-dev git libgnutls28-dev libgl1-mesa-dev libgles2-mesa-dev libsdl2-dev cmake python3 python python-minimal git mpv libmpv-dev
WORKDIR /build
COPY --from=mpv-build-source /mpv-build .
COPY --from=ffmpeg-source /ffmpeg ./ffmpeg
COPY --from=libass-source /libass ./libass
COPY --from=mpv-source /mpv ./mpv

RUN echo --enable-libmpv-shared >> mpv_options
RUN echo --disable-cplayer >> mpv_options
RUN ./use-mpv-release
RUN ./use-ffmpeg-release
RUN ./rebuild -j$(nproc)
RUN rm -rf /usr/local/include /usr/local/lib
RUN ./install

## Build qt
FROM base AS qt-build
RUN apt update && apt install -y wget
RUN wget https://files.pimylifeup.com/plexmediaplayer/qt5-opengl-dev_5.12.5_armhf.deb
RUN apt-get install -y ./qt5-opengl-dev_5.12.5_armhf.deb
