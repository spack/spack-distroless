FROM docker.io/debian:12.11 AS bootstrap

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    git \
    libc6-dev \
    python3

RUN git clone -c feature.manyFiles=true --depth=2 https://github.com/spack/spack.git /spack

ENV PATH="${PATH}:/spack/bin"

COPY spack.yaml /root/spack-env/spack.yaml

RUN spack compiler find
RUN sed -i '/spec: gcc/s/$/ build_type=Release/' /root/.spack/packages.yaml

RUN spack -e /root/spack-env concretize
RUN spack -e /root/spack-env fetch -D
RUN spack -e /root/spack-env install --fail-fast --fresh
RUN spack view add -i /bootstrap-view $(spack find -H)


FROM docker.io/debian:12.11 AS base

RUN apt-get update && apt-get install -y \
    libc6-dev

COPY --from=bootstrap /spack /spack
COPY --from=bootstrap /bootstrap-view /bootstrap-view

ENV PATH="/bootstrap-view/bin:/spack/bin:${PATH}"

COPY spack.yaml /root/spack-env/spack.yaml

RUN spack compiler find /bootstrap-view/bin

RUN spack -e /root/spack-env concretize -Uf
RUN spack -e /root/spack-env install --fail-fast --fresh
RUN spack clean -ab
RUN spack gc -e /root/spack-env -y


FROM scratch

COPY --from=base /spack /spack
COPY --from=base /view /usr
COPY --from=base /python-view /python-view

ENV SPACK_PYTHON=/python-view/bin/python3
ENV PATH=/usr/bin:/spack/bin

SHELL ["/usr/bin/bash", "-c"]

RUN ln -s /usr/bin /bin

RUN spack compiler find
RUN spack bootstrap now

ENTRYPOINT ["/usr/bin/bash", "-l", "-c"]
