# Ubuntu/Debian

Install packages needed to build vim:

    apt install xsel ruby-dev python3-dev python-dev liblua5.2 libncurses5-dev gawk libx11-dev libice-dev libsm-dev libxt-dev libxpm-dev

Configure vim with necessary features:

    ./configure --prefix=`pwd`/build --enable-pythoninterp=yes --enable-python3interp=yes --with-features=huge --with-x --enable-gui --enable-luainterp=yes --enable-rubyinterp=yes --with-x

# Fedora

Install packages needed to build vim:

    dnf install xsel ruby-devel python3-devel lua-devel python-devel ncurses-devel gawk x11-devel libICE-devel libXpm-devel libXt-devel libX11-devel ncurses-compat-libs

Configure vim with necessary features:

    CFLAGS='-fPIC -O2' ./configure --prefix=`pwd`/build --enable-pythoninterp=yes --enable-python3interp=yes --with-features=huge --with-x --enable-gui --enable-luainterp=yes --enable-rubyinterp=yes --with-x
