FROM ubuntu:bionic

RUN apt-get update
RUN apt-get -y install wget curl gcc g++ python3 python3-venv make

RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.1/cmake-3.16.1-Linux-x86_64.sh -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local

RUN apt-get -y install perl
RUN apt-get -y install unzip
RUN apt-get -y install git
