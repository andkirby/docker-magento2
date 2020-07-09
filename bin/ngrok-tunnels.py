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
    ERR_COMMON = 3
    ERR_BAD_TUNNELS = 4
    ERR_NO_HOST = 5

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
        raise WorkException('Cannot read tunnels', code=WorkException.ERR_BAD_TUNNELS)

    return stream


def requested_host():
    return str(sys.argv[1]).replace('0.0.0.0', 'localhost') if len(sys.argv) > 1 else ''


def find_hosts(data, app_host, proto='https'):
    output = []
    for i in data['tunnels']:
        if app_host:

            if str(app_host) in i['config']['addr'] and proto in i['public_url']:
                output.append(i['public_url'])
        else:
            output.append(i['public_url'] + " => " + i['config']['addr'])

    if app_host and not len(output):
        raise WorkException("Host %s not found." % app_host, code=WorkException.ERR_NO_HOST)

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
        raise WorkException(str(e), code=WorkException.ERR_COMMON)
    except WorkException as e:
        pass

finally:
    if isinstance(e, Exception):
        import traceback

        sys.stderr.write(
            "Error: %s" % str(e)
        )
        sys.exit(e.code) if hasattr(e, 'code') else sys.exit(WorkException.ERR_COMMON)
    else:
        # print(str(e))
        # no errors
        pass
