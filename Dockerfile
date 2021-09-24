FROM swift:5.5-bionic AS builder

WORKDIR /app

RUN sed -i 's/bionic/groovy/g' /etc/apt/sources.list \
        && apt-get update \
        && apt-get install -o APT::Immediate-Configure=false -y libsqlite3-dev libexif-dev libiptcdata0-dev libmagickwand-6.q16-dev \
        && rm -rf /var/lib/apt/lists/*

COPY . .
RUN make test
RUN make build-release

FROM swift:5.5-bionic-slim

RUN sed -i 's/bionic/groovy/g' /etc/apt/sources.list \
        && apt-get update \
        && apt-get install -o APT::Immediate-Configure=false -y libexif12 libiptcdata0 libmagickwand-6.q16-6 \
        && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/.build/release /app

ENTRYPOINT [ "/app/munin" ]
