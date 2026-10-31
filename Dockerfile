# syntax=docker/dockerfile:1
FROM elixir:1.18-otp-27@sha256:e6228e8a8967e60755664b7b1d621cff776d59cd4ca7e8de6637531c08fa8b51 AS build
ENV MIX_ENV=prod
WORKDIR /app
COPY mix.exs mix.lock ./
COPY config config
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export HEX_CACERTS_PATH=/run/secrets/proxy_ca; fi; \
    mix local.hex --force && mix local.rebar --force && mix deps.get --only prod
COPY lib lib
COPY priv priv
RUN mix compile && mix release

# Release locale HTTP pour Docker Desktop; le service Compose est limité à 127.0.0.1.
FROM build AS local_build
ENV MIX_ENV=local
RUN mix compile --warnings-as-errors && mix release

FROM elixir:1.18-otp-27@sha256:e6228e8a8967e60755664b7b1d621cff776d59cd4ca7e8de6637531c08fa8b51 AS local
ENV LANG=C.UTF-8 DATA_DIR=/data
WORKDIR /app
RUN useradd --uid 10001 --create-home bricks && mkdir /data && chown bricks /data
COPY --from=local_build --chown=bricks:bricks /app/_build/local/rel/first_bricks ./
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/first-bricks-entrypoint
ENTRYPOINT ["first-bricks-entrypoint"]
EXPOSE 4000
CMD ["bin/first_bricks", "start"]

# La dernière cible demeure la production HTTPS pour Railway.
FROM elixir:1.18-otp-27@sha256:e6228e8a8967e60755664b7b1d621cff776d59cd4ca7e8de6637531c08fa8b51 AS runtime
ENV LANG=C.UTF-8 DATA_DIR=/data
WORKDIR /app
RUN useradd --uid 10001 --create-home bricks && mkdir /data && chown bricks /data
COPY --from=build --chown=bricks:bricks /app/_build/prod/rel/first_bricks ./
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/first-bricks-entrypoint
ENTRYPOINT ["first-bricks-entrypoint"]
EXPOSE 4000
CMD ["bin/first_bricks", "start"]
