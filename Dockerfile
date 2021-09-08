# SGLS 090921

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
    ls; \
    make install

# that was the slow bit
# now install other useful stuff

# jview stuff (may not need git if not building a server)	 
RUN apt-get -y update && apt-get install -y chromium git
# other useful packages (SGLS)
# non-graphical (gfortran used in Vofi tests)
RUN apt-get -y update && apt-get install -y \
     less emacs
# graphical
RUN apt-get -y update && apt-get install -y \
    vlc xpdf gimp xterm evince meshlab gv eog
# nomacs has gone?
RUN apt-get -y update && apt-get install -y feh

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

USER root
RUN apt-get -y update && apt-get install -y firefox-esr
USER basilisk

# probably fine up to here

# off-screen rendering
#ENV CFLAGS += -g -Wall -pipe -D_FORTIFY_SOURCE=2
#ENV OPENGLIBS = -lfb_osmesa -lGLU -lOSMesa
#RUN cd $BASILISK; \
#    rm config; \
#    cp config.gcc config; \
#    sed -i 's/-lfb_dumb/-lfb_osmesa -lGLU -lOSMesa/' config; \
#    sed -i 's/-DDUMBGL//' config; \
#    cat config; \
#    make clean
#RUN cd $BASILISK/gl; \
#    make clean; \
#    make libglutils.a libfb_osmesa.a
# graphics-acceleration hardware
#ENV OPENGLIBS = -lfb_glx -lGLU -lGLEW -lGL -lX11
RUN cd $BASILISK; \
    rm config; \
    cp config.gcc config; \
    sed -i 's/-lfb_dumb/-lfb_glx -lGLU -lGLEW -lGL -lX11/' config; \
    sed -i 's/-DDUMBGL//' config; \
    cat config; \
    make clean
RUN cd $BASILISK/gl; \
    make clean; \
    make libfb_glx.a
RUN cd $BASILISK; \
    cat config; \
    ls gl
RUN cd $BASILISK; \
    make clean; \
    make -k; \
    make

# bview servers off-screen rendering
#ENV OPENGLIBS = -lfb_osmesa -lGLU -lOSMesa
# bview servers graphics-acceleration hardware
##ENV OPENGLIBS = -lfb_glx -lGLU -lGLEW -lGL -lX11
#RUN cd $BASILISK; \
#    make bview-servers

# have lost python?
USER root
RUN apt-get -y update && apt-get install -y python
USER basilisk

# works up to here

# GOTM
USER root
RUN apt-get -y update && apt-get install -y cmake libnetcdff-dev
RUN ls
RUN wget https://github.com/gotm-model/code/archive/v5.2.1.tar.gz; \
    tar xzvf v5.2.1.tar.gz
RUN cd code-5.2.1/src ;\
    ls; \
    wget http://basilisk.fr/src/gotm/gotm.patch?raw -O gotm.patch; \
    patch -p0 < gotm.patch; \
    cd ..; \
    ls; \
    mkdir build; \
    cd build; \
    cmake ../src -DGOTM_USE_FABM=off; \
    make  
USER basilisk

# PPR
RUN cd $BASILISK/ppr; \
    make; \
    ls

USER root
RUN apt-get -y update && apt-get install -y eog
USER basilisk

# CVMix
#RUN git clone git@github.com:CVMix/CVMix-src.git
#RUN ls

#USER root
# jview
#USER basilisk
#RUN cd $BASILISK/bview/three.js; \
#    git init; \
#    git remote add origin https://github.com/mrdoob/three.js.git; \
#    git fetch; \
#    git reset origin/master; \
#    git checkout r124 -- .; \
#    darcs revert -a .

CMD /bin/bash
