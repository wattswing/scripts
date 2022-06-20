#!/bin/bash

##########################################################
# Sync Google domains DDNS with the machine's current one:
# https://support.google.com/domains/answer/6147083
# Will log current IP and logfiles in a /tmp/ddns/ folder
#
# Meant to be used with crontab, eg (every 10 minutes):
# */10 * * * * sh /root/ddns_sync.sh > /dev/null 2>&1
##########################################################

HOSTNAME="sub.domain.com"
LOGIN="LOGIN"
PASSWORD="PASSWORD"

# Sets ddns dir, make it and program files if needed
DDNS_DIR="/tmp/ddns"
LAST_IP_FILE="$DDNS_DIR/last_known_ip"
LOG_FILE="$DDNS_DIR/ddns-$HOSTNAME.log"
if [[ ! -d "$DDNS_DIR" ]]; then
  echo "Creating $DDNS_DIR and files"
  mkdir "$DDNS_DIR"
  touch "$LAST_IP_FILE" "$LOG_FILE"
  echo -e "`date` Init: create $DDNS_DIR dir\n`date` Created $LAST_IP_FILE and $LOG_FILE files" >> $LOG_FILE
fi

LAST_IP="$(cat $LAST_IP_FILE)"
PUBLIC_IP="$(curl -s https://domains.google.com/checkip)"
DDNS_CURRENT_IP=$(nslookup $HOSTNAME | awk '/^Address: / { print $2 }' | tail -n 1)

# Syncing only if (current WAN and local known IP) or (current WAN and ddns's current IP) differs
if [ "$PUBLIC_IP" != "$LAST_IP" ] || [ "$PUBLIC_IP" != "$DDNS_CURRENT_IP" ]; then
  echo "`date` Not same IP: syncing Google domain DDNS $HOSTNAME with IP $PUBLIC_IP" >> $LOG_FILE
  URL="https://$LOGIN:$PASSWORD@domains.google.com/nic/update?hostname=$HOSTNAME&myip=$PUBLIC_IP"
  RESP=$(curl -s $URL)
  case $RESP in
    "Good $PUBLIC_IP" | "nochg $PUBLIC_IP" )
    echo $PUBLIC_IP > $LAST_IP_FILE
    echo -e "`date` (Good / nochg): DDNS $HOSTNAME updated with IP $PUBLIC_IP" >> $LOG_FILE
      ;;
    "nohost" )
      echo "`date` Error The hostname $HOSTNAME doesn't exist, or doesn't have Dynamic DNS enabled." >> $LOG_FILE
      ;;
    "badauth" )
      echo "`date` Error The username/password combination isn't valid for the specified host $HOSTNAME." >> $LOG_FILE
      ;;
    "notfqdn" )
      echo "`date` Error The supplied hostname $HOSTNAME isn't a valid fully-qualified domain name." >> $LOG_FILE
      ;;
    "badagent" )
      echo "`date` Error Your Dynamic DNS client makes bad requests. Ensure that the user agent is set in the request." >> $LOG_FILE
      ;;
    "abuse" )
      echo "`date` Error Dynamic DNS access for the hostname $HOSTNAME has been blocked due to failure to interpret previous responses correctly." >> $LOG_FILE
      ;;
    "911" )
      echo "`date` Error An error happened on our end. Wait 5 minutes and retry." >> $LOG_FILE
      ;;
  esac
fi
