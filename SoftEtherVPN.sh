#!/bin/bash

set -e
set -x

mkdir ~/softether && cd ~/softether

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
DEST=$BASE/opt
LDFLAGS="-L$DEST/lib -Wl,--gc-sections"
CPPFLAGS="-I$DEST/include"
CFLAGS="-mtune=mips32 -mips32 -O3 -ffunction-sections -fdata-sections"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=/opt --host=mipsel-linux"
MAKE="make -j`nproc`"

mkdir $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET https://zlib.net/zlib-1.2.11.tar.gz
tar zxvf zlib-1.2.11.tar.gz
cd zlib-1.2.11

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=mipsel-linux- \
./configure \
--prefix=/opt \
--static

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET https://www.openssl.org/source/openssl-1.0.2n.tar.gz
tar zxvf openssl-1.0.2n.tar.gz
cd openssl-1.0.2n

./Configure linux-mips32 \
-mtune=mips32 -mips32 -ffunction-sections -fdata-sections -Wl,--gc-sections \
--prefix=/opt zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=mipsel-linux-gcc
make CC=mipsel-linux-gcc install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# NCURSES # #################################################################
########### #################################################################

mkdir $SRC/curses && cd $SRC/curses
$WGET http://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
tar zxvf ncurses-6.0.tar.gz
cd ncurses-6.0

LDFLAGS=$LDFLAGS \
CPPFLAGS="-P $CPPFLAGS" \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-widec \
--enable-overwrite \
--with-normal \
--with-shared \
--enable-rpath \
--with-fallbacks=xterm

$MAKE
make install DESTDIR=$BASE

############### #############################################################
# LIBREADLINE # #############################################################
############### #############################################################

mkdir $SRC/libreadline && cd $SRC/libreadline
$WGET http://ftp.gnu.org/gnu/readline/readline-7.0.tar.gz
tar zxvf readline-7.0.tar.gz
cd readline-7.0

$WGET https://raw.githubusercontent.com/lancethepants/tomatoware/master/patches/readline/readline.patch
patch < readline.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--disable-shared \
bash_cv_wcwidth_broken=no \
bash_cv_func_sigsetjmp=yes

$MAKE
make install DESTDIR=$BASE

############ ################################################################
# LIBICONV # ################################################################
############ ################################################################

mkdir $SRC/libiconv && cd $SRC/libiconv
$WGET http://ftp.gnu.org/gnu/libiconv/libiconv-1.15.tar.gz
tar zxvf libiconv-1.15.tar.gz
cd libiconv-1.15

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

############# ###############################################################
# SOFTETHER # ###############################################################
############# ###############################################################

mkdir $SRC/softether && cd $SRC/softether
git clone https://github.com/SoftEtherVPN/SoftEtherVPN.git

cp -r SoftEtherVPN SoftEtherVPN_host
cd SoftEtherVPN_host

if [ "`uname -m`" == "x86_64" ];then
	cp ./src/makefiles/linux_64bit.mak ./Makefile
else
	cp ./src/makefiles/linux_32bit.mak ./Makefile
fi

$MAKE

cd ../SoftEtherVPN

$WGET https://raw.githubusercontent.com/lancethepants/SoftEtherVPN-arm-static/master/patches/100-ccldflags.patch
$WGET https://raw.githubusercontent.com/lancethepants/SoftEtherVPN-arm-static/master/patches/iconv.patch
patch -p1 < 100-ccldflags.patch
patch -p1 < iconv.patch

cp ./src/makefiles/linux_32bit.mak ./Makefile
sed -i 's,#CC=gcc,CC=mipsel-linux-gcc,g' Makefile
sed -i 's,-lncurses -lz,-lncursesw -lz -liconv,g' Makefile
sed -i 's,ranlib,mipsel-linux-ranlib,g' Makefile

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE \
|| true

cp ../SoftEtherVPN_host/tmp/hamcorebuilder ./tmp/

CCFLAGS="$CPPFLAGS $CFLAGS" \
LDFLAGS="-static $LDFLAGS" \
$MAKE
