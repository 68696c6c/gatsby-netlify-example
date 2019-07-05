FROM node:10-alpine AS base

RUN apk add --no-cache util-linux

# These dependancies are used for building sharp, an image processing library used by Gatsby.
# Yes, Python is required.
RUN apk add --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community \
    vips-dev vips-tools gcc g++ make libc6-compat python

RUN yarn global add gatsby-cli

EXPOSE 80
RUN mkdir -p /site
WORKDIR /site


########################################################################################################################
# Local development stage.
FROM base AS dev
RUN apk add --no-cache bash
RUN echo 'alias ll="ls -lah"' >> ~/.bashrc


########################################################################################################################
# Production stage.
FROM base AS final
COPY . .
RUN yarn
RUN yarn build
