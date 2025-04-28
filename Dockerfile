# -----------------------------------------------------------------------------
# Build Stage: Build xTeVe from source
# -----------------------------------------------------------------------------

    FROM golang:bullseye AS builder

    # Install git to fetch source
    RUN apt-get update && apt-get install -y --no-install-recommends git
    
    # Set working directory
    WORKDIR /src
    
    # Clone xTeVe repository
    RUN git clone https://github.com/SenexCrenshaw/xTeVe.git /src
    
    # Build arguments
    ARG TARGETOS=linux
    ARG TARGETARCH=amd64
    
    # Build xTeVe binary (trying static linking)
    RUN GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -o xteve xteve.go
    
    # 🔍 DEBUG: Check if the binary is dynamically or statically linked
    RUN echo "🔍 Checking xteve binary linking:" && \
        file xteve && \
        ldd xteve || echo "✅ Not dynamically linked (static binary)."
    
    # Strip debug symbols (optional, reduces size)
    RUN strip xteve
    
    # -----------------------------------------------------------------------------
    # Runtime Stage: Minimal Debian image to run xTeVe
    # -----------------------------------------------------------------------------
    
    FROM debian:bullseye-slim
    
    # Build metadata
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
    
    # Environment variables
    ENV XTEVE_BIN=/home/xteve/bin
    ENV XTEVE_CONF=/home/xteve/conf
    ENV XTEVE_HOME=/home/xteve
    ENV XTEVE_TEMP=/tmp/xteve
    ENV PATH=$PATH:$XTEVE_BIN
    ENV TZ=America/New_York
    
    # Set working directory
    WORKDIR $XTEVE_HOME
    
    # Install minimal runtime dependencies
    RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates tzdata ffmpeg vlc curl && \
        rm -rf /var/lib/apt/lists/*
    
    # Set timezone
    RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
    
    # Create needed directories
    RUN mkdir -p $XTEVE_BIN $XTEVE_CONF $XTEVE_TEMP $XTEVE_HOME/cache && \
        chmod a+rwX $XTEVE_CONF $XTEVE_TEMP
    
    # Copy compiled binary from builder
    COPY --from=builder /src/xteve $XTEVE_BIN/xteve
    
    # Set permissions
    RUN chmod +x $XTEVE_BIN/xteve
    
    # Declare volumes
    VOLUME $XTEVE_CONF
    VOLUME $XTEVE_TEMP
    
    # Expose web UI port
    EXPOSE ${XTEVE_PORT}
    
    # Entrypoint
    ENTRYPOINT ["xteve", "-port=34400", "-config=/home/xteve/conf"]    