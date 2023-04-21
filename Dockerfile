FROM kong:latest
USER root

COPY ./kong/plugins/zenskar /custom-plugins/zenskar/kong/plugins/zenskar
COPY ./kong-plugin-zenskar-0.1.0-1.rockspec custom-plugins/zenskar
WORKDIR /custom-plugins/zenskar

RUN luarocks make
WORKDIR /
USER kong
