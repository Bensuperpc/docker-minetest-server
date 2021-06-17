ARG DOCKER_IMAGE=alpine:3.13
FROM $DOCKER_IMAGE AS builder

LABEL author="Bensuperpc <bensuperpc@gmail.com>"
LABEL mantainer="Bensuperpc <bensuperpc@gmail.com>"

ARG VERSION="1.0.0"
ENV VERSION=$VERSION

ARG MINETEST_VERSION=master
ENV MINETEST_VERSION=$MINETEST_VERSION 

ARG MINETEST_GAME_VERSION=master
ENV MINETEST_GAME_VERSION=$MINETEST_GAME_VERSION 

ARG IRRLICHT_VERSION=master
ENV IRRLICHT_VERSION=$IRRLICHT_VERSION

WORKDIR /usr/src/minetest

RUN apk add --no-cache git build-base cmake sqlite-dev curl-dev zlib-dev \
		gmp-dev jsoncpp-dev postgresql-dev ninja luajit-dev ca-certificates ccache

RUN git clone --recurse-submodules --remote-submodules -b ${MINETEST_VERSION} \
	https://github.com/minetest/minetest.git /usr/src/minetest

RUN	git clone --recurse-submodules --remote-submodules -b ${MINETEST_GAME_VERSION} https://github.com/minetest/minetest_game.git \
	./games/minetest_game && rm -fr ./games/minetest_game/.git

WORKDIR /usr/src/
RUN git clone --recurse-submodules --remote-submodules https://github.com/jupp0r/prometheus-cpp/ && \
	mkdir prometheus-cpp/build && \
	cd prometheus-cpp/build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_TESTING=0 \
		-DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
		-DCMAKE_C_COMPILER_LAUNCHER="ccache" \
		-GNinja && \
	ninja && \
	ninja install

RUN git clone --recurse-submodules --remote-submodules https://github.com/minetest/irrlicht/ -b ${IRRLICHT_VERSION} && \
	cp -r irrlicht/include /usr/include/irrlichtmt

WORKDIR /usr/src/minetest
RUN rm -rf build && mkdir -p build && \
	cd build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SERVER=TRUE \
		-DENABLE_PROMETHEUS=TRUE \
		-DBUILD_UNITTESTS=FALSE \
		-DBUILD_CLIENT=FALSE \
		-DCMAKE_CXX_COMPILER_LAUNCHER="ccache" \
		-DCMAKE_C_COMPILER_LAUNCHER="ccache" \
		-GNinja && \
	ninja && \
	ninja install

ARG DOCKER_IMAGE=alpine:3.13
FROM $DOCKER_IMAGE AS runtime

RUN apk add --no-cache sqlite-libs curl gmp libstdc++ libgcc libpq luajit jsoncpp && \
	adduser -D minetest --uid 30000 -h /var/lib/minetest && \
	chown -R minetest:minetest /var/lib/minetest

WORKDIR /var/lib/minetest

COPY --from=builder /usr/local/share/minetest /usr/local/share/minetest
COPY --from=builder /usr/local/bin/minetestserver /usr/local/bin/minetestserver
COPY --from=builder /usr/local/share/doc/minetest/minetest.conf.example /etc/minetest/minetest.conf

ENV PATH="/usr/local/bin:${PATH}"
RUN minetestserver --version

USER minetest:minetest

EXPOSE 30000/udp 30000/tcp

LABEL org.label-schema.schema-version="1.0" \
   org.label-schema.build-date=$BUILD_DATE \
   org.label-schema.name="bensuperpc/minetest-server" \
   org.label-schema.description="minetest server in docker" \
   org.label-schema.version=$VERSION \
   org.label-schema.vendor="Bensuperpc" \
   org.label-schema.url="http://bensuperpc.com/" \
   org.label-schema.vcs-url="https://github.com/Bensuperpc/docker-minetest" \
   org.label-schema.vcs-ref=$VCS_REF \
   org.label-schema.docker.cmd="docker build -t bensuperpc/minetest-server -f Dockerfile ."

CMD ["minetestserver", "--config", "/etc/minetest/minetest.conf"]
