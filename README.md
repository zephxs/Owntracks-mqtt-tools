# Owntracks-mqtt-tools

[owntracks.sh]  is used to parse MQTT Owntracks Location payload, and send update request. 

[ot-mqtt-pub.py]  is used for MQTT publish and 'Termux' (Android term) for Location gather, all can publish legit Location Owntracks payloads.
#
This tool was first created to send a 'requestLocation' mqtt payload for a remote device to an Owntracks MQTT broker.

It can now do much more things :
- Show all topics your user have access to on the broker.
- Request location update to remote devices via your mqtt Broker.
- Parse last payload of specified device for easy reading (gmap link and approximate address conversion). 
- Generate own '_type:location' payload with 'termux-location' and publish it as legit Owntracks payload.

Required Apps : 'mosquitto_sub', 'jq' (json parsing), 'ncat' (port testing)

Required for 'publish' : Python3 with paho-mqtt library (pip install paho-mqtt), and 'termux-api' (for location and battery).

also require : 
https://github.com/zephxs/bash/tree/master/functions/01-myecho-colors.sh
for fancy output !
#
*Can use TLS Client Certificate MQTT Broker authentication or User-Password credentials.
