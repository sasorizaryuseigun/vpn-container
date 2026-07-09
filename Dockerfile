# SPDX-License-Identifier: AGPL-3.0-only

ARG DEBIAN_VERSION=stable-slim

FROM debian:${DEBIAN_VERSION} AS builder

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  ca-certificates \
  cmake \
  curl \
  gcc \
  git \
  libncurses-dev \
  libreadline-dev \
  libsodium-dev \
  libssl-dev \
  make \
  pax-utils \
  pkg-config \
  tzdata \
  zlib1g-dev \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/*

RUN ln -snf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

WORKDIR /workspace

RUN git clone --depth 1 https://github.com/SoftEtherVPN/SoftEtherVPN.git

WORKDIR /workspace/SoftEtherVPN

RUN git submodule update --init --recursive

ENV CMAKE_FLAGS="-DSE_PIDDIR=/run/softether -DSE_LOGDIR=/var/log/softether -DSE_DBDIR=/var/lib/softether"

WORKDIR /workspace/SoftEtherVPN

RUN curl -L https://raw.githubusercontent.com/sasorizaryuseigun/vpn-patch/main/vpn-patch.patch | git apply -

RUN ./configure \
  && make -C build -j "$(nproc)"

WORKDIR /workspace/SoftEtherVPN/build

RUN make install

WORKDIR /workspace

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN git clone --depth 1 https://github.com/sasorizaryuseigun/rust-exec.git

WORKDIR /workspace/rust-exec

RUN EXEC_TARGET_PATH=/usr/local/libexec/softether/vpnserver/vpnserver \
  ~/.cargo/bin/cargo build --release \
  && rm /usr/local/bin/vpnserver \
  && mv target/release/rust-exec /usr/local/bin/vpnserver \
  && EXEC_TARGET_PATH=/usr/local/libexec/softether/vpncmd/vpncmd \
  ~/.cargo/bin/cargo build --release \
  && rm /usr/local/bin/vpncmd \
  && mv target/release/rust-exec /usr/local/bin/vpncmd

WORKDIR /workspace

RUN curl -fsSLo /usr/local/bin/miroot https://raw.githubusercontent.com/sasorizaryuseigun/miroot/main/miroot \
  && bash -lc '. /usr/local/bin/miroot \
  && mkdir /out \
  && copy_binary_dependencies /usr/local/libexec/softether/vpnserver/vpnserver \
  && copy_binary_dependencies /usr/local/libexec/softether/vpncmd/vpncmd \
  && copy_path_with_symlink_chain /usr/local/libexec/softether/vpnserver/hamcore.se2 \
  && copy_path_with_symlink_chain /usr/local/libexec/softether/vpncmd/hamcore.se2 \
  && copy_path_with_symlink_chain /usr/lib/x86_64-linux-gnu/gconv \
  && copy_package_copyright_for_path /usr/lib/x86_64-linux-gnu/gconv \
  && copy_path_with_symlink_chain /etc/localtime \
  && copy_package_copyright_for_path /etc/localtime \
  && copy_binary_dependencies /usr/local/bin/vpnserver \
  && copy_binary_dependencies /usr/local/bin/vpncmd \
  && create_dir_with_existing_ancestor /run/softether \
  && create_dir_with_existing_ancestor /var/log/softether \
  && create_dir_with_existing_ancestor /var/lib/softether \
  && create_dir_with_existing_ancestor /tmp \
  && cp -a /workspace/SoftEtherVPN/src/bin/hamcore/eula.txt /out/usr/local/libexec/softether/LICENSE.txt \
  && cp -a /workspace/SoftEtherVPN/src/bin/hamcore/legal.txt /out/usr/local/libexec/softether/THIRD_PARTY.txt \
  && printf "%s\\n" \
  "10.0.0.0/8" \
  "127.0.0.0/8" \
  "172.16.0.0/12" \
  "192.168.0.0/16" \
  "::1/128" \
  "fc00::/7" \
  > /out/usr/local/libexec/softether/vpnserver/adminip.txt \
  && chmod 644 /out/usr/local/libexec/softether/vpnserver/adminip.txt'


FROM scratch

COPY --from=builder /out/ /

WORKDIR /usr/local/libexec/softether/vpnserver

ENTRYPOINT ["/usr/local/bin/vpnserver"]

CMD ["execsvc"]

EXPOSE 443
EXPOSE 992
EXPOSE 5555
EXPOSE 8888

LABEL org.opencontainers.image.licenses="AGPL-3.0-only"
