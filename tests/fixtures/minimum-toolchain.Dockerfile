ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG BASH_VERSION=4.4
ARG BASH_SHA256=d86b3392c1202e8ff5a423b302e6284db7f8f435ea9f39b5b1b20fd3ac36dfcb
ARG MAKE_VERSION=4.3
ARG MAKE_SHA256=e05fdde47c5f7ca45cb697e973894ff4f5d79e13b750ed57d7b66d8defc78e19

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
      bats build-essential ca-certificates coreutils curl desktop-file-utils findutils gawk git grep \
      gzip jq libarchive-tools sed shared-mime-info tar util-linux xdg-utils && \
    curl --fail --location --silent --show-error \
      "https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz" -o /tmp/bash.tar.gz && \
    printf '%s  %s\n' "${BASH_SHA256}" /tmp/bash.tar.gz | sha256sum --check --strict && \
    curl --fail --location --silent --show-error \
      "https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz" -o /tmp/make.tar.gz && \
    printf '%s  %s\n' "${MAKE_SHA256}" /tmp/make.tar.gz | sha256sum --check --strict && \
    mkdir /tmp/bash-src /tmp/make-src && \
    tar -xzf /tmp/bash.tar.gz --strip-components=1 -C /tmp/bash-src && \
    tar -xzf /tmp/make.tar.gz --strip-components=1 -C /tmp/make-src && \
    cd /tmp/bash-src && ./configure --prefix=/opt/minimum && make -j2 && make install && \
    cd /tmp/make-src && ./configure --prefix=/opt/minimum && make -j2 && make install && \
    /opt/minimum/bin/bash --version | grep -F 'version 4.4' && \
    /opt/minimum/bin/make --version | grep -F 'GNU Make 4.3' && \
    rm -rf /tmp/bash-src /tmp/make-src /tmp/bash.tar.gz /tmp/make.tar.gz /var/lib/apt/lists/*

ENV PATH=/opt/minimum/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
