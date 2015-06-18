#!/bin/bash
## Date: 15-06-2015
## http://www.khmer.pw
## For CentOS 7.x

## Poppler Version
VPoppler=0.33.0
Vpopplerdata=0.4.7
VCario=1.14.2

## Install necessary tools
yum -y install cmake gcc gnu-getopt java-1.8.0-openjdk libpng-devel \
	libspiro-devel freetype-devel libjpeg-turbo-devel git wget zip unzip make gettext
	
## Additional
yum -y install gcc-c++ openjpeg-devel patch libtool libtool-ltdl-devel \
	pixman-devel python-devel glib2-devel pango-devel libxml2-devel libtiff-devel \
	giflib-devel

## Make temporary directory
mkdir -p /root/src/
###################

## Poppler
cd /root/src/
wget http://poppler.freedesktop.org/poppler-${VPoppler}.tar.xz -O poppler-${VPoppler}.tar.xz
tar xf poppler-${VPoppler}.tar.xz
cd poppler-${VPoppler}
git clone git://git.freedesktop.org/git/poppler/test testfiles

## Compile
./configure --prefix=/usr         \
            --sysconfdir=/etc     \
            --disable-static      \
            --enable-xpdf-headers \
            --with-testdatadir=$PWD/testfiles && make
make install
##To install the documentation, run the following commands as root:
#install -v -m755 -d        /usr/share/doc/poppler-0.33.0 &&
#install -v -m644 README*   /usr/share/doc/poppler-0.33.0 &&
#cp -vr glib/reference/html /usr/share/doc/poppler-0.33.0

#############
## Install poppler-data
cd /root/src/
wget http://poppler.freedesktop.org/poppler-data-${Vpopplerdata}.tar.gz -O poppler-data-${Vpopplerdata}.tar.gz
tar xzf poppler-data-${Vpopplerdata}.tar.gz
cd poppler-data-${Vpopplerdata}
make prefix=/usr install
###############

###############
## Install cairo
cd /root/src/
wget http://cairographics.org/releases/cairo-${VCario}.tar.xz -O cairo-${VCario}.tar.xz
tar xf cairo-${VCario}.tar.xz
cd cairo-${VCario}
./configure --prefix=/usr    \
            --disable-static \
            --enable-tee && make
make install

###############
## Install fontforge
cd /root/src/
git clone https://github.com/fontforge/fontforge.git
cd fontforge/
./bootstrap
./configure --prefix=/usr
make
make install

###############
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig
cd /root/src/
git clone git://github.com/coolwanglu/pdf2htmlEX.git
cd pdf2htmlEX
cmake . && make
make install

## To update and fix error: pdf2htmlEX: error while loading shared libraries:
## libpoppler.so.52: cannot open shared object file: No such file or directory
/usr/sbin/ldconfig
###############
