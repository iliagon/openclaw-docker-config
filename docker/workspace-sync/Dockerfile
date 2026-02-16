FROM alpine:3.19

RUN apk add --no-cache git bash

COPY workspace-sync.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/workspace-sync.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
