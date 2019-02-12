#!/usr/bin/env bash
[ $# -gt 0 ] || echo $0: need localhost port command-line argument 
SSHD_PORT=`expr $1 + 0` || exit $?

function set_sigusr1_received {
	sigusr1_received=1
}
trap set_sigusr1_received SIGUSR1
sigusr1_received=0

# Output our PID
echo $$

# Wait for SIGUSR1
while [ $sigusr1_received -eq 0 ] ; do
	sleep 0.5
done

# -h needed for non-root sshd
# -d sshd debugging mode: do not fork sshd
# UsePrivilegeSeparation=no do not fork process with connecting user's priv
exec `which sshd` -o UsePrivilegeSeparation=no \
                  -h ~/.ssh/id_rsa -d -p $SSHD_PORT 2>/dev/null
