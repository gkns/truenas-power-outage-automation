#!/bin/bash

# Target TrueNAS host and SSH parameters
TARGET="gkns@192.168.1.250"
SSH_OPTS="-o StrictHostKeyChecking=no -i /config/truenas_rsa"

# 1. Dispatch Email Alert via midclt
ssh $SSH_OPTS $TARGET "midclt call mail.send '{\"subject\": \"⚠️ TrueNAS Power Outage\", \"text\": \"Both Archer AX10 routers are unreachable. Initiating an automated shutdown sequence on TrueNAS.\"}'"

# 2. Give the SMTP engine 10 seconds to flush the queue
sleep 10

# 3. Initiate Shutdown via midclt
ssh $SSH_OPTS $TARGET 'midclt call system.shutdown {"reason":"Power Outage. Shutdown initiated by home assistant"}'