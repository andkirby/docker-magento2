#!/usr/bin/env python
###############################################################################
# Fetch list of ngrok tunnels
# USAGE
#  LIST ALL
#    $ ./ngrok.sh
#    https://27ffc5f2.ngrok.io => http://0.0.0.0:4693
#    http://27ffc5f2.ngrok.io => http://0.0.0.0:4693
#  LIST CERTAIN HOST
#    $ ./ngrok.sh 0.0.0.0:4693
#    https://27ffc5f2.ngrok.io
#    http://27ffc5f2.ngrok.io
#  ERROR HANDLING
#    If there is no hosts at all it will exit with code 8
###############################################################################

import json
import os
import sys

os.system("curl -sL http://localhost:4040/api/tunnels > /tmp/ngrok-tunnels.json")

try:
  with open('/tmp/ngrok-tunnels.json') as data_file:
    if data_file != '':
      datajson = json.load(data_file)
except ValueError:
  sys.exit(8)


app_host = ''
if len(sys.argv) > 1:
  app_host = str(sys.argv[1])

if datajson:
  for i in datajson['tunnels']:
    if app_host and str(app_host) in i['config']['addr']:
      print(i['public_url'])
    else:
      print(i['public_url'] + " => " + i['config']['addr'])
