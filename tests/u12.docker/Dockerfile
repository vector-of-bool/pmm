FROM ubuntu:precise

RUN apt-get update
RUN apt-get -y install curl gcc g++ python make

RUN curl https://cmake.org/files/v3.12/cmake-3.12.2-Linux-x86_64.sh -o /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local

# We have to download pip from upstream to get it installed properly.
RUN curl https://bootstrap.pypa.io/get-pip.py | python -
RUN pip install virtualenv
