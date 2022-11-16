# syntax=docker/dockerfile:1.4
ARG NODE_VERSION=14
ARG NGINX_VERSION=1.23

FROM "node:${NODE_VERSION}" AS build-env

RUN <<EOF
    apt-get update
    apt-get install -y \
        gosu
    apt-get clean
    rm -rf /var/lib/apt/lists/*

    groupadd -g 2000 user
    useradd -m -o -u 2000 -g user user
EOF

RUN <<EOF
    apt-get update
    apt-get install -y \
        git
    apt-get clean
    rm -rf /var/lib/apt/lists/*
EOF

ARG HARMONICA_WEB_REPO_URL=https://github.com/aoirint/harmonica-web.git
ARG HARMONICA_WEB_VERSION=bc26856347b621208e2ac92bdf230b6c5bb6460f
RUN <<EOF
    mkdir -p /opt/harmonica-web
    chown -R 2000:2000 /opt/harmonica-web

    gosu user git clone -n "${HARMONICA_WEB_REPO_URL}" /opt/harmonica-web
    cd /opt/harmonica-web
    gosu user git checkout "${HARMONICA_WEB_VERSION}"
EOF

WORKDIR /opt/harmonica-web

RUN gosu user npm ci

ARG REACT_APP_API_URL
ARG REACT_APP_SMOKEPING_URL
ARG REACT_APP_SMOKEPING_TARGET

RUN <<EOF
    set -eu

    cat <<EOT > .env
REACT_APP_API_URL=${REACT_APP_API_URL}
REACT_APP_SMOKEPING_URL=${REACT_APP_SMOKEPING_URL}
REACT_APP_SMOKEPING_TARGET=${REACT_APP_SMOKEPING_TARGET}
EOT
    chown user:user .env
EOF
RUN gosu user npm run build


FROM "nginx:${NGINX_VERSION}" AS runtime-env

COPY --from=build-env /opt/harmonica-web/build /opt/harmonica-web-build
ADD ./default.conf.template /etc/nginx/templates/
