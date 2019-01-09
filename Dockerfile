FROM ubuntu:18.04

LABEL authors="Sören Gebbert,Carmen Tawalika,Markus Neteler"
LABEL maintainer="soerengebbert@gmail.com,tawalika@mundialis.de,neteler@mundialis.de"

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /tmp

# Workaround for resolveconf ubuntu docker issue
# https://stackoverflow.com/questions/40877643/apt-get-install-in-ubuntu-16-04-docker-image-etc-resolv-conf-device-or-reso
RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

# Install the dependencies of GRASS GIS (we'll locally compile PROJ 4.9)
RUN apt update && apt upgrade -y && \
        apt install software-properties-common -y && \
        add-apt-repository ppa:ubuntugis/ubuntugis-unstable -y && \
        apt update && apt install --no-install-recommends --no-install-suggests \
        build-essential \
        attr \
        bison \
        bzip2 \
        curl \
        flex \
        g++ \
        gcc \
        gdal-bin \
        gettext \
        gnutls-bin \
        libapt-pkg-perl \
        libbz2-dev \
        libcairo2 \
        libcairo2-dev \
        libcurl4-gnutls-dev \
        libfftw3-bin \
        libfftw3-dev \
        libfreetype6-dev \
        libgdal-dev \
        libgeos-dev \
        libgnutls28-dev \
        libgsl0-dev \
        libjpeg-dev \
        liblas-c-dev \
        liblas-dev \
        libnetcdf-dev \
        libncurses5-dev \
        libopenjp2-7 \
        libopenjp2-7-dev \
        libpdal-dev pdal \
        libpdal-plugin-python \
        libpnglite-dev \
        libpq-dev \
        libpython3-all-dev \
        libsqlite3-dev \
        libtiff-dev \
        libzstd-dev \
        gdal-bin \
        make \
        moreutils \
        ncurses-bin \
        netcdf-bin \
        python \
        python-dev \
        python-numpy \
        python-pil \
        python-ply \
        resolvconf \
        sqlite3 \
        subversion \
        unzip \
        vim \
        wget \
        zip \
        zlib1g-dev -y && \
        apt-get clean && \
        apt-get autoremove

RUN echo LANG="en_US.UTF-8" > /etc/default/locale

WORKDIR /src

# install the latest projection library for GRASS GIS
RUN wget http://download.osgeo.org/proj/proj-5.2.0.tar.gz && \
    tar xzvf proj-5.2.0.tar.gz && \
    cd /src/proj-5.2.0/ && \
    wget http://download.osgeo.org/proj/proj-datumgrid-1.8.zip && \
    cd nad && \
    unzip ../proj-datumgrid-1.8.zip && \
    cd .. && \
    ./configure --prefix=/usr/ && \
    make && \
    make install

# Checkout and install GRASS GIS
WORKDIR /src
RUN wget https://grass.osgeo.org/grass76/source/snapshot/grass-7.6.svn_src_snapshot_latest.tar.gz
# unpack source code package and remove tarball archive:
RUN mkdir /src/grass_build && \
    tar xfz grass-7.6.svn_src_snapshot_latest.tar.gz --strip=1 -C /src/grass_build && \
    rm -f grass-7.6.svn_src_snapshot_latest.tar.gz

# update snapshot once more to grab latest updates and fixes:
# cd /src/grass_build
WORKDIR /src/grass_build
RUN svn update

# Set environmental variables for GRASS GIS compilation, without debug symbols
ENV MYCFLAGS "-O2 -std=gnu99 -m64"
ENV MYLDFLAGS "-s -Wl,--no-undefined"
# CXX stuff:
ENV LD_LIBRARY_PATH "/usr/local/lib"
ENV LDFLAGS "$MYLDFLAGS"
ENV CFLAGS "$MYCFLAGS"
ENV CXXFLAGS "$MYCXXFLAGS"

# Configure compile and install GRASS GIS
ENV NUMTHREADS=2
RUN /src/grass_build/configure \
    --enable-largefile \
    --with-cxx \
    --with-proj --with-proj-share=/usr/share/proj \
    --with-gdal \
    --with-python \
    --with-geos \
    --with-sqlite \
    --with-bzlib \
    --with-zstd \
    --with-cairo --with-cairo-ldflags=-lfontconfig \
    --with-fftw \
    --with-liblas \
    --with-pdal \
    --with-netcdf \
    --with-postgres --with-postgres-includes="/usr/include/postgresql" \
    --without-freetype \
    --without-openmp \
    --without-opengl \
    --without-nls \
    --without-mysql \
    --without-odbc \
    --without-openmp \
    --without-ffmpeg \
    && make -j $NUMTHREADS && make install && ldconfig

# enable simple grass command regardless of version number
RUN ln -s `find /usr/local/bin -name "grass*"` /usr/local/bin/grass

# Unset environmental variables to avoid later compilation issues
ENV INTEL ""
ENV MYCFLAGS ""
ENV MYLDFLAGS ""
ENV MYCXXFLAGS ""
ENV LD_LIBRARY_PATH ""
ENV LDFLAGS ""
ENV CFLAGS ""
ENV CXXFLAGS ""

# set SHELL var to avoid /bin/sh fallback in interactive GRASS GIS sessions in docker
ENV SHELL /bin/bash

# Data workdir
WORKDIR /grassdb
VOLUME /grassdb

# Clean up the compiled files
RUN rm -rf /src/*

# Reduce the image size
RUN apt-get autoremove -y
RUN apt-get clean -y

# GRASS GIS specific
# allow work with MAPSETs that are not owned by current user
ENV GRASS_SKIP_MAPSET_OWNER_CHECK 1

# install external Python API
RUN apt-get install python python-pip -y
RUN pip install grass-session

# for python3 usage:
RUN apt install language-pack-en-base -y
ENV LC_ALL "en_US.UTF-8"

# debug
RUN grass --config revision version

CMD ["/usr/local/bin/grass", "--version"]
