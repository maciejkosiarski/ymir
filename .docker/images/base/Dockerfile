ARG BASE_IMAGE
FROM ${BASE_IMAGE}

RUN apt-get update && \
    apt-get install -y \
    zlib1g-dev libzip-dev git openssh-client \
    libcurl4-openssl-dev pkg-config libssl-dev \
    libpng-dev libxml2-dev libicu-dev g++ \
    libpq-dev unzip librabbitmq-dev vim

RUN docker-php-ext-install pdo soap sockets bcmath zip gd \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install xml intl pdo_pgsql pdo_mysql \
    && pecl install mongodb-1.12.0 amqp-1.11.0 grpc-1.46.3 protobuf-3.21.1 \
    && docker-php-ext-enable mongodb amqp grpc protobuf \
    && rm -rf /var/lib/apt/lists/* \
    && pecl clear-cache \
    && pecl config-set php_ini /usr/local/etc/php/conf.d/over.ini \
    && docker-php-ext-configure pcntl --enable-pcntl

RUN curl -OL https://github.com/phpmd/phpmd/releases/download/2.10.1/phpmd.phar && \
    cp phpmd.phar /usr/local/bin/phpmd && \
    chmod +x /usr/local/bin/phpmd
