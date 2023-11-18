# Owntracks-mqtt-tools

Toolset first created to send 'requestLocation' mqtt payload to ask device to update when it gets up. 
Can now do much more things :
- Request location update to devices via your mqtt Broker.
- Parse last payload of specified device for easy reading (gmap link and approximate address conversion). 
- Generate your own '_type:location' payload with 'termux-location' and publish it as legit Owntracks payload

Required Apps : 'mosquitto_sub', 'mosquitto_sub', 'jq', 'nc' (for port testing)
Required for 'publish' : 'termux-app' for location and battery gathering, python3 with paho-mqtt

Can use TLS Client Certificate MQTT Broker authentication or User-Password credentials.
