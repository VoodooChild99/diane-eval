FROM ubuntu:16.04

ENV DEBIAN_FRONTEND noninteractive

ENV TZ=Asia/Shanghai

ARG proxy_address

ENV HTTP_PROXY=$proxy_address
ENV HTTPS_PROXY=$proxy_address
ENV http_proxy=$proxy_address
ENV https_proxy=$proxy_address
ENV NO_PROXY=localhost,127.0.0.1
ENV no_proxy=localhost,127.0.0.1

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update

RUN apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install apt-utils

# Set the locale
RUN apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install locales
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install dependencies
RUN apt-get update
RUN apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install \
    wget unzip build-essential cmake gcc libcunit1-dev libudev-dev \
    git python-pip python-tk tk-dev zlib1g-dev libffi-dev libssl-dev \
    libbz2-dev libreadline-dev libsqlite3-dev liblzma-dev \
    python2.7-dev libxml2-dev libxslt1-dev libffi-dev libtool debootstrap \
    debian-archive-keyring libglib2.0-dev libpixman-1-dev libqt4-dev \
    binutils-multiarch nasm sudo qt5-default mercurial flex bison \
    sshpass psmisc vim

# Upgrade setuptools and pip
RUN pip install --upgrade setuptools==44.1.1 && \
    pip install --upgrade "pip < 21.0"

# Install SIP
RUN cd $HOME && \
    hg clone https://www.riverbankcomputing.com/hg/sip && \
    cd sip && hg up 4.16.6 && \
    python build.py prepare && \
    python configure.py && \
    make -j`nproc` && \
    make install

# Install PyQt5
RUN cd $HOME && \
    wget https://master.dl.sourceforge.net/project/pyqt/PyQt5/PyQt-5.5.1/PyQt-gpl-5.5.1.tar.gz && \
    tar -xzvf PyQt-gpl-5.5.1.tar.gz && \
    rm PyQt-gpl-5.5.1.tar.gz && \
    cd PyQt-gpl-5.5.1 && \
    python configure.py --confirm-license && \
    make -j`nproc` && \
    make install

# Install JDK 17
RUN cd $HOME && \
    wget https://download.oracle.com/java/17/archive/jdk-17.0.9_linux-x64_bin.deb && \
    dpkg -i jdk-17.0.9_linux-x64_bin.deb

# Download Android CLI tools
RUN cd $HOME && \
    wget https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip && \
    unzip commandlinetools-linux-10406996_latest.zip && \
    rm commandlinetools-linux-10406996_latest.zip
ENV PATH ${PATH}:/root/cmdline-tools/bin

# Download Android SDK
RUN mkdir $HOME/android_sdk
ENV ANDROID_SDK /root/android_sdk
RUN yes | sdkmanager --licenses --sdk_root=$ANDROID_SDK && \
    sdkmanager --verbose --sdk_root=$ANDROID_SDK \
        $(sdkmanager --sdk_root=$ANDROID_SDK --list | grep "platforms;android-[1-9].*" | awk '{print $1}')

# Download Platform tools
RUN yes | sdkmanager --licenses --sdk_root=$ANDROID_SDK && \
    sdkmanager --verbose --sdk_root=$ANDROID_SDK platform-tools
ENV PATH ${PATH}:/root/android_sdk/platform-tools

# Download build tools
RUN yes | sdkmanager --licenses --sdk_root=$ANDROID_SDK && \
    sdkmanager --verbose --sdk_root=$ANDROID_SDK "build-tools;34.0.0"
ENV PATH ${PATH}:/root/android_sdk/build-tools/34.0.0

# Download Frida
RUN cd $HOME && \
    wget https://github.com/frida/frida/releases/download/11.0.2/frida-server-11.0.2-android-arm64.xz && \
    unxz frida-server-11.0.2-android-arm64.xz
RUN cd $HOME && \
    wget https://github.com/frida/frida/releases/download/11.0.2/frida-server-11.0.2-android-arm.xz && \
    unxz frida-server-11.0.2-android-arm.xz

# Build and Install FFmpeg
RUN apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install \
    python3-pip pkg-config libusb-1.0-0 libusb-1.0-0-dev ninja-build
RUN python3 -m pip install meson==0.52.1

RUN cd $HOME && \
    git clone https://github.com/FFmpeg/FFmpeg.git && \
    cd FFmpeg && \
    git checkout n6.1 && \
    ./configure && \
    make -j`nproc` && \
    make install

# Build and Install libsdl2
RUN cd $HOME && \
    git clone https://github.com/libsdl-org/SDL.git && \
    cd SDL && \
    git checkout release-2.0.6 && \
    ./configure && \
    make -j`nproc` && \
    make install

# Build Scrcpy
RUN cd $HOME && \
    git clone https://github.com/Genymobile/scrcpy.git && \
    cd scrcpy && \
    ./install_release.sh

# set git proxy
RUN if [ -n "$HTTP_PROXY" ]; then git config --global https.proxy $HTTP_PROXY && \
    git config --global http.proxy $HTTP_PROXY; fi

# Install turi
RUN pip install gitdb2==2.0.6 && pip install GitPython==2.1.14
RUN cd $HOME && \
    git clone https://github.com/VoodooChild99/turi.git && \
    cd turi && git checkout diane-docker && \
    ./setup.sh
RUN cd $HOME && pip install -e turi

# Configure ADB key
RUN if [ ! -d "$HOME/.android" ]; then mkdir $HOME/.android; fi
COPY adbkey* /root/.android/

# Install diane
RUN cd $HOME && \
    git clone https://github.com/VoodooChild99/diane.git && \
    cd diane && git checkout docker && \
    pip install -r diane/requirements.pip

# prepare workdir
RUN mkdir $HOME/workdir