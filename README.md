## PageKite Watchdog

This repository contains scripts and tools for running "watch dogs" that
monitoring running PageKites.

The general principle is to run a process on the same machine as PageKite
(pagekite.py or libpagekite) and perform end-to-end tests to see whether the
kites are flying correctly. If not, the watchdog takes corrective action.

At the moment, we only have one script. More may be added over time.


### Why use a watchdog?

If you are deploying devices to the field, your remote access may well depend
on PageKite. Although we obviously hope to find and fix any bugs in pagekite.py
and libpagekite, nothing is perfect. A watchdog is an inexpensive way to make
your system resilient to PageKite bugs.

If the automatic crash reporting is enabled, the watchdog will also help us
find and fix bugs more quickly.


### pagekite_watchdog.sh

This is a shell-script which will attempt to fetch (using HTTPS) the kite
listed in `/etc/pagekite.d/10_accounts.rc`. If the front-ends report that the
kite is unavailable, that tells us two things:

   1. The front-end relay servers *are reachable*
   2. Our kite is *not* flying

Given the assumption: "if the network is up, then our kite should be flying",
we can take this to mean PageKite has gotten into a bad state somehow, and try
to restart it.

The script will trigger a restart by killing PageKite with a SIGSEGV, which
will trigger a core dump (if the OS permits). The latest log files are then
harvested and uploaded to the PageKite.net crash report URL.

This script can probably be used as-is from root's crontab, on machines using
the `pagekite.py` Debian package. Other setups will probably need to customize
the restart logic and/or the kite-name detection code, at the very least.


### Design considerations

1. Health probes must differentiate between PageKite failing, and the network
failing. The simplest way to do this is to look at the response from the relay.

2. Care should be taken not to overload shared infrastructure; don't probe too
frequently, don't upload crash dumps every few minutes.

3. Even if PageKite appears broken, it may be worth giving it some time to
recover. An overly aggressive watchdog may itself cause or prolong outages
unnecessarily.

4. PageKite processes can be restarted in many ways. Since these restarts are
generally indicative of bugs in libpagekite or pagekite.py, it is useful to
perform the restart in such a way that it creates useful data for debugging;
core dumps or logs. Sharing that data with PageKite.net increases the odds that
bugs will get fixed.

5. When sharing data with PageKite.net, please be mindful of private user data.
Core dumps in particular, although extremely useful, may contain fragments of
user data, including usernames and passwords.

6. Embedded devices frequently use flash, and product designers often want to
minimize writes in order to extend the lifetime of their product.  This is all
well and good, but if you do this, please consider writing logs to a RAM disk
so they can be harvested when the watchdog detects a problem. Alternately, make
it possible for the watchdog to temporarily enable logging, so if a problem
persists it becomes more likely there will be logs available the second time it
occurs.
