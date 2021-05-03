FROM kradalby/swift:5.4-groovy AS builder

WORKDIR /app

RUN apt-get update \
        && apt-get upgrade -y \
        && apt-get install -o APT::Immediate-Configure=false -y libsqlite3-dev libexif-dev libiptcdata0-dev libmagickwand-6.q16-dev \
        && rm -rf /var/lib/apt/lists/*

COPY . .
RUN make test
RUN make build-release

FROM kradalby/swift:5.4-groovy

RUN apt-get update \
        && apt-get upgrade -y \
        && apt-get install -o APT::Immediate-Configure=false -y libexif-dev libiptcdata0-dev libmagickwand-6.q16-dev \
        && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/.build/release /app

ENTRYPOINT [ "/app/munin" ]
