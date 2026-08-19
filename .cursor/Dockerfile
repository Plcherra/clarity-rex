# Clarity Cloud Agent base image.
# Provides the full toolchain for the monorepo:
#   - services/rex-api  -> Python 3.12 (FastAPI)
#   - apps/web          -> Node.js 22 (Astro)
#   - apps/mobile       -> Flutter stable (Dart)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages + Python 3.12 toolchain + Flutter build prerequisites.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        build-essential \
        python3 \
        python3-venv \
        python3-pip \
        libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 (apps/web pins Node 22 via apps/web/.node-version).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Flutter stable SDK. Pinned so Dart satisfies apps/mobile pubspec (sdk: ^3.11.4).
ARG FLUTTER_VERSION=3.47.0
RUN curl -fsSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R ubuntu:ubuntu /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Warm the Flutter tool as the runtime user so per-user config is baked into
# the image. Platform/host artifacts are fetched by `flutter pub get` during
# the install step (which runs at build time and is captured in the snapshot).
USER ubuntu
RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics >/dev/null 2>&1 || true \
    && flutter --version
