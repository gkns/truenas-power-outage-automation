#!/bin/bash

# ================= Configuration =================
TRUENAS_IP="192.168.1.250"
ROUTER_1="192.168.1.49"
ROUTER_2="192.168.1.50"
MAC_ADDRESS="c8:ff:bf:05:77:c8"

# Time thresholds (in seconds)
CHECK_INTERVAL=60       # Check network status every 1 minute
REQUIRED_OFFLINE=300    # TrueNAS must be offline for 5 minutes continuously
REQUIRED_CHARGE=3600    # Require 1 hour (3600s) of continuous, stable grid power
# =================================================

OFFLINE_COUNTER=0

# Helper function to check if AT LEAST ONE router is online
check_grid_power() {
    if ping -c 1 -W 2 "$ROUTER_1" > /dev/null 2>&1 || ping -c 1 -W 2 "$ROUTER_2" > /dev/null 2>&1; then
        return 0 # True: Grid power is ON
    else
        return 1 # False: Grid power is OFF
    fi
}

echo "Starting Stateful TrueNAS Watchdog on PiKVM..."

while true; do
    # 1. Check if TrueNAS is alive
    if ping -c 1 -W 2 "$TRUENAS_IP" > /dev/null 2>&1; then
        OFFLINE_COUNTER=0
    else
        # TrueNAS is offline
        OFFLINE_COUNTER=$((OFFLINE_COUNTER + CHECK_INTERVAL))
        
        # 2. If TrueNAS has been offline long enough, look for grid power
        if [ "$OFFLINE_COUNTER" -ge "$REQUIRED_OFFLINE" ]; then
            
            if check_grid_power; then
                echo "$(date): Grid power detected! Entering 1-hour UPS charging phase..."
                
                CHARGE_TIMER=0
                
                # 3. The Validation Loop: Monitor power continuously for 1 hour
                while [ "$CHARGE_TIMER" -lt "$REQUIRED_CHARGE" ]; do
                    sleep "$CHECK_INTERVAL"
                    
                    if check_grid_power; then
                        CHARGE_TIMER=$((CHARGE_TIMER + CHECK_INTERVAL))
                        echo "$(date): Power stable for $CHARGE_TIMER / $REQUIRED_CHARGE seconds."
                    else
                        echo "$(date): ⚠️ Grid power dropped during charging phase! Aborting WOL and resetting timer."
                        break # Break out of the charging loop
                    fi
                done
                
                # 4. If we successfully reached 3600 seconds without breaking the loop
                if [ "$CHARGE_TIMER" -ge "$REQUIRED_CHARGE" ]; then
                    echo "$(date): 1 hour of stable power confirmed. Sending Wake-on-LAN to TrueNAS!"
                    
                    wol "$MAC_ADDRESS"
                    
                    # Sleep for 15 minutes to allow TrueNAS to fully boot before resuming monitoring
                    sleep 900 
                    OFFLINE_COUNTER=0
                fi
            else
                echo "$(date): TrueNAS offline, but grid power is still OUT. Waiting..."
            fi
        fi
    fi

    sleep "$CHECK_INTERVAL"
done