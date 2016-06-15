#!/bin/bash
#
# This is a simple script for monitoring whether PageKite is running, and
# restarting it if not.
#
export NOW=$(date +%s)
export WORKDIR="/tmp/pagekite-monitor.$$.$NOW"


###[ Settings ]################################################################

export DELAY=60      # Time to sleep between probes
export SILENT=false  # Replace with true to make cron-job silent
export CLEANUP=true  # Replace with false to leave junk in /tmp
export KITENAME=$(grep kitename /etc/pagekite.d/10_account.rc \
                 |head -1 \
                 |sed -e 's/ //g' \
                 |cut -f2 -d=)

# Set this to the empty string to disable uploading logs to pagekite.net
export CRASH_REPORT_URL='https://pagekite.net/cgi-bin/crashes.pl'

# This marker is used to make sure we only submit one crash-report per week,
# so we don't overload the crash-report server.
export CRASH_REPORTED=/tmp/crash-reported.wk$(date +%g)


###[ Functions ]###############################################################

function restart_pagekite {
  $SILENT || echo "Restarting PageKite..."

  # Kill with a fake segfault, to trigger core dumps
  kill -SEGV $(cat /var/run/pagekite.pid)

  # Save a compressed copy of the latest log file. We overwrite any
  # previous restart-log, to avoid filling up our disk.
  nice gzip </var/log/pagekite/pagekite.log >/root/pagekite-restart.log.gz

  # FIXME: Copy the core-dumps as well, add them to the tar archive below.

  # Upload the log (and any other details) to https://pagekite.net/, to
  # facilitate debugging. Be careful what you upload, as there may be
  # privacy concerns.
  if [ "$CRASH_REPORT_URL" != "" ]; then
    if ! [ -e $CRASH_REPORTED ]; then
      tar cf - /root/pagekite-restart.log.gz \
          2>/dev/null \
        |curl -s -X POST -H Expect: "$CRASH_REPORT_URL" \
              -F "data=@-;filename=$KITENAME-DOWN.tar" \
          > /dev/null \
        && {
          $SILENT || echo "Uploaded crash data to $CRASH_REPORT_URL"
        }
        touch $CRASH_REPORTED
    fi
  fi
}

 function report_happiness {
  $SILENT || echo 'Kite is flying, all is well!'
}

function pagekite_is_broken {
  rm -f probe.stdout probe.stderr
  curl -sv "https://$KITENAME/" >probe.stdout 2>probe.stderr
  # This will return True if the kite is reported as offline by the
  # front-end relay server.
  grep -e 'pagekite.net/offline/.*where=FE' probe.stdout >/dev/null
}

function cleanup {
  $CLEANUP && cd / && rm -rf $WORKDIR
}


###[ Main! ]###################################################################

# Safe boilerplate for creating a private temporary working directory
mkdir $WORKDIR && cd $WORKDIR && chmod 700 . && trap cleanup EXIT

# If broken 3 times in a row: save logs and restart
pagekite_is_broken && sleep $DELAY && \
  pagekite_is_broken && sleep $DELAY && \
    pagekite_is_broken && \
      restart_pagekite \
  || report_happiness \

# Always return a happy exit code
true
