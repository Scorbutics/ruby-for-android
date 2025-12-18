FROM debian:bookworm-slim

ENV ANDROID_NDK_HOME /opt/android-ndk
ENV ANDROID_NDK_VERSION r25b

# get the Android NDK
RUN mkdir /tmp/android-ndk && \
    cd /tmp/android-ndk && \
    apt-get update && \
    apt-get install -y --no-install-recommends wget unzip ca-certificates && \
    wget https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    mv ./android-ndk-${ANDROID_NDK_VERSION} ${ANDROID_NDK_HOME} && \
    cd /tmp && rm -rf /tmp/android-ndk

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    git \
    make \
    cmake \
    ruby \
    ruby-dev \
    linux-libc-dev \
    ninja-build \
    libtool \
    bash \
    gcc \
    g++ \
    libc6-dev \
    autoconf \
    automake \
# ncurses on host is required for cross-compiling ncurses (tic executable must be on the host when cross-compiling)
    ncurses-bin \
    libncurses-dev \
    zip \
    gettext \
# some dependencies might need patches
    patch \
    && rm -rf /var/lib/apt/lists/*

# add NDK to PATH
ENV PATH $PATH:$ANDROID_NDK_HOME
ENV ANDROID_NDK $ANDROID_NDK_HOME

WORKDIR /opt/current
