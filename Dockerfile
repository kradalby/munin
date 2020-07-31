FROM kradalby/swift:groovy AS builder

WORKDIR /app

COPY . .
RUN make test
RUN make build-release

FROM kradalby/swift:groovy

COPY --from=builder /app/.build/release /app

ENTRYPOINT [ "/app/munin" ]
