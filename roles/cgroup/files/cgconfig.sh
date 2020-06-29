#! /bin/sh
### BEGIN INIT INFO
# Provides:          cgconfig
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Load cgroup configuration
# Description:       Loads cgconfig.conf and creates cgroup layout based on it
### END INIT INFO

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="CGroups Config Parser"
NAME=cgconfig
CONFIG_FILE=/etc/cgconfig.conf
CREATE_DEFAULT=yes
DAEMON=/usr/sbin/cgconfigparser
LOCK_FILE=/run/lock/$NAME
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

# Create default group and place all processes in it by default

create_default_groups() {
        DEFAULTCGROUP=

        if [ -f /etc/cgrules.conf ]
        then
            grep -m1 '^\*[[:space:]]\+' /etc/cgrules.conf | read USR CTRL DEFAULTCGROUP
            if [ -n "$DEFAULTCGROUP" -a "$DEFAULTCGROUP" = "*" ]
            then
                [ "$VERBOSE" != no ] && log_warning_msg "/etc/cgrules.conf incorrect"
                [ "$VERBOSE" != no ] && log_warning_msg "Overriding it"
                DEFAULTCGROUP=
            fi
        fi

        if [ -z $DEFAULTCGROUP ]
        then
            DEFAULTCGROUP=sysdefault/
        fi

        #
        # Find all mounted subsystems and create comma-separated list
        # of controllers.
        #
        CONTROLLERS=`lssubsys 2>/dev/null | tr '\n' ',' | sed s/.$//`

        #
        # Create the default group, ignore errors when the default group
        # already exists.
        #
        cgcreate -g $CONTROLLERS:$DEFAULTCGROUP 2>/dev/null

        #
        # special rule for cpusets
        #
        if echo $CONTROLLERS | grep -q -w cpuset; then
                CPUS=`cgget -nv -r cpuset.cpus /`
                cgset -r cpuset.cpus=$CPUS $DEFAULTCGROUP
                MEMS=`cgget -nv -r cpuset.mems /`
                cgset -r cpuset.mems=$MEMS $DEFAULTCGROUP
        fi

        #
        # Classify everything to default cgroup. Ignore errors, some processes
        # may exit after ps is run and before cgclassify moves them.
        #
        cgclassify -g $CONTROLLERS:$DEFAULTCGROUP `ps --no-headers -eL o tid` \
                 2>/dev/null || :
}

#
# Function that starts the daemon/service
#
do_start()
{
        # Return
        #   0 if daemon has been started
        #   1 if daemon was already running
        #   2 if daemon could not be started
        if [ -f $LOCK_FILE ]
        then
            [ "$VERBOSE" != no ] && log_warning_msg "lock file already exists"
            return 1
        fi

        if [ $? -eq 0 ]
        then
                $DAEMON -l $CONFIG_FILE
                retval=$?
                if [ $retval -ne 0 ]
                then
                    [ "$VERBOSE" != no ] && log_failure_msg "Failed to parse " $CONFIG_FILE
                    return 2
                fi
        fi

        if [ $CREATE_DEFAULT = "yes" ]
        then
                create_default_groups
        fi

        touch $LOCK_FILE
        retval=$?
        if [ $retval -ne 0 ]
        then
            [ "$VERBOSE" != no ] && log_failure_msg "Failed to touch " $LOCK_FILE
            return 2
        fi
}

#
# Function that stops the daemon/service
#
do_stop()
{
        # Return
        #   0 if daemon has been stopped
        #   1 if daemon was already stopped
        #   2 if daemon could not be stopped
        #   other if a failure occurred
        cgclear
        rm -f $LOCK_FILE
        return 0
}

trapped() {
        #
        # Do nothing
        #
        true
}

common() {
        #
        # main script work done here
        #
        trap "trapped ABRT" ABRT
        trap "trapped QUIT" QUIT
        trap "trapped TERM" TERM
        trap "trapped INT"   INT
}

common

case "$1" in
  start)
        [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
        do_start
        case "$?" in
                0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
                2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
        esac
        ;;
  stop)
        [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
        do_stop
        case "$?" in
                0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
                2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
        esac
        ;;
  status)
        if [ -f $LOCK_FILE ] ; then
            log_success_msg "$NAME is running"
            exit 0
        else
            log_failure_msg "$NAME is not running"
            exit 1
        fi
        ;;
  restart|force-reload)
        #
        # If the "reload" option is implemented then remove the
        # 'force-reload' alias
        #
        log_daemon_msg "Restarting $DESC" "$NAME"
        do_stop
        case "$?" in
          0|1)
                do_start
                case "$?" in
                        0) log_end_msg 0 ;;
                        1) log_end_msg 1 ;; # Old process is still running
                        *) log_end_msg 1 ;; # Failed to start
                esac
                ;;
          *)
                # Failed to stop
                log_end_msg 1
                ;;
        esac
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
        exit 3
        ;;
esac

:
 cgred.sh
#! /bin/sh
### BEGIN INIT INFO
# Provides:          cgred
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: CGroups Rules Engine Daemon
# Description:       This is a daemon for automatically classifying processes
#                    into cgroups based on UID/GID.
### END INIT INFO

# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="CGroups Rules Engine Daemon"
NAME=cgred
DAEMON=/usr/sbin/cgrulesengd
DAEMON_ARGS=""
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
if [ -r /etc/default/$NAME ]
then
        . /etc/default/$NAME
        DAEMON_ARGS="$NODAEMON $LOG"
        if [ -n "$LOG_FILE" ]
        then
                DAEMON_ARGS="$DAEMON_ARGS --log-file=$LOG_FILE"
        fi
fi

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
        # Return
        #   0 if daemon has been started
        #   1 if daemon was already running
        #   2 if daemon could not be started
        start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
                || return 1
        start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- \
                $DAEMON_ARGS \
                || return 2
}

#
# Function that stops the daemon/service
#
do_stop()
{
        # Return
        #   0 if daemon has been stopped
        #   1 if daemon was already stopped
        #   2 if daemon could not be stopped
        #   other if a failure occurred
        start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $NAME
        RETVAL="$?"
        [ "$RETVAL" = 2 ] && return 2
        # Wait for children to finish too if this is a daemon that forks
        # and if the daemon is only ever run from this initscript.
        # If the above conditions are not satisfied then add some other code
        # that waits for the process to drop all resources that could be
        # needed by services started subsequently.  A last resort is to
        # sleep for some time.
        start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
        [ "$?" = 2 ] && return 2
        # Many daemons don't delete their pidfiles when they exit.
        rm -f $PIDFILE
        return "$RETVAL"
}

case "$1" in
  start)
        [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
        do_start
        case "$?" in
                0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
                2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
        esac
        ;;
  stop)
        [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
        do_stop
        case "$?" in
                0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
                2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
        esac
        ;;
  status)
        status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
        ;;
  restart|force-reload)
        log_daemon_msg "Restarting $DESC" "$NAME"
        do_stop
        case "$?" in
          0|1)
                do_start
                case "$?" in
                        0) log_end_msg 0 ;;
                        1) log_end_msg 1 ;; # Old process is still running
                        *) log_end_msg 1 ;; # Failed to start
                esac
                ;;
          *)
                # Failed to stop
                log_end_msg 1
                ;;
        esac
        ;;
  *)
        echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
        exit 3
        ;;
esac

: