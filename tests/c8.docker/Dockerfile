FROM rockylinux:8

RUN yum -y install wget curl python3 gcc gcc-c++ make unzip git zip tar

RUN wget https://github.com/Kitware/CMake/releases/download/v3.13.0/cmake-3.13.0-Linux-x86_64.sh -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local
