#!/usr/bin/perl -w
#
## Copyright (c) 2007 University of Miami
#

my $pkgdoc = <<'EOD';


#/**-------------------------------------------------------------------
# @ file               radiosondeparcer.pl
# This script parses the fetched radiosonde data from the Plymouth 
# website.
# 
# @author              MK Hernandez
# @since               01/18/2007
# @project             Kat
# @ussage              radiosondeparcer.pl ddd.hh.yyyy.index.txt
# date:                Jan 18, 2007
# institution:         UM
#--------------------------------------------------------------------*/
EOD

# $Log$

use strict;
use warnings;
use Getopt::Long;


if (@ARGV <1) {
        print $pkgdoc;
        exit -1;
}

my $txtfile = shift;

my $lat;
my $long;

open (DATA, $txtfile)||die "cannot open $txtfile for reading";

# First seek location line
while (<DATA>) {
     next unless /(-?\d+(?:\.\d*)?)\s+ (-?\d+(?:\.\d*)?)\s+ \d+\s \d+/x;
     ($lat, $long) = ($1, $2);
     last;
}

# print "$lat, $long\n";

# Skip to data lines
while (<DATA>) {last if /^-+$/};
while (<DATA>) {last if /^-+$/};

open (OUT, ">$txtfile.redo");

# Skip to data lines to get scf data
while (<DATA>) {
     my ($LEV, $PRES, $HGHT,  $TEMP, $DEWP, $RH, $DD, $WETB, $DIR, $SPD, $THETA, $THEV, $THEW) = split ' ';
        if ($LEV && $LEV =~ /SFC/) {
                last unless defined $SPD;
                print OUT "$lat  $long  $PRES  $HGHT  $TEMP  $DEWP  $DIR  $SPD\n";
        }
        if ($PRES && $PRES =~ /850|500|250/)  {
                last unless defined $SPD;
                print OUT "$lat  $long  $PRES  $HGHT  $TEMP  $DEWP  $DIR  $SPD\n";
        }

        last unless defined $THEW;
	
}

close (DATA);
close (OUT);
}
