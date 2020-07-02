FROM ubuntu:xenial

RUN apt-get update
RUN apt-get -y install wget curl gcc g++ python3 python3-venv make

RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.1/cmake-3.16.1-Linux-x86_64.sh --no-check-certificate -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local
