#!/bin/bash
##### Owntracks MQTT Broker tools
##### Request location update to devices via mqtt,
##### Parse last payload of specified device, 
##### Generate your own '_type:location' payload with 'termux-location' and publish
### v0.8 - rework log parser hability to parse any json file containing owntracks location payload
### v0.7 - Rework and full link with python publisher
### v0.6 - added hability to publish 'termux-location' as owntracks json payload to broker
# Required Apps : mosquitto_sub, jq, nc (for port testing)
# Required for 'publish' : termux-app for location gather, ot-mqtt-pub.py script and python3 with paho-mqtt

### VARS : update connection info and tmp folder
# certificate auth will have precedence over user+pass
_MQTTHOST="my.broker.com"
_MQTTPORT="8883"
# MQTT Auth infos (Certificate auth or User+Pass)
_MQTTUSER=''
_MQTTPASS=''
_MQTTCAFILE="$HOME/mqttcerts/ca-chain.cert.pem"
_MQTTCERT="$HOME/mqttcerts/client.crt"
_MQTTKEY="$HOME/mqttcerts/client.key"
_TMPFOLDER='/data/data/com.termux/files/usr/tmp'

# Publish vars (Use your Owntracks User ID and topic)
_MQTTTOPIC="owntracks/user/device"
_TID="ZE"

# other vars
_LOGFILE="$HOME/logs/termloc.json"
_LOCLOGFILE="$HOME/logs/termloc.log"
_PAYLOAD="$HOME/logs/termloc.payload"
_VERS=$(awk '/### v/ {print $0; exit}' $basename $0 |awk '{print $2}')
_LISTLOCATION=''
_REQUESTLOCATION=''
_PUBLISHLOCATION=''
_GETTOPICS=''
_VERBOSE=''
_JSONTOPARSE=''
_MAPSONLY=''

# Color and output
type _MYECHO >/dev/null 2>&1 || . ${PREFIX}/etc/profile.d/01-myecho-colors.sh >/dev/null 2>&1
_LINELENGH="56"


# Usage
_FNUSAGE(){ echo "# Onwtracks broker tool $_VERS
# Request Location Update or parse  payload

Usage:
-p|--publish            # Generate and Publish 'termux-location' payload
-u|--user 'UserName'    # Owntracks client [Mandatory with 'list' and 'request'].
-r|--request            # Request: Send a 'reportLocation' next time device is up.
-l|--list               # List: parse last payload [DEFAULT].
-m|--maps               # List: only parse and get gmaps link. 
-n|--noaddress          # List: but do not search Approximate Address via Maps.co. 
-j|--json 'file.json'   # Parse any Owntracks JSon file.
-g|--get                # Get all Owntracks topics.
-v|--verbose            # List: print raw json payload.
-h|--help               # This Help

Ex:
Parse last Location     : $(basename $0) -u username
Request Device Update   : $(basename $0) -u username -r
Publish Location        : $(basename $0) -p
"; }


# Args
while (($#)); do
  case $1 in
    -p|--publish) _PUBLISHLOCATION="yes"; shift 1 ;;
    -j|--json)
          if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            [ -f "$2" ] && { _PARSEJSON='yes'; _JSONTOPARSE=$2 ; }; shift 2
          else
            _MYECHO -c red -s "Json $2 not found, exit.."; exit 1
          fi
          ;;
    -u|--user)
          if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            _USER=$2; shift 2
          else
            _MYECHO -c red -s "User $_USER not found, exit.."; exit 1
          fi
          ;;
    -r|--request) _REQUESTLOCATION='yes'; shift 1 ;;
    -g|--get) _GETTOPICS='yes'; shift 1 ;;
    -l|--list) _LISTLOCATION='yes'; shift 1 ;;
    -v|--verbose) _VERBOSE='yes'; shift 1 ;;
    -m|--maps) _MAPSONLY='yes'; shift 1 ;;
    -n|--noaddress) _SEARCHLOC='no'; shift 1 ;;
    -h|--help) _FNUSAGE && exit 0 ;;
    *) _MYECHO -c red -p "# Arg  not recognised.." && _FNUSAGE && exit 1 ;;
  esac
done

_MYECHO -t "Owntracks Broker tool $_VERS"
_MYECHO "Broker" && echo "$_MQTTHOST"
# Set Connexion infos
if [ -n "$_MQTTUSER" -a -n "$_MQTTPASS" ]; then
  _CONNECTIONINFO=(-h $_MQTTHOST -p $_MQTTPORT -u $_MQTTUSER -P "$_MQTTPASS")
elif [ -n "$_MQTTCAFILE" -a -n "$_MQTTCERT" -a -n "$_MQTTKEY" ]; then
  _CONNECTIONINFO=(-h $_MQTTHOST -p $_MQTTPORT --cafile "${_MQTTCAFILE}" --cert "${_MQTTCERT}" --key "${_MQTTKEY}")
else
  _MYECHO -c red -s "Connection Info incomplete.. exit"
  exit 1
fi
# Test connection to broker via 'ncat' (needed)
if ! type -P ncat &>/dev/null; then
  _MYECHO -c red -s "# 'ncat' not found.. exit"
  exit 1
elif ! ncat -zvw1 "${_CONNECTIONINFO[1]}" "${_CONNECTIONINFO[3]}" &>/dev/null; then
  _MYECHO -c red -s "# No route to Broker.. exit"; exit 1
fi
# Test credentials to broker
mosquitto_sub "${_CONNECTIONINFO[@]}" -t "owntracks/#" -v -W 1  &>/dev/null  >${_TMPFOLDER}/.mqtt-test
[ -s "${_TMPFOLDER}/.mqtt-test" ] || { _MYECHO -c red -p "Broker rejected credentials.. exit"; exit 1; }
# Get topics (user check not needed)
if [ "$_GETTOPICS" = 'yes' ]; then
  _MYECHO -s "Topics:"
  awk '$1 !="" {print $1}' ${_TMPFOLDER}/.mqtt-test
  exit 0
fi
# Set 'list' as default if no argument apart user
[ -z "$_LISTLOCATION" -a -z "$_REQUESTLOCATION" -a -z "$_PUBLISHLOCATION" ] && _LISTLOCATION='yes'

### FUNCTIONS
_USERCHECK(){
[ -z "$_USER" ] && { _MYECHO -c red -p "Needs a Username.. exit"; exit 1; }
awk '{print $1}' ${_TMPFOLDER}/.mqtt-test |grep -q "$_USER" || { \
_MYECHO "User" && _KO ":$_USER"
_MYECHO -c red -s "is not a valid MQTT User.."
_MYECHO -c red -s "type: \"$(basename $0) -g\" to get available Users Topics"
exit 1
}
}

_REQUESTOR(){
_USERCHECK
_LASTMODTIME=$(grep "$_USER" ${_TMPFOLDER}/.mqtt-test |awk '{$1=""; print $0}' |jq .tst)
_MYECHO "User" && echo "$_USER"
_MYECHO "Last Update" && date -d @"$_LASTMODTIME" +"%d/%m/%Y %T"
mosquitto_pub "${_CONNECTIONINFO[@]}" -t "owntracks/user/$_USER/cmd" -m '{"_type":"cmd", "action":"reportLocation"}'
_MYECHO "Request Location" && _OK
echo
}

_LOCPARSER(){
# Set vars from mqtt payload
_LASTMODTIME=$(jq .tst <${_JSONTOPARSE})
_LATTITUDE=$(jq .lat <${_JSONTOPARSE})
_LONGITUDE=$(jq .lon <${_JSONTOPARSE})
if [ "$_MAPSONLY" = 'yes' ]; then
_MYECHO "Last Update" && date -d @"$_LASTMODTIME" +"%d/%m/%Y %T"
_MYECHO "Maps Link" && echo "https://www.google.fr/maps/@${_LATTITUDE},${_LONGITUDE},18z?entry=ttu"
exit 0
fi
_ALTITUDE=$(jq .alt <${_JSONTOPARSE})
_PRECISION=$(jq .acc <${_JSONTOPARSE})
_BATTERY=$(jq .batt <${_JSONTOPARSE})
_NETACCESS=$(jq .conn <${_JSONTOPARSE})
[ "$_NETACCESS" = '"w"' ] && _NETWORK='Wifi'
[ "$_NETACCESS" = '"m"' ] && _NETWORK='Mobile'
[ "$(jq [.inregions] -c <${_JSONTOPARSE})" = '[null]'  ] && _INREGION='' || _INREGION=$(jq .inregions[] -c  <${_JSONTOPARSE})
[ "$(jq .tag  <${_JSONTOPARSE})" = 'null'  ] && _OTAG='Owntracks' || _OTAG=$(jq .tag  <${_JSONTOPARSE} |tr -d '"')
# Print results
_MYECHO "Last Update" && date -d @"$_LASTMODTIME" +"%d/%m/%Y %T"
_MYECHO "Lattitude" && echo "$_LATTITUDE"
_MYECHO "Longitude" && echo "$_LONGITUDE"
_MYECHO "Altitude" && echo "${_ALTITUDE}m"
_MYECHO "Precision" && echo "${_PRECISION}m"
_MYECHO "Battery" && echo "${_BATTERY}%"
_MYECHO "Network" && echo "$_NETWORK"
_MYECHO "Tag" && echo "$_OTAG"
[ ! -z "$_INREGION" ] && _MYECHO "Place" && echo "$_INREGION"
_MYECHO "Maps Link" && echo "https://www.google.fr/maps/@${_LATTITUDE},${_LONGITUDE},18z?entry=ttu"
# noaddress option
if [ -z "$_SEARCHLOC" ]; then
  _MYECHO "Approx. Address"
  curl -s -o - "https://geocode.maps.co/reverse?lat=${_LATTITUDE}&lon=${_LONGITUDE}" |jq .display_name
fi
# Verbose option show raw mqtt payload
[ "$_VERBOSE" = 'yes' ] && _MYECHO -p "Raw payload:" && jq <${_JSONTOPARSE}
echo
}

_PUBLISHER(){
type -P termux-location &>/dev/null ||  { _MYECHO -c red -s "termux-location not available.. exit"; exit 1; }
_CREATED_AT=$(date +%s)
# Get Termux-location output
_MYECHO "Get Current Location"
termux-location >${_LOCLOGFILE}
[ -s "${_LOCLOGFILE}" ] && _OK || { _KO "# Location Report Failed.."; exit 1; }
_LATITUDE=$(jq .latitude  <${_LOCLOGFILE})
_LONGITUDE=$(jq .longitude  <${_LOCLOGFILE})
_ACCURACY=$(printf "%.0f" $(jq .accuracy  <${_LOCLOGFILE}))
_ALTITUDE=$(printf "%.0f" $(jq .altitude  <${_LOCLOGFILE}))
_VELOCITY=$(printf "%.0f" $(jq .speed  <${_LOCLOGFILE}))
_VACC=$(printf "%.0f" $(jq .vertical_accuracy  <${_LOCLOGFILE}))
# Battery
_BATTERYSTATUS=$(termux-battery-status |jq .percentage)
# Format the json payload
echo "{
  \"_type\": \"location\"," >${_LOGFILE}
if [ "$(termux-wifi-connectioninfo |jq .bssid)" != 'null' ]; then
  _WIFIBSSID=$(termux-wifi-connectioninfo |jq .bssid)
  _WIFISSID=$(termux-wifi-connectioninfo |jq .ssid)
  echo "  \"BSSID\": ${_WIFIBSSID}," >>${_LOGFILE}
  echo "  \"SSID\": ${_WIFISSID}," >>${_LOGFILE}
fi
echo "  \"acc\": ${_ACCURACY}," >>${_LOGFILE}
echo "  \"alt\": ${_ALTITUDE}," >>${_LOGFILE}
echo "  \"batt\": $_BATTERYSTATUS," >>${_LOGFILE}
# Battery uncharging state : see later
echo '  "bs": 1,' >>${_LOGFILE}
if [ "$(termux-wifi-connectioninfo |jq .bssid)" = 'null' ]; then
  echo '  "conn": "m",' >>${_LOGFILE}
else
  echo '  "conn": "w",' >>${_LOGFILE}
fi
echo "  \"created_at\": $(date +%s)," >>${_LOGFILE}
echo "  \"lat\": ${_LATITUDE}," >>${_LOGFILE}
echo "  \"lon\": ${_LONGITUDE}," >>${_LOGFILE}
# send payload as significatn move
echo '  "m": 1,' >>${_LOGFILE}
# set as User update request
echo '  "t": "u",' >>${_LOGFILE}
echo "  \"tid\": \"$_TID\"," >>${_LOGFILE}
echo "  \"tst\": $_CREATED_AT," >>${_LOGFILE}
echo "  \"vac\": ${_VACC}," >>${_LOGFILE}
echo "  \"vel\": ${_VELOCITY}," >>${_LOGFILE}
echo "  \"tag\": \"Termux\"" >>${_LOGFILE}
echo '}' >>${_LOGFILE}
# move to json compact format
jq -c <${_LOGFILE} >${_PAYLOAD}
# send the payload with mqtt-pub.py
_MYECHO "Send Payload"
mosquitto_pub "${_CONNECTIONINFO[@]}" -r -t "${_MQTTTOPIC}" -f "${_PAYLOAD}" && _OK || _KO

# Old python script call
#if [ -z "$_MQTTUSER" ]; then
#python3 ${_PUBSCRIPT} -b "$_MQTTHOST" -p "$_MQTTPORT" -a "$_MQTTCAFILE" -c "$_MQTTCERT" -k "$_MQTTKEY" -t "$_MQTTTOPIC" -j "$_PAYLOAD"
#else
#python3 ${_PUBSCRIPT} -b "$_MQTTHOST" -p "$_MQTTPORT" -u "$_MQTTUSER" -P "$_MQTTPASS" -t "$_MQTTTOPIC" -j "$_PAYLOAD" 
#fi

}

### MAIN
if [ "$_REQUESTLOCATION" = 'yes' ]; then
_REQUESTOR
elif [ "$_PUBLISHLOCATION" = 'yes' ]; then
_PUBLISHER
elif [ "$_PARSEJSON" = 'yes' ]; then
_MYECHO "Json file" && echo "$_JSONTOPARSE"
_LOCPARSER
elif [ "$_LISTLOCATION" = 'yes' ]; then
_USERCHECK
_MYECHO "User" && echo "$_USER"
mosquitto_sub "${_CONNECTIONINFO[@]}" -t "owntracks/user/$_USER" -W 1  &>/dev/null  >${_TMPFOLDER}/.mqtt-tmp-request
_JSONTOPARSE="${_TMPFOLDER}/.mqtt-tmp-request"
_LOCPARSER
fi

