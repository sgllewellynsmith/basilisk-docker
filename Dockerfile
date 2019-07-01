FROM debian:latest

LABEL maintainer "Stefan Llewellyn Smith <sgls@ucsd.edu>"

RUN useradd -ms /bin/bash basilisk && echo "basilisk:basilisk" | chpasswd && adduser basilisk sudo

# basic tools (gawk is needed to avoid a debian clash; apt-utils is useful)
USER root
RUN apt-get -y update && apt-get install -y \
    darcs flex make gawk apt-utils
USER basilisk

#get basilisk
WORKDIR /home/basilisk
RUN darcs get --lazy http://basilisk.fr/basilisk
ENV BASILISK /home/basilisk/basilisk/src
ENV PATH $PATH:/home/basilisk/basilisk/src

# Packages
USER root
# useful additional packages (basilisk)
RUN apt-get -y update && apt-get install -y \
    gnuplot imagemagick libav-tools smpeg-plaympeg graphviz valgrind gifsicle
# Using Basilisk with python
RUN apt-get -y update && apt-get install -y swig
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
    sudo python-tk python-pip
RUN pip install matplotlib gprof2dot xdot
# gerris
RUN apt-get -y update && apt-get install -y \
    gerris gfsview-batch
#add gts?
USER basilisk

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

# make basilisk
RUN cd $BASILISK; \
    ln -s config.gcc config; \
    make

USER root
# off-screen rendering
RUN apt-get -y update && apt-get install -y \
    libglu1-mesa-dev libosmesa6-dev
# graphics-acceleration hardware
RUN apt-get -y update && apt-get install -y \
    libglu1-mesa-dev libglew-dev libgl1-mesa-dev
USER basilisk

# compile mesa
RUN wget mesa.freedesktop.org/archive/mesa-19.0.4.tar.gz; \
    tar xzvf mesa-19.0.4.tar.gz;
RUN cd mesa-19.0.4; \
    ./configure --prefix=/usr/local --enable-osmesa \
	    --with-gallium-drivers=swrast \
            --disable-driglx-direct --disable-dri --disable-gbm --disable-egl --with-platforms=x11 --enable-autotools; \
    make
RUN wget ftp://ftp.freedesktop.org/pub/mesa/glu/glu-9.0.0.tar.gz; \
    tar xzvf glu-9.0.0.tar.gz
RUN cd glu-9.0.0; \
    ls; \
    ./configure; \
    make
USER root
RUN apt-get remove -y \
    libosmesa6-dev libgl1-mesa-dev
RUN apt-get autoclean -y
RUN cd mesa-19.0.4; \
    make install
RUN cd glu-9.0.0; \
    make install
RUN apt-get -y update && apt-get install -y libglew-dev freeglut3-dev
USER basilisk

# off-screen rendering
RUN cd $BASILISK/gl; \
    make libglutils.a libfb_osmesa.a
# graphics-acceleration hardware
RUN cd $BASILISK/gl; \
    make libfb_glx.a

# bview servers off-screen rendering
#ENV OPENGLIBS = -lfb_osmesa -lGLU -lOSMesa
# bview servers graphics-acceleration hardware
ENV OPENGLIBS = -lfb_glx -lGLU -lGLEW -lGL -lX11
RUN cd $BASILISK; \
    make bview-servers

USER root
# other useful packages (SGLS)
# non-graphical (gfortran used in Vofi tests)
RUN apt-get -y update && apt-get install -y \
     less emacs pstoedit
# graphical
RUN apt-get -y update && apt-get install -y \
    vlc xpdf gimp xterm nomacs evince meshlab gv
USER basilisk

CMD /bin/bash
