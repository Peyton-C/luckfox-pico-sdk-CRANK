# Build environment for the Luckfox Pico SDK. See docs/BUILDING.md
FROM docker.io/library/ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ssh make gcc gcc-multilib g++-multilib module-assistant expect g++ gawk texinfo \
    libssl-dev bison flex fakeroot cmake unzip gperf autoconf device-tree-compiler \
    libncurses5-dev pkg-config bc python-is-python3 python3 passwd openssl openssh-client \
    vim file cpio rsync wget curl ca-certificates xz-utils bzip2 patch diffutils sudo locales \
    lz4 zstd liblz4-tool u-boot-tools kmod dosfstools mtools e2fsprogs \
 && locale-gen en_US.UTF-8 && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 FORCE_UNSAFE_CONFIGURE=1
WORKDIR /sdk
