#!/usr/bin/env python
#
# fakemail2 - rewrite of Perl's fakemail in python
#
# Author: Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This file has been released to the public domain
#

from __future__ import print_function
import sys
import os
from optparse import OptionParser
#from tempfile import TemporaryFile
from smtpd import SMTPServer
from asyncore import loop
from time import ctime

VERSION = '1.1'

# Functions
class FakemailSMTPD(SMTPServer):
    def __init__(self, localaddr, remoteaddr, saveobj, logobj):
        self.capture = saveobj
        self.message = logobj
        SMTPServer.__init__(self, localaddr, remoteaddr)

    def process_message(self, peer, mailfrom, rcptto, data):
        self.message.log('Incoming mail')
        for recp in rcptto:
            self.message.log('Capturing mail to %s' % recp)
            self.capture.save(mailfrom, recp, data)
            self.message.log('Mail to %s saved' % recp)
        self.message.log('Incoming mail dispatched')

class LogIt(object):
    def __init__(self, logfile=None):
        if logfile:
            self.logfile = logfile + os.getpid()
            # Test-open
            with open(self.logfile, 'a'):
                pass
        else:
            self.logfile = None

    def log(self, message):
        msg = ctime() + ': ' + str(message)
        if self.logfile:
            with open(self.logfile, 'a') as log:
                log.write(msg)
        else:
            print(msg)

class SaveIt(object):
    def __init__(self, savepath):
        if not os.path.isdir(savepath):
            raise Exception('Savepath is not a directory: %s' % savepath)
        # TODO: Test-write, fail early on EACCESS
        self.path = savepath
        self.counts = {}

    def save(self, sender, recipient, data):
        msgfile = os.path.join(self.path, self.recp2file(recipient))
        with open(msgfile, 'w') as outf:
            outf.write('MAIL FROM: <%s>\nRCPT TO: <%s>\nDATA:\n%s\n' % (sender, recipient, data))

    def recp2file(self, recipient):
        for char in r'|<>&/\ ;!?':
            recipient = recipient.replace(char, '')
        self.counts[recipient] = self.counts.get(recipient, 0) + 1
        return '.'.join((recipient, str(self.counts[recipient])))

def main():
    process_opts = OptionParser(
        usage='Usage: %prog -H <hostname> -p <port> -P <log_path> [-l <log_file>] [-b]',
        version='%prog ' + VERSION
    )
    process_opts.add_option('-H', '--host', dest='host', help='Hostname/IP to listen on')
    process_opts.add_option('-p', '--port', type='int', dest='port', help='Port to listen on')
    process_opts.add_option('-P', '--path', dest='path', help='Directory to save emails into')
    process_opts.add_option('-l', '--log', dest='log', help='Optionnal file to append messages to')
    process_opts.add_option('-b', '--background', action='store_true', dest='background', help='Fork to background')

    (options, args) = process_opts.parse_args()
    if not options.host or not options.port or not options.path:
        process_opts.error('You must supply a host, port and path')
    if not os.path.isdir(options.path):
        process_opts.error('Path \'%s\' is not a directory' % options.path)
    if args:
        process_opts.error('Unexpected extra argument: %s' % args[0])

    # Fork to background if requested
    if options.background:
        try:
            if os.fork() > 0:
                os._exit(0)
        except OSError as err:
            print('Fork failed: %s (%d)' % (err.strerror, err.errno), file=sys.stderr)
            return False

        # See ya dad...
        for fdno in range(0, 3):
            try:
                os.close(fdno)
            except OSError:
                pass
        os.chdir(os.sep)
        os.umask(0o022)
        try:
            os.setsid()
        except Exception:
            pass

    message = LogIt(options.log)
    capture = SaveIt(options.path)

    # All set, lets go
    message.log('Starting fakemail')
    FakemailSMTPD((options.host, options.port), None, capture, message)
    loop(timeout=1, use_poll=True)
    message.log('Shutting down')

if __name__ == '__main__':
    sys.exit(not main())

