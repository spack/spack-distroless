FROM docker.io/debian:12.5 as base

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    libc6-dev \
    python3

RUN git clone --depth 1 https://github.com/spack/spack.git

COPY spack.yaml /root/spack-env/spack.yaml

RUN ./spack/bin/spack -e /root/spack-env -k install

FROM docker.io/debian:12.5-slim

RUN rm -rf /bin /sbin

COPY --from=base /spack /spack
COPY --from=base /view /view
COPY --from=base /python-view /python-view

COPY --from=base /usr/lib /usr/lib/
COPY --from=base /bin/sh /bin/sh

ENV SPACK_PYTHON=/python-view/bin/python3
ENV PATH=/view/bin:/spack/bin

RUN spack compiler find

RUN spack bootstrap now
