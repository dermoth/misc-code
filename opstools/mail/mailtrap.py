#!/usr/bin/env python
#
# mailtrap - based on fakemail2, trap mail and bounce + forward it
#
# Author: Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This file has been released to the public domain
#
# This tool was written to catch possible configuration errors or important
# mail as we deprecated a bunch of domain names on a mail system as part of
# a server migration.
#
# Start it on a non-standard port or a dedicated IP, and have your
# frontend/spam filters forward emails for the deprecated domains to the
# mailtrap daemon (frontends should also have a list of valid users to avoid
# catching spams for non-existend users).
#
# This script will bounce back any email it receives, but *also* redirect it
# to the specified email address so you can inspect the mails that bounced.
#
# This script will work with any MTA that lets you route mail based on the
# domain name. It should work just as well if you can route based on full
# email addresses or wildcards, if you want to trap in such way.
#

version = '1.0'

import sys, os
from optparse import OptionParser, OptionValueError, OptionError
from smtplib import SMTP
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
            self.message.log('Capturing mail from %s' % recp)
            try:
                self.capture.save(mailfrom, recp, data)
                self.message.log('Mail for %s forwarded' % recp)
            except Exception, e:
                self.message.log("Failed forwarding for %s: %s" % (mailfrom, recp, str(e)))

        self.message.log('Incoming mail dispatched')
        return '550 No such user here'

class logit(object):
    def __init__(self, logfile=None):
        self.logfile = logfile

    def log(self, message):
        if self.logfile:
            l = open(self.logfile, 'a')
            try: l.write(ctime() + ': ' + str(message) + '\n')
            finally: l.close
        else:
            print message

class fwdit(object):
    def __init__(self, destemail=None, my='localhost', server='localhost', port=25):
        if destemail is None: raise StandardError('Dest email not defined');
        self.dest = destemail
        self.my = my
        self.server = server
        self.port = port

    def save(self, sender, recipient, data):
        # Forward the email, but since we already bounced it make sure it doesn't bounce again
        # (hence the "<>" from addr)
        ## TODO: Add recipient somewhere, ex in subject?
        try:
            s = SMTP(self.server, self.port)
            print '<>', self.dest, data
            s.sendmail('<>', self.dest, data)
        except SMTPException, e:
            raise Exception('SMTPException: %s' % str(e))
        finally:
            s.close()

# MAIN

process_opts = OptionParser(usage='Usage: %prog -H <hostname> -p <port> -d <dest-email> [-l <log-file>} [-b]', version='%prog '+version)
process_opts.add_option('-H', '--host', dest='host', help='hostname/ip to listet on')
process_opts.add_option('-p', '--port', type='int', dest='port', help='port to listen to')
process_opts.add_option('-d', '--dest=', dest='dest', help='email to forward mails to')
process_opts.add_option('-l', '--log', dest='log', help='Optionnal file to append messages to')
process_opts.add_option('-b', '--background', action='store_true', dest='background', help='Fork to background')

(options, args) = process_opts.parse_args()
if not options.host or not options.port or not options.dest:
    process_opts.error('You must supply a host, port and dest email')

# Fork to background if needed
if options.background:
    try:
        if os.fork() > 0: os._exit(0)
    except OSError, err:
        print 'Fork failed: %s (%d)\n' % (error.strerror, error.errno)
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
capture = fwdit(options.dest)

# All set, lets go
message.log('Starting mailtrap')
FakemailSMTPD((options.host,options.port), None, capture, message)
loop(timeout=1,use_poll=True)
message.log('Shutting down')

