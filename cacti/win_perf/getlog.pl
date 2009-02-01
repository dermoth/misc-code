#!/usr/bin/perl
# getlog.pl
# v.1.1
#
# This script reads Windows performance logs (normally saved to a samba share)
# and returns the last value for a given counter in a format suitable for
# Cacti.
#
# Usage of Perl module has been avoided as it cuts down incredibly the
# loading time (The last removed module alone cut load time by 3!)
#
# Configuration is done statically - see below (~ 2 pages down) for options.
#
# Usage: getlog.pl <servername> <instance>
#        getlog.pl <servername> list
# Ex: perl getlog.pl SRV6 '\LogicalDisk(C:)\% Disk Time'
#     perl getlog.pl SRV6 "\\LogicalDisk(C:)\\% Disk Time"
# Output: Cacti data format (or nothing). Errors goes to STDERR.
#
# Log files should be saved under $LOG_PATH and named "<hostname>.csv"
# Everything is CaSe-SenSITive!
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

# Uncomment for development purposes (increase loading time)
#use strict;
#use warnings;

if (@ARGV != 2) {
	print STDERR "Usage: $0 <servername> <instance>\n";
	print STDERR "       $0 <servername> list\n";
	exit(1);
}

# Config variables
my ($LOG_PATH, $MAX_AGE, $STALL_CMD, $READ_CHNK, $MAX_READ);

## All CONFIG VARIABLES defined HERE
#
# This is the place where logs files are dropped
$LOG_PATH = '/var/log/cacti';
#
# If last line's timestamp is older that this (seconds), no data will be
# returned. Additionally, if $STALL_CMD is defined it will be run. Set it to 0
# or comment out the line to avoid this check.
$MAX_AGE = 120; # 2 minutes.
#
# This is a script that will be run if the log is stall for more than $MAX_AGE
# seconds (It's up to you to make good use of this). Have no effect if
# $MAX_AGE isn't defined. The original idea was to have a Nagios event handler
# restart the counter when stall (Implement it the way you like though).
$STALL_CMD = "/usr/libexec/nagios/eventhandlers/notify_stall_counter $ARGV[0]";
#
# This is the maximum read size for each read. Optimal performance can be
# obtained by setting this to the smallest number higher than your usual
# line length. THIS MUST BE A 512-BYTES MULTIPLE!! I.e. 512, 1024, 8192, 8704
# are all valid numbers.
$READ_CHNK = 512 * 2; # 1024 bytes
#
# Maximum buffered read size (Will stop reading lines longer than this!)
$MAX_READ = 1024 * 512; # 512KiB
#
## END of CONFIG VARIABLES

my $log = "$LOG_PATH/$ARGV[0].csv";
die "File not found: $log" unless (-f $log);

# Since we can't mix buffered and system reads, we'll do only system reads.
open (LOG, "<$log") or die "Cannot open $log for reading :$!";

my $header = get_head() or die ("Failed to read first line!");
my $last = get_tail() or die ("Failed to read last line!");

close (LOG);

# Strip the first column (we'll do the same to get the date field)
subst_col (0, \$header);

if ($ARGV[1] eq 'list') {
	print "Available counters:\n";
	while (defined(my $col = subst_col (0, \$header))) {
		$col = substr ($col, index ($col, "\\", 3));
		print "$col\n";
	}
	exit;
}

# Check the date
my $datestr = subst_col (0, \$last);
if ($MAX_AGE) {
	my $diff = datediff($datestr);
	die ("Couldn't parse date string '$datestr'") unless (defined($diff));
	if ($diff > $MAX_AGE) {
		if ($STALL_CMD) {
			# Run $STALL_CMD and exit, but don't block the Cacti poller!
			my $ret = fork;
			system($STALL_CMD) if ($ret == 0);
		}
		exit;
	}
}

my $index = find_index ($ARGV[1], $header);
die ("No matching index '$ARGV[1]'") unless (defined($index) && $index >= 0);

my $value = subst_col ($index, \$last);
# Only check for definition; allow returning empty strings and zeros!
die ("Column $index not found!") unless (defined($value));

print "$value\n";

sub get_head {
	my $buf = '';
	my $marker = -1;

	# Make sure we're at the beginning
	sysseek (LOG, 0, 0);

	# Loop until we get a newline
	while (my $ret = sysread (LOG, my $read, $READ_CHNK)) {
		$read =~ s/\r//g;
		$buf .= $read;
		last if (($marker = index ($buf, "\n")) > 0);
		last if (length ($buf) > $MAX_READ);
	}

	# Return the first line if we got one
	if ($marker > 0) {
		$buf = substr ($buf, 0, $marker);
		return $buf;
	}
	return undef;
}

sub get_tail {
	my $buf = '';
	my $marker = -1;

	my $length = (stat(LOG))[7]; # Size in bytes

	# Try to read up to $READ_CHNK bytes at time, but make sure we read at
	# 512-bytes boundaries. THIS IS TRICKY, don't change this unless you
	# know what you're doing!
	my $start = (int($length / 512) * 512);
	if ($start >= $READ_CHNK && $start == $length) {
		$start -= $READ_CHNK;
	} elsif ($start >= $READ_CHNK) {
		$start -= ($READ_CHNK - 512);
	} else {
		$start = 0;
	}

	sysseek (LOG, $start, 0);
	while (sysread (LOG, my $read, $READ_CHNK) > 0) {
		$read =~ s/\r//g;
		$buf = $read . $buf;
		if (($marker = index ($buf, "\n")) >= 0 && $marker != length ($buf) - 1) {
			# Make sure we got the last newline
			while ((my $tmpmark = index ($buf, "\n", $marker + 1)) > $marker) {
				# Got last newline ?
				last if ($tmpmark == length ($buf) - 1);
				$marker = $tmpmark;
			}
			last;
		}
		last if (length ($buf) > $MAX_READ);
		last if (($start -= $READ_CHNK) < 0);
		sysseek (LOG, $start, 0);
	}

	# Return the last line if we got one
	if ($marker >= 0) {
		$buf = substr ($buf, $marker + 1);
		chomp $buf;
		return $buf;
	}
	return undef;
}

sub find_index {
	my $colname = shift;
	my $line = shift;

	my $i = 0;
	while ($line && defined(my $col = subst_col (0, \$line))) {
		# Skip over the server name (\\name)
		$col = substr ($col, index ($col, "\\", 3));
		return $i if ($col eq $colname);
		$i++;
	}
	return undef;
}

sub subst_col {
	# Fetch the column indicated by $colnum and remove the scanned part from
	# $lineref (this allow faster scanning by find_index).
	# NOTE: CSV does not require delimiters on numeric values; but since Windows
	#       doesn't do that anyways it's not supported here. Could be easy to add
	#       though...
	my $colnum = shift;
	my $lineref = shift;
	my $col = undef;

	for (my $i = 0, my $marker = 0; $i <= $colnum; $i++, $marker = 0) {
		my $delim = index ($$lineref, ',', $marker);
		my $curr;
		# this is the last column?
		if ($delim < 0) {
			$delim = length ($$lineref) - 1;
			$curr = $$lineref;
			# Possible infinite loop is you leave data in there
			$$lineref = '';
		} else {
			$curr = substr ($$lineref, 0, $delim);
		}
		# Look for starting and ending double-quotes...
		if (index ($curr, '"', 0) != 0 || index ($curr, '"', length ($curr) - 1) != length ($curr) - 1) {
			# The field isn't properly delimited; try next comma and hope for the best
			$marker = $delim + 1;
			# Continue while there's still data to parse
			redo if ($$lineref);
			return undef;
		}
		if ($i == $colnum) {
			# We're done, extract the current column
			$col = substr ($curr, 1, length($curr) - 2) if ($curr);
			$$lineref = substr ($$lineref, $delim + 1) if ($$lineref);
		} else {
			# No more data?
			last unless ($$lineref);

			# Pop out the column
			$$lineref = substr ($$lineref, $delim + 1);
			$marker = 0;
		}
	}
	return $col;
}

sub datediff {
	# Date string to time diff. Ex. string: "01/22/2008 07:49:19.798"
	my $datestr = shift;

	$datestr =~ m#^(\d{2})/(\d{2})/(\d{4})\s(\d{2}):(\d{2}):(\d{2})\.(?:\d{3})$#;
	my ($month, $day, $year, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
	return undef if(!defined($month) || !defined($day) || !defined($year) || !defined($hour) || !defined($min) || !defined($sec));

	my ($nowsec, $nowmin, $nowhour, $nowday, $nowmon, $nowyear) = localtime();
	$nowmon++; $nowyear += 1900;

	# Seconds out from Google Calculator. Those are rounded averages; we
	# don't care about precision as we really shouldn't need to exceed one
	# day. We care about correctness though (i.e. same date last month is
	# NOT correct).
	my $diff = ($nowyear-$year)*31556926
	          +($nowmon-$month)*2629744
	          +($nowday-$day)*86400
	          +($nowhour-$hour)*3600
	          +($nowmin-$min)*60
	          +($nowsec-$sec);
	return $diff;
}

