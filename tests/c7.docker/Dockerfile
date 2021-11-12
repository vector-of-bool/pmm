FROM centos/devtoolset-7-toolchain-centos7:7

USER 0
RUN yum -y install wget curl python3 python3-venv unzip

RUN wget https://github.com/Kitware/CMake/releases/download/v3.13.0/cmake-3.13.0-Linux-x86_64.sh -nv -O /tmp/cmake.sh
RUN sh /tmp/cmake.sh --exclude-subdir --prefix=/usr/local

# Note: vcpkg requiers a newer git than the Git with rhel7. This is possible by
# downloading and building a new one from source, but that's a big ask.
ENV PMM_VCPKG_TEST_SKIP=1

USER 1001