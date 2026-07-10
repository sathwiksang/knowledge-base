# Production image — Next.js 16, multi-stage.
# The API URL is read at server start (rewrites proxy), not baked into the client.
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
# Rewrite destinations are compiled into the build; bake the internal API URL.
ARG NEXT_PUBLIC_API_URL=http://knowledge-base-api:80
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL \
    NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1

COPY --from=build /app/package.json /app/package-lock.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.ts ./

RUN addgroup -S app -g 1001 && adduser -S app -u 1001 && chown -R app:app /app
USER app

EXPOSE 3000
CMD ["npm", "run", "start"]
