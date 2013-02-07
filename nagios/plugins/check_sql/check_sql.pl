#! /usr/bin/perl -w
#
# check_sql  -  Run a simple test query against a SQL Server
#
# For MySQL this script requires DBD::mysql.
#
# Note: Driver-specific timeouts aren't implemented because
#   1. It doesn't work as expected on DBD::mysql
#   2. DBD::Sybase defaults to 60 seconds which is enough for most people
#
# For MSSQL this script requires the FreeTDS library and DBD::Sybase Perl
# module. The SYBASE environment variable also needs to be defined.
# Make sure FreeTDS is compiled with --with-tdsver=8.0 !!!
#
# Other drivers are untested.
#
# It also requires File:::Basename, Nagios::Plugins and Time::HiRes.
#
# Copyright (c) 2007 Thomas Guyot-Sionnest <tguyot@gmail.com>
# Copyright (c) 2007 Nagios Plugin Development Team
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

use strict;
use warnings;
use vars qw($PROGNAME $VERSION $QSTRING $LABEL);
use File::Basename qw(basename);
use Nagios::Plugin;
use Nagios::Plugin::Functions qw(max_state);
use Time::HiRes qw(gettimeofday tv_interval);
use DBI;

$PROGNAME = basename($0);
$VERSION = '0.9.4';
$QSTRING = 'SELECT 1 AS Response';
$LABEL = 'result';

# If called using a known name (i.e. via symlink), set the DBI driver,
# else set the driver option.
my $driver;
my $driverarg = '';
if ($PROGNAME =~ /check_mysql/) {
  $driver = 'mysql';
} elsif ($PROGNAME =~ /check_mssql/) {
  $driver = 'Sybase';
} else {
  $driverarg = ' -d <driver>';
}

my $np = Nagios::Plugin->new(
  usage => "Usage: %s -H <hostname>$driverarg [ -p <port> ] [ -t <timeout> ]\n"
    . "    -U <user> -P <pass> [ -D <db> ] [ -w <warn_range> ] [ -c <crit_range> ]\n"
    . "    [ -W <warn_range> ] [ -C <crit_range> ] [ -q query ] [ -e expect_string ]\n"
    . '    [ -r ] [ -s ] [ -l label ]',
  version => $VERSION,
  plugin  => $PROGNAME,
  blurb => 'Run a simple test query against a SQL Server',
  extra   => "\n\nCopyright (c) 2007 Nagios Plugin Development Team",
  timeout => 30,
);

$np->add_arg(
  spec => 'hostname|H=s',
  help => "-H, --hostname=<hostname>\n"
    . '   SQL Database hostname',
  required => 1,
);

if ($driverarg) {
  # This argument is omited if the driver is set fie the basename (above).
  $np->add_arg(
    spec => 'driver|d=s',
    help => "-d, --driver=<driver>\n"
      . '   DBD driver name (does not include the \'DBD::\' prefix).',
    required => 1,
  );
}

$np->add_arg(
  spec => 'port|p=i',
  help => "-p, --port=<port>\n"
    . '   SQL TCP port (default: driver-dependent).',
  required => 0,
);

$np->add_arg(
  spec => 'username|U=s',
  help => "-U, --username=<username>\n"
    . '   Username to connect with.',
  required => 1,
);

$np->add_arg(
  spec => 'password|P=s',
  help => "-P, --password=<password>\n"
    . '   Password to use with the username.',
  required => 1,
);

$np->add_arg(
  spec => 'database|D=s',
  help => "-D, --database=<db>\n"
    . '   Database to use.',
  required => 0,
);

$np->add_arg(
  spec => 'warning|w=s',
  help => "-w, --warning=THRESHOLD\n"
    . "   Warning threshold for the responce time. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'critical|c=s',
  help => "-c, --critical=THRESHOLD\n"
    . "   Critical threshold for the responce time. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format.',
  required => 0,
);

$np->add_arg(
  spec => 'query|q=s',
  help => "-q, --query=<SQL_query>\n"
    . "   SQL Query ro execute on the server (default: '$QSTRING').",
  default => $QSTRING,
  required => 0,
);

$np->add_arg(
  spec => 'expect|e=s',
  help => "-e, --expect=<expect_string>\n"
    . "   The expected result from the SQL server (first cell of first row). Cannot\n"
    . '   be used with -W or -C.',
  required => 0,
);

$np->add_arg(
  spec => 'regexp|r+',
  help => "-r, --regexp\n"
    . '   Allow Perl regular expressions to be used with -e.',
  required => 0,
);

$np->add_arg(
  spec => 'rwarning|W=s',
  help => "-W, --rwarning=THRESHOLD\n"
    . "   Warning threshold for the returned value. Value must be numeric. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format. Cannot be used with -e.',
  required => 0,
);

$np->add_arg(
  spec => 'rcritical|C=s',
  help => "-C, --rcritical=THRESHOLD\n"
    . "   Critical threshold for the returned value. Value must be numeric. See\n"
    . "   http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT\n"
    . '   for the threshold format. Cannot be used with -e.',
  required => 0,
);

$np->add_arg(
  spec => 'show|s+',
  help => "-s, --show\n"
    . '   Show the result of the SQL query in the status text.',
  required => 0,
);

$np->add_arg(
  spec => 'label|l=s',
  help => "-l, --label=label\n"
    . "   Label used to present the SQL result (default: '$LABEL'). If in the form\n"
    . "   'LABEL,UOM', enables performance data for the result. Label is effective\n"
    . "   only when used with --show or in the form 'LABEL,UOM'.",
  default => $LABEL,
  required => 0,
);

$np->getopts;

# Assign, then check args

my $hostname = $np->opts->hostname;
$driver = $np->opts->driver if (!$driver);
my $port = $np->opts->port;
my $username = $np->opts->username;
my $password = $np->opts->password;
my $database = $np->opts->database;
my $warning = $np->opts->warning;
my $critical = $np->opts->critical;
my $query = $np->opts->query;
my $expect = $np->opts->expect;
my $regexp = $np->opts->regexp;
my $rwarning = $np->opts->rwarning;
my $rcritical = $np->opts->rcritical;
my $show = $np->opts->show;
my ($label, $uom) = split(/,/, $np->opts->label);
my $verbose = $np->opts->verbose;

$np->nagios_exit('UNKNOWN', 'Hostname contains invalid characters.')
  if ($hostname =~ /\`|\~|\!|\$|\%|\^|\&|\*|\||\'|\"|\<|\>|\?|\,|\(|\)|\=/);

$np->nagios_exit('UNKNOWN', 'Port must be an integer between 1 and 65535.')
  if ($port && ($port < 1 || $port > 65535));

$np->nagios_exit('UNKNOWN', 'Username is required.')
  if ($username eq '');

$np->nagios_exit('UNKNOWN', 'Password is required.')
  if ($password eq '');

$np->nagios_exit('UNKNOWN', '-e cannot be used with -W or -C')
  if (defined($expect) && ($rwarning || $rcritical));

$np->nagios_exit('UNKNOWN', '-r have no effect without -e')
  if ($regexp && !defined($expect));

$np->nagios_exit('UNKNOWN', 'LABEL must be defined if UOM is used')
  if ($uom && !$label);

# Check if the DBI driver exists
$np->nagios_exit('UNKNOWN', "Driver '$driver' not installed.")
  unless (grep { $_ eq $driver } DBI->available_drivers);


# First set the r* thresholds to validate them and get the threshold object.
$np->set_thresholds(
    warning => $rwarning,
    critical => $rcritical,
);
my $rthreshold = $np->threshold;

# Then we can set the normal thresholds for validation and future use.
$np->set_thresholds(
    warning => $warning,
    critical => $critical,
);

# Note: There's no automated way to check if ranges makes sense, so you can
# have a WARNING range within a CRITICAL range with no warning. I'm not going
# to do N::P's job here so such thresholds are allowed for now.

my $cs = "DBI:$driver:" . ($database ? "database=$database;" : '') . "host=$hostname" . ($port ? ";port=$port" : '');

warn("Trying to connect. Connect string: '$cs'\n") if ($verbose);
warn("Using the following credentials: $username,$password\n") if ($verbose > 2);

# Just in case of problems, let's not hang Nagios
alarm $np->opts->timeout;

my $timestart = [gettimeofday];

my $dbh = DBI->connect($cs,$username,$password,{PrintWarn=>($verbose ? 1 : 0),PrintError=>($verbose ? 1 : 0)})
  or $np->nagios_exit('CRITICAL', $DBI::errstr);

warn("Connected. Querying server with '$query'\n") if ($verbose > 1);

# selectrow_array behavior in scalar context is undefined (driver-dependent)
# if multiple collumns are returned. Just get the first or only collumn:
my ($result) = $dbh->selectrow_array($query)
  or $np->nagios_exit('CRITICAL', $DBI::errstr);

$dbh->disconnect;

my $timeend = [gettimeofday];

#Turn off alarm
alarm(0);

my $elapsed =  tv_interval($timestart, $timeend);

warn("Request complete. Time elapsed: $elapsed\n") if ($verbose);
warn("Server returned $result\n") if ($verbose > 1);

$np->add_perfdata(
  label => "time",
  value => $elapsed,
  uom => 's',
  threshold => $np->threshold,
);

# Add result perfdata if UOM is specified (see usage) and result is numeric.
if ($uom && $result =~ /^[-+]?\d+$/) {
  $np->add_perfdata(
    label => lc($label),
    value => $result,
    uom => $uom,
    threshold => $rthreshold,
  );
}

# First check expect strings (if defined) as they always return CRITICAL
if (defined($expect) && $regexp) {
  $np->nagios_exit('CRITICAL', "Unexpected $label" . ($show ? ": $result" : '')) unless ($result =~ /$expect/);
} elsif (defined($expect)) {
  $np->nagios_exit('CRITICAL', "Unexpected $label" . ($show ? ": $result" : '')) if ($result ne $expect);
}

my @results;

push (@results, $np->check_threshold($elapsed));

my $nonnumeric = 0;
if (($rwarning || $rcritical) && !($result =~ /^[-+]?\d+$/)) {
  push (@results, ($rcritical ? CRITICAL : WARNING));
  $nonnumeric = 1;
} else {
  push (@results, $np->check_threshold(check => $result, warning => $rwarning, critical => $rcritical));
}

warn ('Thresholds results: time=' . $results[0] . ', result=' . $results[1] . ', nonnumeric=' . $nonnumeric) if ($verbose);

my $status = max_state(@results);

if ($nonnumeric) {
  $np->nagios_exit($status, "Result is not numeric with result threshold defined ($elapsed seconds)");
} elsif ($show) {
  $np->nagios_exit($status, "SQL Server $label: $result ($elapsed seconds)");
} else {
  $np->nagios_exit($status, "SQL Server responded in $elapsed seconds");
}

