# First Stage: Build xTeVe binary
FROM golang:alpine AS builder

# Install git (needed for go get clone) and other minimal build dependencies
RUN apk add --no-cache git

# Set working directory
WORKDIR /src

# Download source code
RUN git clone https://github.com/SenexCrenshaw/xTeVe.git /src

# Pass build arguments
ARG TARGETOS=linux
ARG TARGETARCH=amd64

# Build static binary
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -a -installsuffix cgo -o xteve xteve.go

# Optional: Strip the binary to reduce size
RUN strip xteve

# -----------------------------------------------------------------------------

# Second Stage: Minimal Alpine Runtime
FROM alpine:latest

# Build arguments (optional metadata)
ARG BUILD_DATE
ARG VCS_REF
ARG XTEVE_PORT=34400
ARG XTEVE_VERSION=2.5.3

# Metadata Labels
LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.url="https://hub.docker.com/r/SenexCrenshaw/xteve/" \
      org.opencontainers.image.source="https://github.com/SenexCrenshaw/xTeVe" \
      org.opencontainers.image.version="${XTEVE_VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="SenexCrenshaw" \
      org.opencontainers.image.title="xTeVe" \
      org.opencontainers.image.description="Dockerized fork of xTeVe by SenexCrenshaw" \
      org.opencontainers.image.authors="SenexCrenshaw SenexCrenshaw@gmail.com"

# Environment variables
ENV XTEVE_BIN=/home/xteve/bin
ENV XTEVE_CONF=/home/xteve/conf
ENV XTEVE_HOME=/home/xteve
ENV XTEVE_TEMP=/tmp/xteve
ENV PATH=$PATH:$XTEVE_BIN
ENV TZ=America/New_York

# Set working directory
WORKDIR $XTEVE_HOME

# Install runtime dependencies: CA certs, tzdata (only needed)
RUN apk add --no-cache ca-certificates tzdata

# Set timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create necessary folders
RUN mkdir -p $XTEVE_BIN $XTEVE_CONF $XTEVE_TEMP $XTEVE_HOME/cache && \
    chmod a+rwX $XTEVE_CONF $XTEVE_TEMP

# Copy the compiled xTeVe binary from builder stage
COPY --from=builder /src/xteve $XTEVE_BIN/xteve

# Permissions
RUN chmod +x $XTEVE_BIN/xteve

# Volumes for configuration and temp files
VOLUME $XTEVE_CONF
VOLUME $XTEVE_TEMP

# Expose web interface port
EXPOSE ${XTEVE_PORT}

# Default entrypoint
ENTRYPOINT ["xteve", "-port=34400", "-config=/home/xteve/conf"]
