# Current latest: ghcr.io/python/wasicontainer:2026.02.20.22245651027
FROM ghcr.io/python/wasicontainer:latest

ENV BINARYEN_HOME=/opt/binaryen
ENV BINARYEN_VERSION=119
ENV BINARYEN_CPU_ARCH=x86_64

RUN mkdir --parents ${BINARYEN_HOME} && \
    curl --location "https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-${BINARYEN_CPU_ARCH}-linux.tar.gz" | \
    tar --strip-components 1 --directory ${BINARYEN_HOME} --extract --gunzip && \
    ln -s ${BINARYEN_HOME}/bin/* /usr/local/bin

# ENV WABT_HOME=/opt/wabt
# ENV WABT_VERSION=1.0.40
# ENV WABT_CPU_ARCH=x64

# RUN mkdir --parents ${WABT_HOME} && \
#     curl --location "https://github.com/WebAssembly/wabt/releases/download/${WABT_VERSION}/wabt-${BINARYEN_VERSION}-linux-${BINARYEN_CPU_ARCH}.tar.gz" | \
#     tar --strip-components 1 --directory ${WABT_HOME} --extract --gunzip && \
#     ln -s ${WABT_HOME}/bin/* /usr/local/bin
