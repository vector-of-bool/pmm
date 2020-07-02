FROM ubuntu:precise

RUN apt-get update
RUN apt-get -y install wget curl gcc g++ python make

RUN wget https://github.com/Kitware/CMake/releases/download/v3.16.1/cmake-3.16.1-Linux-x86_64.sh --no-check-certificate -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local

# We have to download pip from upstream to get it installed properly.
RUN curl https://bootstrap.pypa.io/get-pip.py | python -
RUN pip install virtualenv
