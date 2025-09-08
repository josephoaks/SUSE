#!/bin/bash
# Enhanced channel sync watcher for SMLM (SUSE Multi-Linux Manager / Uyuni)

INTERVAL=10
LINES=200
LOGDIR="/var/log/rhn/reposync"

# Filter only the interesting sync log lines
FILTER='Packages in repo|Packages already synced|Packages to sync|New packages to download|Downloading|Importing|Linking|Patches in repo|mediaproducts|[0-9]+/[0-9]+ : |Sync completed'

while true; do
    clear
    echo "=== $(date) ==="
    echo

    # Find the last "Syncing repos for channel" log entry from Taskomatic
    ACTIVE=$(mgrctl exec -- tail -n 500 /var/log/rhn/rhn_taskomatic_daemon.log | \
      grep "Syncing repos for channel:" | tail -n 1)

    if [ -z "$ACTIVE" ]; then
        echo ">> No active channel sync in progress"
    else
        # Reformat to "date/time - Syncing repos for channel: ..."
        FORMATTED=$(echo "$ACTIVE" | \
          sed -E 's/^([0-9-]+ [0-9:]+),[0-9]+ .* - (Syncing repos for channel:.*)/\1 - \2/')

        echo ">> Active channel:"
        echo "$FORMATTED"
        echo

        # Extract channel identifier (grab everything after "channel:")
        CHANNEL=$(echo "$ACTIVE" | sed -E 's/.*channel: (.*)/\1/')

        # Match reposync log file(s) for this channel
        LOGS=$(mgrctl exec -- ls -1t $LOGDIR | grep -i "$(echo $CHANNEL | awk '{print $1}')" | head -n 1)

        if [ -n "$LOGS" ]; then
            echo ">>> Watching $LOGS"
            mgrctl exec -- tail -n $LINES "$LOGDIR/$LOGS" | grep -E "$FILTER"
        else
            echo ">>> No matching reposync log found for channel: $CHANNEL"
        fi
    fi

    sleep $INTERVAL
done
