FROM ubuntu:latest
RUN apt update
RUN apt install -y git patchutils
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
