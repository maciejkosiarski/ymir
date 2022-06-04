ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS build
WORKDIR /application

ARG SSH_PRIVATE_KEY
RUN mkdir -p ~/.ssh && \
    echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_rsa && \
    chmod 700 ~/.ssh/id_rsa && \
    eval "$(ssh-agent -s)" && \
    ssh-add ~/.ssh/id_rsa && \
    ssh-keyscan gitlab.performance-media.pl > ~/.ssh/known_hosts

COPY --from=composer:2.0.7 /usr/bin/composer /usr/bin/
COPY . ./
RUN composer install --ignore-platform-reqs --no-interaction

RUN ln -s /application/rr /usr/local/bin/rr
