# The dynamic (glibc) Linux build and test environment; `make docker-build`
# and `docker-test` build it.
#
# An image rather than apt-on-every-run so the C libraries are pinned here
# instead of by whatever noble-updates serves that day.
#
# SWIFT_VERSION has no default: .swift-version is the single pin, and a build
# without it should fail rather than track `swift:latest`.
ARG SWIFT_VERSION
FROM swift:${SWIFT_VERSION}

# tzdata is load-bearing: ExifDateTests skips itself without
# /usr/share/zoneinfo, silently dropping the only guard against an unpinned
# DateFormatter. The base image ships it today; do not rely on that.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         libvips-dev libexif-dev libiptcdata0-dev pkg-config tzdata \
    && rm -rf /var/lib/apt/lists/*
