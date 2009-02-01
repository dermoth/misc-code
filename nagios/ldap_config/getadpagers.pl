#!/usr/bin/perl
#
# getadpagers.pl  -  See updatepagers.pl.
#
# Version 1.01
#
# Copyright (C) 2008 Thomas Guyot-Sionnest <tguyot@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

# Version 1.01

use Net::LDAP;
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);
use strict;
use warnings;


## CONFIG SECTION ##

# This is the AD group containing the pager contacts
my $alias = 'Pager-Alerts';

# Enter the path/file for the output
my $dumpfile = '/tmp/pagers.txt.new';

# Enter the FQDN of your Active Directory domain controllers below
my $dc1='dc1.example.com';
my $dc2='dc2.example.com';

# Base DN to search
my $hqbase='dc=example,dc=com';

# Authorized user for querying
my $user='johndoe@example.com';
my $passwd='password';

# Number of seconds before timeout (for each query)
my $timeout=60;

## END OF CONFIG SECTION ##

# Catch timeouts here
$SIG{'ALRM'} = sub {
  die "LDAP queries timed out";
};

alarm($timeout);

my $ldap = Net::LDAP->new($dc1) || Net::LDAP->new($dc2) || die "Error connecting to specified domain controllers $@ \n";

my $mesg = $ldap->bind(dn => $user,password =>$passwd);

if ($mesg->code()) {
  die ("error:", $mesg->code(),"\n","error name: ",$mesg->error_name(),"\n", "error text: ",$mesg->error_text(),"\n");
}

# How many LDAP query results to grab for each paged round
# Set to under 1000 for Active Directory
my $page = Net::LDAP::Control::Paged->new(size => 100);

# @queries is an array or array references. We initially fill it up with one
# arrayref (The first LDAP search) and then add more during the execution.
# First start by resolving the group.
my @queries = [ ( base    => $hqbase,
                  filter  => "(&(objectCategory=group)(cn=$alias))",
                  control => [ $page ],
) ];

my %pagers;

# Loop until @queries is empty...
foreach my $queryref (@queries) {

  my $cookie;
  alarm($timeout);
  while (1) {
    # Perform search
    my $mesg = $ldap->search( @{$queryref} );

    foreach my $entry ($mesg->entries) {

      my @class = $entry->get_value("objectClass");

      if ($class[1] eq 'group') {
        # Append this group for resolving...
        push @queries, [ ( base    => $hqbase,
                           filter  => "(&(|(objectClass=group)(objectClass=contact))(memberOf=" . $entry->get_value("distinguishedName") . "))",
                           control => [ $page ],
        ) ];
      } elsif ($class[1] eq 'person' && $class[3] eq 'contact' ) {
        # this is a contact

        my $mail = $entry->get_value("targetAddress");
        # Test if the Line starts with the following line:
        # SMTP:
        # and also discard this starting string, so that $mail is only the
        # address without any other characters...
        if ( defined($mail) && $mail =~ s/^(SMTP)://gs &&
             defined(my $name = $entry->get_value("mailNickname")) &&
             defined(my $fullname = $entry->get_value("cn"))) {
          $pagers{lc($name)} = [$fullname, $mail];
        }
      } else {
        warn "Unexpected objectClass: $class[0],$class[1],$class[2],$class[3]";
      }
    } # END: foreach my $entry (...

    # Only continue on LDAP_SUCCESS
    $mesg->code and last;

    # Get cookie from paged control
    my($resp)  = $mesg->control(LDAP_CONTROL_PAGED) or last;
    $cookie    = $resp->cookie or last;

    # Set cookie in paged control
    $page->cookie($cookie);
  } # END: while(1)

  # Reset the page control for the next query
  $page->cookie(undef);

  if ($cookie) {
    # We had an abnormal exit, so let the server know we do not want any more
    $page->cookie($cookie);
    $page->size(0);
    $ldap->search( @{$queryref} );
    # Also would be a good idea to die unhappily and inform OP at this point
    die("LDAP query unsuccessful");
  }

} # END: foreach my $queryref (...)

alarm(0);

## Only write the file once the query is successful
open DUMPFILE, ">$dumpfile" or die "CANNOT OPEN $dumpfile $!";
foreach my $name (sort keys %pagers) {
  (my $fullname, my $email) = @{$pagers{$name}};
  print DUMPFILE "$name\t$fullname\t$email\n"
}
close DUMPFILE;

