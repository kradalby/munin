FROM kradalby/swift:groovy AS builder

WORKDIR /app

RUN apt-get install -y libsqlite3-dev

COPY . .
RUN make test
RUN make build-release

FROM kradalby/swift:groovy

COPY --from=builder /app/.build/release /app

ENTRYPOINT [ "/app/munin" ]
