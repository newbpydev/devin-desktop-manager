ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN if command -v apt-get >/dev/null 2>&1; then \
      apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        bash bats binutils coreutils curl desktop-file-utils findutils gawk git grep gzip jq libarchive-tools \
        make sed shared-mime-info tar util-linux xdg-utils && \
      rm -rf /var/lib/apt/lists/*; \
    elif command -v dnf >/dev/null 2>&1; then \
      dnf install --assumeyes \
        bash bats binutils bsdtar coreutils curl desktop-file-utils diffutils findutils gawk git grep gzip jq \
        make sed shared-mime-info tar util-linux util-linux-script xdg-utils && \
      dnf clean all; \
    else \
      printf 'Unsupported fixture userland\n' >&2; exit 1; \
    fi
