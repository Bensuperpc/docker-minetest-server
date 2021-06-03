# Original version: https://github.com/minetest/minetest

ARG DOCKER_IMAGE=alpine:latest
FROM $DOCKER_IMAGE AS builder

ENV MINETEST_GAME_VERSION master
ENV IRRLICHT_VERSION master

LABEL author="Bensuperpc <bensuperpc@gmail.com>"
LABEL mantainer="Bensuperpc <bensuperpc@gmail.com>"

WORKDIR /usr/src/minetest

RUN apk add --no-cache git build-base cmake sqlite-dev curl-dev zlib-dev \
		gmp-dev jsoncpp-dev postgresql-dev ninja luajit-dev ca-certificates && \
	git clone --depth=1 -b ${MINETEST_GAME_VERSION} https://github.com/minetest/minetest_game.git ./games/minetest_game && \
	rm -fr ./games/minetest_game/.git


WORKDIR /tmp/
RUN git clone --recursive https://github.com/minetest/minetest.git \
	&& cd minetest \
	&& cp -a .git /usr/src/minetest/.git \
	&& cp -a CMakeLists.txt /usr/src/minetest/CMakeLists.txt \
	&& cp -a README.md /usr/src/minetest/README.md \
	&& cp -a minetest.conf.example /usr/src/minetest/minetest.conf.example \
	&& cp -a builtin /usr/src/minetest/builtin \
	&& cp -a cmake /usr/src/minetest/cmake \
	&& cp -a doc /usr/src/minetest/doc \
	&& cp -a fonts /usr/src/minetest/fonts \
	&& cp -a lib /usr/src/minetest/lib \
	&& cp -a misc /usr/src/minetest/misc \
	&& cp -a po /usr/src/minetest/po \
	&& cp -a src /usr/src/minetest/src \
    && textures /usr/src/minetest/textures \
	&& cd .. && rm -rf /tmp/minetest


WORKDIR /usr/src/
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp/ && \
	mkdir prometheus-cpp/build && \
	cd prometheus-cpp/build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_BUILD_TYPE=Release \
		-DENABLE_TESTING=0 \
		-GNinja && \
	ninja && \
	ninja install

RUN git clone --depth=1 https://github.com/minetest/irrlicht/ -b ${IRRLICHT_VERSION} && \
	cp -r irrlicht/include /usr/include/irrlichtmt

WORKDIR /usr/src/minetest
RUN mkdir build && \
	cd build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SERVER=TRUE \
		-DENABLE_PROMETHEUS=TRUE \
		-DBUILD_UNITTESTS=FALSE \
		-DBUILD_CLIENT=FALSE \
		-GNinja && \
	ninja && \
	ninja install

ARG DOCKER_IMAGE=alpine:latest
FROM $DOCKER_IMAGE AS runtime

RUN apk add --no-cache sqlite-libs curl gmp libstdc++ libgcc libpq luajit jsoncpp && \
	adduser -D minetest --uid 30000 -h /var/lib/minetest && \
	chown -R minetest:minetest /var/lib/minetest

WORKDIR /var/lib/minetest

COPY --from=builder /usr/local/share/minetest /usr/local/share/minetest
COPY --from=builder /usr/local/bin/minetestserver /usr/local/bin/minetestserver
COPY --from=builder /usr/local/share/doc/minetest/minetest.conf.example /etc/minetest/minetest.conf

USER minetest:minetest

EXPOSE 30000/udp 30000/tcp

LABEL org.label-schema.schema-version="1.0" \
	  org.label-schema.build-date=$BUILD_DATE \
	  org.label-schema.name="bensuperpc/minetest-server" \
	  org.label-schema.description="minetest-server in docker" \
	  org.label-schema.version=$VERSION \
	  org.label-schema.vendor="Bensuperpc" \
	  org.label-schema.url="http://bensuperpc.com/" \
	  org.label-schema.vcs-url="https://github.com/Bensuperpc/docker-minetest-server" \
	  org.label-schema.vcs-ref=$VCS_REF \
	  org.label-schema.docker.cmd="docker build -tbensuperpc/minetest-server -f Dockerfile ."

CMD ["/usr/local/bin/minetestserver", "--config", "/etc/minetest/minetest.conf"]
