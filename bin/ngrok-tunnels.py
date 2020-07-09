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


class WorkException(Exception):
    code = 1

    def __init__(self, message, code=1):
        # Call the base class constructor with the parameters it needs
        if message:
            super(Exception, self).__init__(message)

        self.code = code


def read_tunnels():
    os.system("curl -sL http://localhost:4040/api/tunnels > /tmp/ngrok-tunnels.json")
    try:
        with open('/tmp/ngrok-tunnels.json') as data_file:
            if data_file != '':
                stream = json.load(data_file)
    except ValueError as e:
        raise WorkException('Cannot read tunnels', code=4)

    return stream


def requested_host():
    return str(sys.argv[1]) if len(sys.argv) > 1 else ''


def find_hosts(data, app_host):
    output = []
    for i in data['tunnels']:
        if app_host:
            if str(app_host) in i['config']['addr']:
                output.append(i['public_url'])
        else:
            output.append(i['public_url'] + " => " + i['config']['addr'])
    return output


# #################### Code #####################

e = None
try:
    print("\n".join(
        find_hosts(read_tunnels(), requested_host())
    ))

except WorkException as e:
    pass
except Exception as e:
    try:
        raise WorkException(str(e), code=3)
    except WorkException as e:
        pass

finally:
    if isinstance(e, Exception):
        import traceback

        sys.stderr.write(
            "Error: %s" % str(e)
        )
        sys.exit(e.code) if hasattr(e, 'code') else sys.exit(3)
    else:
        # no errors
        pass
