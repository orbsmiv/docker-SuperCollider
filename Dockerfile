FROM alpine:3.9 AS build
MAINTAINER orbsmiv@hotmail.com

ARG SC_VERSION="Version-3.10.2"
ARG SC_PLUG_VERSION="Version-3.10.0"

RUN apk update && \
    apk --no-cache add \
    build-base \
    jack-dev \
    fftw-dev \
    git \
    libsndfile-dev \
    linux-headers \
    cmake \
    alsa-lib-dev \
    eudev-dev \
    bsd-compat-headers

RUN mkdir /tmp/supercollider-compile \
        && git clone --recursive --depth 1 --branch ${SC_VERSION} \
        git://github.com/supercollider/supercollider \
        /tmp/supercollider-compile

# Alpine uses musl libc (instead of glibc) and doesn't include GLOB_TILDE
RUN sed -i'' "s@GLOB_TILDE@GLOB_ERR@" /tmp/supercollider-compile/common/SC_Filesystem_unix.cpp

RUN sed -i'' "s@__va_copy@va_copy@g" /tmp/supercollider-compile/common/SC_StringBuffer.cpp

RUN mkdir /tmp/supercollider-compile/build

WORKDIR /tmp/supercollider-compile/build

ARG CC=/usr/bin/gcc
ARG CXX=/usr/bin/g++

RUN cmake -L \
            -DCMAKE_BUILD_TYPE="Release" \
            -DBUILD_TESTING=OFF \
            -DENABLE_TESTSUITE=OFF \
            -DSUPERNOVA=OFF \
            -DNATIVE=OFF \
            -DSC_WII=OFF \
            -DSC_IDE=OFF \
            -DSC_QT=OFF \
            -DSC_ED=OFF \
            -DSC_EL=OFF \
            -DINSTALL_HELP=OFF \
            -DSC_VIM=ON \
            -DNO_AVAHI=ON \
            -DNO_X11=ON \
            .. \
        && make -j $(nproc) \
        && make install

RUN mkdir /tmp/supercollider-plugs-compile \
        && git clone --recursive --depth 1 --branch ${SC_PLUG_VERSION} \
        git://github.com/supercollider/sc3-plugins \
        /tmp/supercollider-plugs-compile

RUN mkdir /tmp/supercollider-plugs-compile/build

WORKDIR /tmp/supercollider-plugs-compile/build

RUN cmake -L \
            -DCMAKE_BUILD_TYPE="Release" \
            -DSUPERNOVA=OFF \
            -DNATIVE=OFF \
            -DSC_PATH=/tmp/supercollider-compile/ \
            .. \
        && make -j $(nproc) \
        && make install



FROM alpine:3.9 

RUN apk update && \
    apk --no-cache add \
    jack \
    tini \
    fftw \
    libsndfile \
    eudev

COPY --from=build /usr/local/include/SuperCollider /usr/local/include/SuperCollider
COPY --from=build /usr/local/share/SuperCollider /usr/local/share/SuperCollider
COPY --from=build /usr/local/lib/SuperCollider /usr/local/lib/SuperCollider
COPY --from=build /usr/local/bin/scsynth /usr/local/bin/scsynth
COPY --from=build /usr/local/bin/sclang /usr/local/bin/sclang
COPY --from=build /usr/local/share/pixmaps/supercollider.png /usr/local/share/pixmaps/supercollider.png
COPY --from=build /usr/local/share/pixmaps/supercollider.xpm /usr/local/share/pixmaps/supercollider.xpm
COPY --from=build /usr/local/share/pixmaps/sc_ide.svg /usr/local/share/pixmaps/sc_ide.svg
COPY --from=build /usr/local/share/mime/packages/supercollider.xml /usr/local/share/mime/packages/supercollider.xml

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Env vars for jackd
ENV JACK_NO_AUDIO_RESERVATION=1 \
    JACK_START_SERVER=true \
    SC_JACK_DEFAULT_INPUTS=system \
    SC_JACK_DEFAULT_OUTPUTS=system \
    SC_PLUGIN_PATH=/usr/local/share/SuperCollider/Extensions

# Env vars for scsynth init
ENV CH_OUT=2 \
    CH_IN=2 \
    SC_SYNTH_PORT=57110 \
    SR=48000 \
    SC_BLOCK=128 \
    HW_BUFF=2048 \
    SC_MEM=131072 \
    ALSA_DEV="hw:0"

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

# The following command runs a shell with the scsynth command to ensure that env vars can be interpreted
CMD ["/bin/sh", "-c", "/usr/local/bin/scsynth -u ${SC_SYNTH_PORT} -m ${SC_MEM} -D 0 -R 0 -i ${CH_IN} -o ${CH_OUT} -z ${SC_BLOCK}"]

