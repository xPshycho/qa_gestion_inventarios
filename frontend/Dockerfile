FROM node:22-alpine@sha256:16e22a550f3863206a3f701448c45f7912c6896a62de43add43bb9c86130c3e2 AS build

WORKDIR /app

ARG PNPM_VERSION=10.12.1

RUN npm config set fetch-retries 5 \
    && npm config set fetch-retry-factor 2 \
    && npm config set fetch-retry-mintimeout 10000 \
    && npm config set fetch-retry-maxtimeout 60000 \
    && npm install -g "pnpm@${PNPM_VERSION}" --ignore-scripts

COPY package.json pnpm-lock.yaml .npmrc ./
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY angular.json tsconfig.json tsconfig.app.json ./
COPY public ./public
COPY src ./src
RUN pnpm build

FROM nginx:1.29-alpine@sha256:5616878291a2eed594aee8db4dade5878cf7edcb475e59193904b198d9b830de

RUN apk upgrade --no-cache

COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY security-headers.conf.template /etc/nginx/templates/security-headers.conf.template
COPY silent-sso-headers.conf.template /etc/nginx/templates/silent-sso-headers.conf.template
COPY docker-entrypoint.sh /usr/local/bin/inventory-frontend-entrypoint
COPY --from=build /app/dist/qa-gestion-inventarios-frontend/browser /usr/share/nginx/html

RUN chmod +x /usr/local/bin/inventory-frontend-entrypoint \
    && chown -R nginx:nginx /etc/nginx/conf.d /run /var/cache/nginx /var/run /var/log/nginx /usr/share/nginx/html

USER nginx

EXPOSE 8080

ENTRYPOINT []
CMD ["/usr/local/bin/inventory-frontend-entrypoint"]
