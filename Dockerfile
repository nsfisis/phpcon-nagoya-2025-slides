FROM amutake/satysfi

RUN opam update && \
    opam install satysfi-base

RUN opam install satysfi-class-slydifi && \
    opam install satysfi-code-printer && \
    opam install satysfi-fonts-noto-sans && \
    opam install satysfi-fonts-noto-sans-cjk-jp

RUN eval $(opam env) && \
    satyrographos install --copy

WORKDIR /work

COPY patches/figbox.satyh.patch /root/.satysfi/dist/packages/figbox/figbox.satyh.patch
RUN cd /root/.satysfi/dist/packages/figbox && \
    patch -p0 < figbox.satyh.patch
