#!/bin/bash
#
# riemann-consul-receiver        Manage the consul-to-riemann receiver
#       
# chkconfig:   2345 95 95
# description: Feeds Consul check results to Riemann
# processname: riemann-consul-receiver
# config: /etc/sysconfig/riemann-consul-receiver
# pidfile: /var/run/riemann-consul-receiver.pid

### BEGIN INIT INFO
# Provides:       riemann-consul-receiver
# Required-Start: $local_fs $network
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start: 2 3 4 5
# Default-Stop:  0 1 6
# Short-Description: Manage the consul agent
# Description: Feeds Consul check results to Riemann
### END INIT INFO

# source function library
. /etc/rc.d/init.d/functions

prog="riemann-consul-receiver"
user="consul"
exec="/usr/bin/$prog"
pidfile="/var/run/$prog.pid"
lockfile="/var/lock/subsys/$prog"
logfile="/var/log/$prog"
conffile="/etc/sysconfig/$prog"

# pull in sysconfig settings
[ -e $conffile ] && . $conffile

export GOMAXPROCS=${GOMAXPROCS:-2}
export LOG_FILE="$logfile"

export RIEMANN_HOST
export RIEMANN_PORT
export RIEMANN_PROTO
export CONSUL_HOST
export CONSUL_PORT
export UPDATE_INTERVAL
export LOCK_DELAY
export DEBUG

start() {
    [ -x $exec ] || exit 5
    
    [ -f $conffile ] || exit 6

    umask 077

    touch $logfile $pidfile
    chown $user:$user $logfile $pidfile

    echo -n $"Starting $prog: "
    
    ## holy shell shenanigans, batman!
    ## go can't be properly daemonized.  we need the pid of the spawned process,
    ## which is actually done via runuser thanks to --user.
    ## you can't do "cmd &; action" but you can do "{cmd &}; action".
    daemon \
        --pidfile=$pidfile \
        --user=$user \
        " { $exec & } ; echo \$! >| $pidfile "
    
    RETVAL=$?
    # echo
    
    if [ $RETVAL -eq 0 ]; then
        touch $lockfile
        success
    else
        failure
    fi
    
    echo    
    return $RETVAL
}

stop() {
    echo -n $"Stopping $prog: "
    
    ## wait up to 10s for the daemon to exit
    count=0
    stopped=0
    pid=$( cat ${pidfile} )
    while [ $count -lt 10 ] && [ $stopped -ne 1 ]; do
        count=$(( count + 1 ))
        
        if ! checkpid ${pid} ; then
            stopped=1
        else
            sleep 1
        fi
    done
    
    if [ $stopped -ne 1 ]; then
        RETVAL=125
    fi
    
    if [ $RETVAL -eq 0 ]; then
        success
        rm -f $lockfile $pidfile
    else
        failure
    fi

    echo
    return $RETVAL
}

restart() {
    stop
    start
}

reload() {
    echo -n $"Reloading $prog: "
    killproc -p $pidfile $exec -HUP
    echo
}

force_reload() {
    restart
}

rh_status() {
    status -p "$pidfile" -l $prog $exec
    
    RETVAL=$?
    
    return $RETVAL
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
    start)
        rh_status_q && exit 0
        $1
        ;;
    stop)
        rh_status_q || exit 0
        $1
        ;;
    restart)
        $1
        ;;
    reload)
        rh_status_q || exit 7
        $1
        ;;
    force-reload)
        force_reload
        ;;
    status)
        rh_status
        ;;
    condrestart|try-restart)
        rh_status_q || exit 0
        restart
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload}"
        exit 2
esac

exit $?