#!/bin/sh

set -e
set -x

wget_once() {
  url="$1"
  if ! test -f `basename "$url"`; then
    wget -O `basename "$url"`.part "$url"
    rv=$?
    if test $rv = 0; then
      mv `basename "$url"`.part `basename "$url"`
    else
      rm -f `basename "$url"`.part
      return $rv
    fi
  fi
}

file_host=https://github.com/pycurl/deps/raw/master

(cd &&
  mkdir -p opt &&
  cd opt &&
  wget $file_host/bin-precise-64.tar.xz &&
  tar xfJ bin-precise-64.tar.xz)

export PATH=~/opt/bin:$PATH

if test -n "$USEPY"; then
  # need to launch tests.appmanager with a more modern python.
  # doing this for 3.1 now.
  pip install -r requirements-dev.txt

  (cd && mkdir -p opt && cd opt &&
    wget $file_host/python-"$USEPY"-precise-64.tar.xz &&
    tar xfJ python-"$USEPY"-precise-64.tar.xz)
  export PATH=$HOME/opt/python-$USEPY/bin:$PATH

  mkdir archives && (
    cd archives &&
    wget_once https://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.7.1.2.tar.gz &&
    tar zxf virtualenv-1.7.1.2.tar.gz &&
    cd virtualenv-1.7.1.2 &&
    ~/opt/python-$USEPY/bin/python$USEPY setup.py install
  )

  virtualenv --version
  which virtualenv
  # travis places its virtualenv in /usr/local/bin.
  # virtualenv 1.7 installed above for python 2.x goes in /usr/bin.
  # /usr/local/bin is earlier in path and takes precedence.
  # manually invoke the 1.7 version here.
  # however, when installed for 2.x our virtualenv 1.7 goes in /usr/local/bin.
  if test "$USEPY" = 3.1; then
    virtualenv=$HOME/opt/python-$USEPY/bin/virtualenv
  else
    virtualenv=/usr/bin/virtualenv
  fi
  $virtualenv --version
  $virtualenv ~/virtualenv/python$USEPY -p python$USEPY
  . ~/virtualenv/python$USEPY/bin/activate
  python -V
  which pip
  pip --version
fi

if test -e requirements-dev-$USEPY.txt; then
  pip install -r requirements-dev-$USEPY.txt
else
  pip install -r requirements-dev.txt
fi

if test "$USEPY" = 3.1; then
  # install flaky since pip/tarfile barfs on it
  wget_once https://pypi.python.org/packages/source/f/flaky/flaky-2.2.0.tar.gz
  tar xfz flaky-2.2.0.tar.gz
  cd flaky-2.2.0
  python setup.py install
  cd ..
fi

if test -n "$USECURL"; then
  if echo "$USECURL" |grep -q -- "-libssh2\$"; then
    curl_suffix=-libssh2
    USECURL=$(echo "$USECURL" |sed -e s/-libssh2//)
  else
    curl_suffix=
  fi
  if echo "$USECURL" |grep -q -- "-gssapi\$"; then
    curl_suffix=-gssapi$curl_suffix
    USECURL=$(echo "$USECURL" |sed -e s/-gssapi//)
  fi

  if test -n "$USEOPENSSL"; then
    (cd && mkdir -p opt && cd opt &&
      wget $file_host/openssl-"$USEOPENSSL"-precise-64.tar.xz &&
      tar xfJ openssl-"$USEOPENSSL"-precise-64.tar.xz)
  fi
  if test -n "$USELIBRESSL"; then
    (cd && mkdir -p opt && cd opt &&
      wget $file_host/libressl-"$USELIBRESSL"-precise-64.tar.xz &&
      tar xfJ libressl-"$USELIBRESSL"-precise-64.tar.xz)
  fi

  if test -n "$USESSL"; then
    if test "$USESSL" != none; then
      curldirname=curl-"$USECURL"-"$USESSL"$curl_suffix
    else
      curldirname=curl-"$USECURL"-none$curl_suffix
    fi
  else
    curldirname=curl-"$USECURL"$curl_suffix
  fi
  export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$HOME/opt/$curldirname/lib
  name=$curldirname-precise-64.tar.xz
  (cd &&
    mkdir -p opt &&
    cd opt &&
    wget $file_host/"$name" &&
    tar xfJ "$name")
  curl_flavor=`echo "$USECURL" |awk -F- '{print $2}'`
  "$HOME"/opt/$curldirname/bin/curl -V
else
  curl -V
fi

if test -n "$USEPY"; then
  PYTHON_VERSION="$USEPY"
else
  PYTHON_VERSION="$TRAVIS_PYTHON_VERSION"
fi

# for building documentation.
# this must be done after python is installed so that we install sphinx
# into the correct python version.
# sphinx 1.4.9 requires python 2.6+ or 3.3+
# sphinx 1.5 requires python 2.7 or 3.4+
case "$PYTHON_VERSION" in
  2.[45])
    ;;
  2.6)
    pip install sphinx==1.4.9
    ;;
  3.[12])
    ;;
  3.3)
    pip install sphinx==1.4.9
    ;;
  *)
    pip install sphinx
    ;;
esac
