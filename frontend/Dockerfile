FROM node:22-alpine AS build

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY angular.json tsconfig.json tsconfig.app.json ./
COPY public ./public
COPY src ./src
RUN pnpm build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /usr/local/bin/inventory-frontend-entrypoint
COPY --from=build /app/dist/qa-gestion-inventarios-frontend/browser /usr/share/nginx/html

RUN chmod +x /usr/local/bin/inventory-frontend-entrypoint \
    && chown -R nginx:nginx /run /var/cache/nginx /var/run /var/log/nginx /usr/share/nginx/html

USER nginx

EXPOSE 8080

ENTRYPOINT []
CMD ["/usr/local/bin/inventory-frontend-entrypoint"]
