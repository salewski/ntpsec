#!/bin/sh
# keep this POSIX sh compatible. No bash-isms!
# replace |& with 2>&1 |

# This is a hack to build with various configuration options.
# The intent is to check building combinations that normal testing doesn't use.

# Stuff goes into various test-* directories.
# Running again starts by deleting everything in the directory.

# set pipefail to catch pipeline failures
# Unfortunately, it doesn't work on some older sh-es
if /bin/sh -c "set -o pipefail"
then
  set -o pipefail
fi

LINUX=""
if [ `uname -s` = "Linux" -a -f /usr/include/seccomp.h ]
then
  # Not supported on CentOS 6
  LINUX="--enable-seccomp"
fi

doit ()
{
  DIR=test-$1
  [ ! -d $DIR ] && mkdir $DIR
  rm -rf $DIR/*
  ./waf configure --out=$DIR $2 2>&1 | tee    $DIR/test.log
  WAF1=$?
  WAF2=0
  WAF3=0
  if [ "$WAF1" = 0 ]
  then
  echo                           2>&1    | tee -a $DIR/test.log
  ./waf build                    2>&1    | tee -a $DIR/test.log
  WAF2=$?
  if [ "$WAF2" = 0 ]
  then
  echo                           2>&1    | tee -a $DIR/test.log
  ./waf check                    2>&1    | tee -a $DIR/test.log
  WAF3=$?
  fi
  fi
  if [ "$WAF1" != 0 -o "$WAF2" != 0 -o "$WAF3" != 0 ] 
  then
    echo                                  2>&1   | tee -a $DIR/test.log
    echo "Trouble with $DIR"              2>&1   | tee -a $DIR/test.log
  else
    echo -n "VERSION: "                   2>&1   | tee -a $DIR/test.log
    ./$DIR/main/ntpd/ntpd --version       2>&1   | tee -a $DIR/test.log
    echo -n "VERSION: "                   2>&1   | tee -a $DIR/test.log
    ./$DIR/main/ntpclients/ntpq --version 2>&1   | tee -a $DIR/test.log
    echo -n "VERSION: "                   2>&1   | tee -a $DIR/test.log
    ./$DIR/main/ntpclients/ntpdig --version 2>&1 | tee -a $DIR/test.log
    if [ `uname -s` != "NetBSD" ]
    then
      # no Python/curses on NetBSD
      echo -n "VERSION: "                 2>&1   | tee -a $DIR/test.log
      ./$DIR/main/ntpclients/ntpmon --version 2>&1 | tee -a $DIR/test.log
    fi
if [ "`which gpsmon 2>/dev/null`" != "" ]
then
    # needs GPSD library
    echo -n "VERSION: "                         2>&1 | tee -a $DIR/test.log
    ./$DIR/main/ntpclients/ntploggps --version  2>&1 | tee -a $DIR/test.log
fi
    echo -n "VERSION: "                         2>&1 | tee -a $DIR/test.log
    ./$DIR/main/ntpclients/ntplogtemp --version 2>&1 | tee -a $DIR/test.log
  fi
  echo
  echo
}

# no --disable-manpage on default and all
doit default ""
doit minimal "--disable-droproot --disable-dns-lookup --disable-mdns-registration --disable-manpage"

# This also tests refclocks without DEBUG
doit classic "--enable-classic-mode --refclock=all --disable-manpage"

doit all     "--enable-debug --enable-debug-gdb --enable-debug-timing --refclock=all --enable-lockclock --enable-leap-smear --enable-mssntp --enable-early-droproot $LINUX"

if [ "`which asciidoc 2>/dev/null`" != "" -a \
     "`which xsltproc 2>/dev/null`" != "" ]
then
doit doc     "--enable-doc --disable-manpage"
fi

# should try cross compile

echo
if [ `uname -s` = "Linux" -a ! -f /usr/include/seccomp.h ]
then
    echo
    echo "### Warning: Missing seccomp.h (on a Linux system)"
    echo
fi

if ! /bin/sh -c "set -o pipefail"
then
  echo "### old sh - no pipefail"
  echo "We can't test for errors"
  echo "###          You will have to scan the log files."
fi

echo "PYTHONPATH is" \"$PYTHONPATH\"
grep VERSION: test*/test.log
echo
grep warning:                    test*/test.log
grep error:                      test*/test.log
grep "The configuration failed"  test*/test.log
grep ^Trouble                    test*/test.log
echo
