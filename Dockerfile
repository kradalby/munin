FROM kradalby/swift:groovy

WORKDIR /app

COPY . .
RUN make test
RUN make build-release

ENTRYPOINT [ "/app/.build/release/munin" ]
