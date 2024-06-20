FROM docker.io/debian:12.5 as bootstrap

RUN apt-get update && apt-get install -y \
    build-essential \
    ca-certificates \
    git \
    libc6-dev \
    python3

RUN git clone -c feature.manyFiles=true https://github.com/spack/spack.git

ENV PATH="${PATH}:/spack/bin"

COPY spack.yaml /root/spack-env/spack.yaml

RUN spack -e /root/spack-env concretize
RUN spack -e /root/spack-env fetch -D
RUN spack -e /root/spack-env install --fail-fast
RUN spack view add -i /bootstrap-view $(spack find -H)

FROM docker.io/debian:12.5 as base

RUN apt-get update && apt-get install -y \
    libc6-dev

COPY --from=bootstrap /spack /spack
COPY --from=bootstrap /bootstrap-view /bootstrap-view

ENV PATH="/bootstrap-view/bin:/spack/bin:${PATH}"

COPY spack.yaml /root/spack-env/spack.yaml

RUN spack compiler find /bootstrap-view/bin

RUN spack -e /root/spack-env concretize -Uf
RUN spack -e /root/spack-env install --fail-fast
RUN spack clean -a
RUN spack gc -e /root/spack-env -y -b

FROM docker.io/debian:12.5-slim

RUN rm -rf /usr/bin /usr/sbin

COPY --from=base /spack /spack
COPY --from=base /view /view
COPY --from=base /python-view /python-view

COPY --from=base /usr/lib /usr/lib/
COPY --from=base /usr/bin/sh /usr/bin/sh
COPY --from=base /usr/bin/env /usr/bin/env

ENV SPACK_PYTHON=/python-view/bin/python3
ENV PATH=/view/bin:/spack/bin:/bin

RUN spack compiler find

RUN spack bootstrap now

ENTRYPOINT ["/bin/sh"]
