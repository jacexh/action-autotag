FROM alpine:3.19

RUN apk add --no-cache bash git jq

COPY autotag.sh /autotag.sh

RUN chmod +x /autotag.sh

ENTRYPOINT ["/autotag.sh"]