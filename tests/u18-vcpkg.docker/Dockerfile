FROM ubuntu:bionic

RUN apt-get update
RUN apt-get -y install curl gcc g++ python3 python3-venv make

RUN curl https://cmake.org/files/v3.12/cmake-3.12.2-Linux-x86_64.sh -o /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local

RUN apt-get -y install perl
RUN apt-get -y install unzip
RUN apt-get -y install git