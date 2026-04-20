FROM telegraf:latest

# switch to root to install extra packages
USER root

RUN apt update && apt install -y openssh-client && rm -rf /var/lib/apt/lists/*

# switch back to non-root for running telegraf
USER telegraf