#!/usr/bin/env python
##### Private MQTT Publisher
### v0.3 - added args parse and load
### v0.2 - added certificate auth to broker
### v0.1 - Parse and Publish location payload POC

import paho.mqtt.client as mqtt
import ssl, time, inspect, os, sys, argparse

print('# Python MQTT TLS Publisher')

# Argument parser set
parser = argparse.ArgumentParser()
parser.add_argument('-b', '--broker', help='Broker')
parser.add_argument('-p', '--port', help='Port')
parser.add_argument('-u', '--user', help='User')
parser.add_argument('-P', '--passw', help='Password')
parser.add_argument('-a', '--cafile', help='CaFile')
parser.add_argument('-c', '--cert', help='Cert')
parser.add_argument('-k', '--key', help='Key')
parser.add_argument('-t', '--topic', help='Topic')
parser.add_argument('-j', '--json', help='Json')

# Get command-line arguments
args = parser.parse_args()
broker_address = args.broker
broker_port = args.port
broker_user = args.user
broker_pass = args.passw
broker_cafile = args.cafile
broker_cert = args.cert
broker_key = args.key
broker_topic = args.topic
json_file_path = args.json
int_port=int(broker_port)

# Test if required variables are set
if broker_pass is not None and broker_user is not None:
    user_connection=True
    cert_connection=False
if broker_cafile is not None and broker_cert is not None and broker_key is not None:
    user_connection=False
    cert_connection=True
if cert_connection is None and user_connection is None:
    print("# Connexion Details Missing.. exit")
    sys.exit(1)

# Message to publish
if not os.path.exists(json_file_path):
    print(f"# Json file '{json_file_path}' does not exist.. exit")
    sys.exit(1)
with open(json_file_path, 'r') as file:
    json_string = file.readline()

# set broker TLS or user auth
client = mqtt.Client("mqttclient")
if cert_connection:
    client.tls_set(ca_certs=broker_cafile, certfile=broker_cert, keyfile=broker_key, cert_reqs=ssl.CERT_REQUIRED, tls_version=ssl.PROTOCOL_TLSv1_2)
    client.tls_insecure_set(False)
    print( "# Broker [mauth=certificate]" )
if user_connection:
    client.username_pw_set(username = broker_user, password = broker_pass)
    print( "# Broker [auth=user+pass]:", broker_address )

# connect and subscribe
client.connect( broker_address, int_port, 60 )
client.loop_start()
print( "# Topic:", broker_topic )
client.subscribe( broker_topic )
print( "# Publish Location Payload" )
client.publish( broker_topic, json_string, retain=True )
time.sleep( 1 )
client.loop_stop()

