#!/bin/bash

# Dependencies:
# curl (tested with v7.52.1)
# s-nail (tested with v14.9.11: https://git.sdaoden.eu/cgit/s-nail.git/tag/?h=v14.9.11 - v14.8.x gives an error)
#
# My setup: 
# 1. Script sends an email to a Gmail account
# 2. A Gmail rule (subject + sender) sends the message back to the sender
# 3. Script checks every 5 seconds if the email is received
# 4. Gives a alert via Pushover if needed
# 
# SETTINGS:

SMTPSERVER='[server]]:[port]'
IMAPSERVER='[server]]:[port]'
EMAILFROM='[mailtest@domain]'
EMAILFROMPASSWORD='[password]]'
EMAILTO='[emailaddress]'

MAXWAIT=300 # Send alert if email not received in xx seconds

# Pushover settings: https://pushover.net/api
POUSERKEY='[pushover user key]'
POTOKEN='[pushover application token]'
POMESSAGE='Er is een probleem met je mail!!'
PODEVICE=''

SNAIL=/usr/local/bin/s-nail

LOGLEVEL=0 #0: debug, 1: info, 2: error

####################


rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
    esac
    encoded+="${o}"
  done
  echo "${encoded}"
}

log() {
  local type="${1}"
  local message="${2}"
  echo $(date "+%Y-%m-%d %T")" [$type]: $message"
}

debug() {
  if [ $LOGLEVEL -eq 0 ]; then
    log "DEBUG" "${1}"
  fi
}

info() {
  if [ $LOGLEVEL -le 1 ]; then
    log "INFO" "${1}"
  fi
}

error() {
  if [ $LOGLEVEL -le 2 ]; then
    log "ERROR" "${1}"
  fi
}
echo "------------------------------------------"
info "Script started"

RND=$(date +%s | sha256sum | base64 | head -c 32)

EMAILFROMENC=$(rawurlencode $EMAILFROM)
EMAILFROMPASSWORDENC=$(rawurlencode $EMAILFROMPASSWORD)

debug "Sending email.."

result=$((echo $RND | $SNAIL \
-r $EMAILFROM \
-s "Testmail" \
-S smtp=$SMTPSERVER \
-S smtp-use-starttls \
-S smtp-auth=login \
-S smtp-auth-user=$EMAILFROM \
-S smtp-auth-password=$EMAILFROMPASSWORD \
-S ssl-verify=ignore \
$EMAILTO) 2>&1)
errorlevel=$?

debug "Result: '$result'. Error code: $errorlevel"

if [ $errorlevel -ne 0 ]; then
  error "Email couldn't be sent. S-nail returned with error code $errorlevel. Message: $result"
  exit
else
  info "Email successfully sent with body: $RND"
fi


EMAILFOUND="false"

loops=($MAXWAIT+4)/5

for i in {1..3}
do
  sleep 5
    
  debug "Checking inbox"

  result=$(($SNAIL \
  -S MAIL=imap://$EMAILFROMENC:$EMAILFROMPASSWORDENC@$IMAPSERVER \
  -S imap-use-starttls \
  -S v15-compat=true \
  -e -L "@body@$RND") 2>&1)
  errorlevel=$?

  debug "Result: '$result'. Error code: $errorlevel"

  if [ ! -z "$result" ]; then
    error "S-nail returned with error code $errorlevel. Message: $result"
    exit
  elif [ $errorlevel -eq 0 ]; then
    EMAILFOUND="true"
    break;
  fi

done

NOW=$(date "+%Y-%m-%d %T")

if [ "$EMAILFOUND" == "true" ]; then
  info "Email received, everything's OK"
else
  error "Email not received. Sending message via Pushover.."
  exit
  result=$((curl -s \
  --form-string "token=$POTOKEN" \
  --form-string "user=$POUSERKEY" \
  --form-string "device=$PODEVICE" \
  --form-string "message=$POMESSAGE" \
  https://api.pushover.net/1/messages.json) 2>&1)
  errorlevel=$?
    
  debug "Error code: $errorlevel"

  if [ $errorlevel -eq 0 ]; then
    info "Pushover API called. Result: $result"
  else
    error "Error by curl. Error code: '$errorlevel'. Message: $result"
  fi
fi