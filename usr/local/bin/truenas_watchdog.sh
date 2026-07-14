cat /usr/local/bin/truenas_watchdog.sh
#!/bin/bash

# ================= Configuration =================
TRUENAS_IP="192.168.1.250"
ROUTER_IP="192.168.1.50"
MAC_ADDRESS="c8:ff:bf:05:77:c8"

# Time thresholds (in seconds)
CHECK_INTERVAL=60       # Check network status every 1 minute
REQUIRED_OFFLINE=300    # TrueNAS must be offline for 5 minutes continuously
# =================================================

OFFLINE_COUNTER=0

echo "Starting TrueNAS Watchdog on PiKVM..."

while true; do
    # Check if TrueNAS is alive
    if ping -c 1 -W 2 "$TRUENAS_IP" > /dev/null 2>&1; then
        # TrueNAS is online, reset our counter
        OFFLINE_COUNTER=0
    else
        # TrueNAS is offline, increment the counter by the interval time
        OFFLINE_COUNTER=$((OFFLINE_COUNTER + CHECK_INTERVAL))
        echo "TrueNAS is offline. Continuous offline time: $OFFLINE_COUNTER seconds."
        
        # If TrueNAS has been offline long enough, check if power is back
        if [ "$OFFLINE_COUNTER" -ge "$REQUIRED_OFFLINE" ]; then
            echo "TrueNAS offline threshold reached. Checking grid power status via router..."
            
            # Ping the wall-connected router to see if utility power is back
            if ping -c 1 -W 2 "$ROUTER_IP" > /dev/null 2>&1; then
                echo "Grid power confirmed ON (Router is reachable). Sending Wake-on-LAN to TrueNAS!"
                
                # Send the WOL packet
                wol "$MAC_ADDRESS"
                
                # Sleep for 10 minutes to allow TrueNAS to fully boot before checking again
                sleep 600
                OFFLINE_COUNTER=0
            else
                echo "Grid power is still OUT (Router is unreachable). Standing down."
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done