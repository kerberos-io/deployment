FROM ubuntu:latest
LABEL maintainer="Cedric Verstraeten"

# Install dependencies
RUN apt-get update && apt-get install snapd snap-confine -y

# Install microk8s
RUN snap install microk8s --classic --channel=1.32/stable