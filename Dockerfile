FROM golang:1.8.3-jessie

RUN useradd --create-home -s /bin/bash content-service

ARG CONTAINER_ENGINE_ARG
ARG USE_NGINX_PLUS_ARG
ARG USE_VAULT_ARG
ARG NETWORK_ARG

# CONTAINER_ENGINE specifies the container engine to which the
# containers will be deployed. Valid values are:
# - kubernetes (default)
# - mesos
# - local
ENV USE_NGINX_PLUS=${USE_NGINX_PLUS_ARG:-true} \
    USE_VAULT=${USE_VAULT_ARG:-false} \
    CONTAINER_ENGINE=${CONTAINER_ENGINE_ARG:-kubernetes} \
    NETWORK=${NETWORK_ARG:-fabric}

RUN mkdir -p /go/src/app
WORKDIR /go/src/app

# this will ideally be built by the ONBUILD below ;)
CMD ["go-wrapper", "run"]

COPY app /go/src/app/
COPY nginx/ssl /etc/ssl/nginx/

# Fix jessie repo
RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list
# Get other files required for installation
RUN go-wrapper download && \
    go-wrapper install && \
    apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    libcurl3-gnutls \
    lsb-release \
    unzip \
    vim \
    wget && \
    mkdir -p /etc/ssl/nginx

# Install nginx and forward request logs to Docker log collector
ADD install-nginx.sh /usr/local/bin/
COPY nginx /etc/nginx/
RUN /usr/local/bin/install-nginx.sh && \
    ln -sf /dev/stdout /var/log/nginx/access_log && \
    ln -sf /dev/stderr /var/log/nginx/error_log

RUN ./test.sh

EXPOSE 80 443 12002

ENTRYPOINT ["./start.sh"]
