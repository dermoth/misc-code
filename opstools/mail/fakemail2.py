#!/usr/bin/env python
#
# fakemail2 - rewrite of Perl's fakemail in python
#
# Author: Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This file has been released to the public domain
#

version = '1.0'

import sys, os
from optparse import OptionParser, OptionValueError, OptionError
from tempfile import TemporaryFile
from smtpd import SMTPServer
from asyncore import loop
from time import ctime

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

class logit(object):
    def __init__(self, logfile=None):
        self.logfile = logfile

    def log(self, message):
        if self.logfile:
            l = open(self.logfile + os.getpid(), 'a')
            try: l.write(ctime() + ': ' + str(message))
            finally: l.close
        else:
            print message

class saveit(object):
    def __init__(self, savepath=None):
        if savepath is None: raise StandardError('Savepath not defined');
        self.path = savepath
        self.counts = {}

    def save(self, sender, recipient, data):
        msgfil = os.path.join(self.path, self.recp2file(recipient))
        m = open(msgfil, 'w')
        try: m.write('MAIL FROM: <%s>\nRCPT TO: <%s>\nDATA:\n%s\n' % (sender, recipient, data))
        finally: m.close()

    def recp2file(self, recipient):
        for c in '|<>&/\\ ;!?':
            recipient = recipient.replace(c, '')
        if self.counts.has_key(recipient):
            self.counts[recipient] += 1
        else:
            self.counts[recipient] = 1
        return recipient + '.' + str(self.counts[recipient])

# MAIN

process_opts = OptionParser(usage='Usage: %prog -H <hostname> -p <port> -P <log-path> [-l <log-file>} [-b]', version='%prog '+version)
process_opts.add_option('-H', '--host', dest='host', help='hostname/ip to listet on')
process_opts.add_option('-p', '--port', type='int', dest='port', help='port to listen to')
process_opts.add_option('-P', '--path', dest='path', help='directory to save emails into')
process_opts.add_option('-l', '--log', dest='log', help='Optionnal file to append messages to')
process_opts.add_option('-b', '--background', action='store_true', dest='background', help='Fork to background')

(options, args) = process_opts.parse_args()
if not options.host or not options.port or not options.path:
    process_opts.error('You must supply a host, port and path')
if not os.path.isdir(options.path):
    process_opts.error('Path \'%s\' do not exist' % options.path)

# Fork to background if needed
if options.background:
    try:
        if os.fork() > 0: os._exit(0)
    except OSError, err:
        print 'Fork failed: %s (%d)' % (error.strerror, error.errno)
        sys.exit(1)

    # See ya dad...
    for fd in range(0,3):
        try: os.close(fd)
        except OSError: pass
    os.chdir(os.sep)
    os.umask(0022)
    try: os.setsid()
    except StandardError: pass

message = logit(options.log)
capture = saveit(options.path)

# All set, lets go
message.log('Starting fakemail')
FakemailSMTPD((options.host,options.port), None, capture, message)
loop(timeout=1,use_poll=True)
message.log('Shutting down')

