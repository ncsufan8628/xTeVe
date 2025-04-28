# Build stage
FROM golang:bullseye AS builder

RUN apt-get update && apt-get install -y git

WORKDIR /src

RUN git clone https://github.com/SenexCrenshaw/xTeVe.git /src

ARG TARGETOS=linux
ARG TARGETARCH=amd64

RUN GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -o xteve xteve.go

RUN strip xteve

# -----------------------------------------------------------------------------

# Runtime stage (Debian)
FROM debian:bullseye-slim

ARG BUILD_DATE
ARG VCS_REF
ARG XTEVE_PORT=34400
ARG XTEVE_VERSION=2.5.3

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.url="https://hub.docker.com/r/SenexCrenshaw/xteve/" \
      org.opencontainers.image.source="https://github.com/SenexCrenshaw/xTeVe" \
      org.opencontainers.image.version="${XTEVE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="SenexCrenshaw" \
      org.opencontainers.image.title="xTeVe" \
      org.opencontainers.image.description="Dockerized fork of xTeVe by SenexCrenshaw" \
      org.opencontainers.image.authors="SenexCrenshaw SenexCrenshaw@gmail.com"

ENV XTEVE_BIN=/home/xteve/bin
ENV XTEVE_CONF=/home/xteve/conf
ENV XTEVE_HOME=/home/xteve
ENV XTEVE_TEMP=/tmp/xteve
ENV PATH=$PATH:$XTEVE_BIN
ENV TZ=America/New_York

WORKDIR $XTEVE_HOME

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates tzdata ffmpeg vlc curl && \
    rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Make folders
RUN mkdir -p $XTEVE_BIN $XTEVE_CONF $XTEVE_TEMP $XTEVE_HOME/cache && \
    chmod a+rwX $XTEVE_CONF $XTEVE_TEMP

# Copy binary
COPY --from=builder /src/xteve $XTEVE_BIN/xteve

# Permissions
RUN chmod +x $XTEVE_BIN/xteve

# Volumes
VOLUME $XTEVE_CONF
VOLUME $XTEVE_TEMP

EXPOSE ${XTEVE_PORT}

# Entrypoint
ENTRYPOINT ["xteve", "-port=34400", "-config=/home/xteve/conf"]
