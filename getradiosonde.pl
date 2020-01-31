#!/usr/bin/perl
#
## Copyright (c) 2007 University of Miami 
## All Rights Reserved
#

my $pkgdoc = <<'EOD';

#/**-----------------------------------------------------------
# @ file           getradiosonde.pl
#
# This script fetches multiple radiosonde data for a specified 
# locator.
#
# @author          MK Hernandez
# @since           01/08/2007
# @project         Kat Reanalysis over S. FL
# @version         $Header$
# @usage           getradiosonde.pl index
# @date:           Jan 8, 2007
# @institution:    UM
#-------------------------------------------------------------*/
EOD

# $Log$

use warnings;
use strict;
use Getopt::Long;
use LWP::Simple;

if (@ARGV < 1) {
        print $pkgdoc;
        exit -1;
}

my @index = @ARGV;

foreach my $index (@index){

getstore("http://vortex.plymouth.edu/cgi-bin/gen_uacalplt-u.cgi?id=${index}&pl=none&yy=05&mm=08&dd=25&hh=12&pt=parcel&size=640x480",
"238.12.2005.${index}.txt");
}
