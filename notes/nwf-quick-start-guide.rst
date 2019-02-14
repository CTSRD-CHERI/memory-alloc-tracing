Go fetch some dependencies::

  pkg install bash sudo py36-pyelftools-0.25 py36-sortedcontainers-2.1.0

Enable in-kernel resource accounting (and reboot)::

  echo 'kern.racct.enable=1' >> /boot/loader.conf

Point an environment variable at this project::

  setenv M /mnt/memory-alloc-tracing

Make sure you have git submodules working (if you cloned ``--recursive`` you
can probably skip these steps)::

  git submodule init
  git submodule update --recursive

Patch and rebuild various parts of the FreeBSD system::

  (cd /usr/src; for i in $M/deps/*/patch-*; do patch -p3 -C < $i; done)
  (cd /usr/src; for i in $M/deps/*/patch-*; do patch -p3 < $i; done)

  (cd /usr/src; make buildkernel installkernel)
  (cd /usr/src/cddl/lib/libdtrace; make all install)
  (cd /usr/src/cddl/usr.sbin/dtrace; make all install)

Run an example workload.  For sshd we require a little more setup::

  ssh-keygen -f ~/.ssh/id_rsa # used by workload to log in
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
    # if you are running as root, make sure sshd will let you in
    # i.e. that PermitRootLogin is either yes or without-password

  $M/run.sh $M/run-config/config-sshd

Having done all that, the central result is in
``runs/.../sshd-run-info-...``, with the ellipses hiding run date stamps.
This file is ready for running through the model or simulator.

Running Chromium is more involved.  The environment on the
host ``nikola01`` can help
if you're here at Cambridge; otherwise, you'll have to figure out how to
build Chromium from source using the patches provided.

Copy a suitable chromium build to ``$HOME``, which means, for example,
grabbing Lucian's, as well as a copy of the LayoutTests::

  tar -xzvf ~lmp53/chromium-65-more-malloc.tar.gz
  cp -a /home/lmp53/LayoutTests $M/workload/chromium/LayoutTests

Anyway, having gotten that set up::

  Xvfb :2
  export DISPLAY=:2
  ./run.sh run-config/config-chromium_jemalloc 

Chrome / selenium is a little flaky; don't be surprised if it crashes
and so needs several runs through to completion. :(
