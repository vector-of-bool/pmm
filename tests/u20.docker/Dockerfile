FROM ubuntu:20.04

RUN apt-get update && \
    apt-get -y install wget curl python3 python3-venv gcc g++ make \
        perl unzip zip git pkg-config

RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.1/cmake-3.16.1-Linux-x86_64.sh -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local
