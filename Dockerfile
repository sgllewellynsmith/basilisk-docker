# SGLS 091621

FROM debian:latest

LABEL maintainer "Stefan Llewellyn Smith <sgls@ucsd.edu>"

RUN useradd -ms /bin/bash basilisk && echo "basilisk:basilisk" | chpasswd && adduser basilisk sudo

# basic tools (apt-utils is useful)
USER root
RUN apt-get -y update && apt-get install -y \
    darcs flex bison make gawk apt-utils
USER basilisk

#set up environment, but install basilisk later
WORKDIR /home/basilisk
ENV BASILISK /home/basilisk/basilisk/src
ENV PATH $PATH:/home/basilisk/basilisk/src

# Packages
USER root
# useful additional packages (basilisk)
RUN apt-get -y update && apt-get install -y \
    gnuplot imagemagick ffmpeg graphviz valgrind gifsicle pstoedit
# Using Basilisk with python
RUN apt-get -y update && apt-get install -y swig libpython2-dev
# You also need to setup the MDFLAGS and PYTHONINCLUDE variables in your config file.
# ssh is needed for certain tests
RUN apt-get -y update && apt-get install -y openssh-server
# is this needed?
RUN mkdir /var/run/sshd
# libgsl-dev is needed for certain tests
RUN apt-get -y update && apt-get install -y libgsl-dev
# unzip is needed for topographic databases
RUN apt-get -y update && apt-get install -y unzip 
# mpi
RUN apt-get -y update && apt-get install -y \
    libopenmpi-dev openmpi-bin
# python graphics
RUN apt-get -y update && apt-get install -y \
    sudo python-tk python3-pip
RUN pip install matplotlib gprof2dot xdot
# have lost python?
RUN apt-get -y update && apt-get install -y python
# gerris
RUN apt-get -y update && apt-get install -y \
    gerris gfsview-batch
#add gts?
USER basilisk

#get basilisk
RUN darcs get --lazy http://basilisk.fr/basilisk
# make basilisk
RUN cd $BASILISK; \
    ln -s config.gcc config; \
    make -k; \
    make

# CADNA
# need wget
USER root
RUN apt-get -y update && apt-get install wget
USER basilisk
RUN wget http://cadna.lip6.fr/Download_Dir/cadna_c-2.0.2.tar.gz; \
    tar xzvf cadna_c-2.0.2.tar.gz; \ 
    cd cadna_c-2.0.2/; \
    patch -p1 < $BASILISK/cadna.patch; \
    ./configure; \
    make
USER root
RUN cd cadna_c-2.0.2/; \
    make install
RUN apt-get -y update && apt-get install -y clang
USER basilisk

# install Vof (gfortran is used for tests; not needed here for installation)
USER root
RUN apt-get -y update && apt-get install -y gfortran
USER basilisk
RUN wget http://www.ida.upmc.fr/~zaleski/paris/Vofi-1.0.tar.gz; \
    tar xzvf Vofi-1.0.tar.gz
RUN cd Vofi; \
    ./configure; \
    make lib
USER root
RUN cd Vofi; \
    make install
USER basilisk

USER root
# off-screen rendering
RUN apt-get -y update && apt-get install -y \
    libglu1-mesa-dev libosmesa6-dev
# graphics-acceleration hardware
RUN apt-get -y update && apt-get install -y \
    libglu1-mesa-dev libglew-dev libgl1-mesa-dev
USER basilisk

# compile mesa
USER basilisk
RUN wget mesa.freedesktop.org/archive/mesa-19.0.4.tar.gz; \
    tar xzvf mesa-19.0.4.tar.gz;
USER root
RUN apt-get -y update && apt-get install -y libxext-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-xfixes0-dev
USER basilisk
RUN cd mesa-19.0.4; \
    ./configure --prefix=/usr/local --enable-osmesa \
	    --with-gallium-drivers=swrast \
            --disable-driglx-direct --disable-dri --disable-gbm --disable-egl --with-platforms=x11 --enable-autotools; \
    make
USER basilisk
RUN wget ftp://ftp.freedesktop.org/pub/mesa/glu/glu-9.0.0.tar.gz; \
    tar xzvf glu-9.0.0.tar.gz
USER root
RUN cd mesa-19.0.4; \
    make install
USER basilisk
RUN cd glu-9.0.0; \
    ./configure; \
    make
USER root
#RUN apt-get remove -y \
#    libosmesa6-dev libgl1-mesa-dev
#RUN apt-get autoclean -y
#RUN cd mesa-19.0.4; \
#    make install
RUN cd glu-9.0.0; \
    make install
#RUN apt-get -y update && apt-get install -y libglew-dev freeglut3-dev
USER basilisk

# that was the slow bit
# now install other useful stuff

USER root
# jview (may not need git if not building a server)	 
RUN apt-get -y update && apt-get install -y chromium git firefox-esr
# other useful packages (SGLS)
# non-graphical (gfortran used in Vofi tests)
RUN apt-get -y update && apt-get install -y \
     less emacs
# graphical - nomacs has gone?
RUN apt-get -y update && apt-get install -y \
    vlc xpdf gimp xterm evince meshlab gv eog feh

# PPR
RUN cd $BASILISK/ppr; \
    make

# rendering
RUN cd $BASILISK/gl; \
    make libglutils.a libfb_osmesa.a libfb_glx.a
RUN cd $BASILISK; \
    rm config; \
    cp config.gcc config; \
    sed -i 's/-lfb_dumb/-lfb_glx -lGLU -lGLEW -lGL -lX11/' config; \
    sed -i 's/-DDUMBGL//' config; \
    cat config; \
    make clean; \
    echo "make -k"; \
    make -k; \
    make    

# GOTM
USER root
RUN apt-get -y update && apt-get install -y cmake libnetcdff-dev
USER basilisk
RUN wget https://github.com/gotm-model/code/archive/v5.2.1.tar.gz; \
    tar xzvf v5.2.1.tar.gz
RUN cd code-5.2.1/src ;\
    wget http://basilisk.fr/src/gotm/gotm.patch?raw -O gotm.patch; \
    patch -p0 < gotm.patch; \
    cd ..; \
    mkdir build; \
    cd build; \
    cmake ../src -DGOTM_USE_FABM=off; \
    make  
#ENV CFLAGS -L/home/basilisk/code-5.2.1/build

# CVMix is not built
RUN wget https://github.com/CVMix/CVMix-src/tarball/master; \
    tar xvzf master
RUN mv CVMix* $BASILISK/cvmix
RUN cd $BASILISK/cvmix; \
    wget http://basilisk.fr/src/cvmix/Makefile?raw -O Makefile
#ENV FC gfortran
#ENV FCFLAGS -Wall -O2
#RUN cd $BASILISK/cvmix; \
#    make libcvmixc.a

CMD /bin/bash
