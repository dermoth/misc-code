# LDAP config file for getad*.pl nagios scripts.

package ldapconfig;

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw($dc1 $dc2 $hqbase $user $passwd $timeout);

use strict;

# Enter the FQDN of your Active Directory domain controllers below
our $dc1='dc1.example.com';
our $dc2='dc2.example.com';

# Base DN to search
our $hqbase='dc=example,dc=com';

# Authorized user for querying
our $user='johndoe@example.com';
our $passwd='password';

# Number of seconds before timeout (for each query)
our $timeout=60;

