# Owntracks-mqtt-tools

[owntracks.sh]  is used to parse MQTT Owntracks 'last Location' payload, and send remote device update request. 
 On Android devices, this script uses 'Termux-api' (Android term) for Location gathering, and is able to publish legit Location Owntracks payloads (seen in Owntracks app with proper infos).

#
This tool was first created to send a 'requestLocation' mqtt payload for a remote device to an Owntracks MQTT broker.

It can now do much more things :
- Show all topics your user have access to on the broker.
- Request location update to remote devices via your mqtt Broker.
- Parse last payload of specified device for easy reading (gmap link and approximate address conversion). 
- Generate current '_type:location' payload with 'termux-location' and publish it as legit Owntracks payload.
- Parse json Onwtracks file.

Required Apps : 'mosquitto' (for publish and subscribe), 'jq' (json parsing), 'ncat' (port testing)

Required for 'Publishing current Location' : Android phone with 'termux-api' (for location and battery info).

also require (for bash fancy output): 
https://github.com/zephxs/bash/tree/master/functions/01-myecho-colors.sh
#

+ Can use TLS Client Certificate or User-Password credentials for MQTT Broker authentication.

[ot-mqtt-pub.py]  was first used for MQTT publish. Leaved here for educational purpose.

