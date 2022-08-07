#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#

my $pkgdoc = <<'EOD';

#/**----------------------------------------------------------------------    
# @file       SummationofAbsMean.pl
# This script calculates the Summation of the Absolute Mean from a text file
# that gives us the fractional mean of the GFS to the occs.
# 
# @author     Skylar Hernandez
# @debuger    Doug Hunt
# @since      07/24/2006
# @version    $Header$
# @cdaacTask  no
# @usage      SummationofAbsMean.pl mytextfile
# -----------------------------------------------------------------------*/
EOD

# $log$

use lib qw (. /ops/tools/lib);
use warnings;
use strict;
use Getopt::Long;

if (@ARGV < 1){
    print $pkgdoc;
    exit -1;
}

my $txtfile = shift;
    
open (IN, $txtfile)||die "cannot open $txtfile for reading";

my $tot = 0;
my $count = 0;

LINE:
while (my $line = <IN>) {
    next LINE if ($line =~ /-999.000/);
    next LINE if ($line =~ /Alt\(km\)/);
    my($alt, $mean, $rms, $n_occs) = split (' ',$line);
    next LINE if ($alt < 0 || $alt > 40);
    $tot += abs($mean);
    $count++;
}

my $sam = $tot/$count;

open (OUT,">$txtfile.SAM");
print OUT "$sam\n";
print "$sam\n";

close (IN);
close (OUT); 
