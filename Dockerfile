FROM --platform=${BUILDPLATFORM} node:24@sha256:8530f76a96d88820d288761f022e318970dda93d01536919fbc16076b7983e63 AS build

WORKDIR /opt/node_app

COPY . .

# do not ignore optional dependencies:
# Error: Cannot find module @rollup/rollup-linux-x64-gnu
RUN --mount=type=cache,target=/root/.cache/yarn \
    npm_config_target_arch=${TARGETARCH} yarn --frozen-lockfile --network-timeout 600000

ARG NODE_ENV=production

RUN npm_config_target_arch=${TARGETARCH} yarn build:app:docker && yarn build:server

FROM node:24-alpine@sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf

WORKDIR /opt/cutedraw

ENV NODE_ENV=production \
    PORT=8080 \
    STATIC_DIR=/opt/cutedraw/public

COPY --from=build /opt/node_app/excalidraw-app/build ./public
COPY --from=build /opt/node_app/server/dist/server.cjs ./server.cjs

USER node

EXPOSE 8080

HEALTHCHECK CMD wget -q -O /dev/null http://localhost:8080 || exit 1

CMD ["node", "server.cjs"]
