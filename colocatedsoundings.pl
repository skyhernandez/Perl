#!/ops/tools/bin/perl
#
## Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#

my $pkgdoc = <<'EOD';

#/**----------------------------------------------------------------------
# @file      colocatedsoundings.pl
#
# Calculates the CAPE values of colocated radiosonde and COSMIC soundings
# that are about 200km and a +/- 2 hour from a radiosonde launch.
#
# @author    Michael Hernandez, Doug Hunt
# @since     06/08/2006
# @version   $Header$
# @cdaacTask no
# @usage     colocatedsoundings.pl indexlist cosmicCAPE mm dd yy
# @example   colocatedsoundings.pl indexlist.txt cosmicCAPE.txt 1 12 07
# -----------------------------------------------------------------------*/

EOD

# $Log$
use lib qw (. /ops/tools/lib);
use warnings;
use strict;

if (@ARGV < 2) {
print $pkgdoc;
exit -1;
}

my $raobCAPE    = shift;
my $cosmicCAPE  = shift;
my $month       = shift;
my $day         = shift;
my $year        = shift;

#
##  Opening the text files
#

open (RAOB, $raobCAPE)||die "cannot open $raobCAPE for reading";
open (COSMIC, $cosmicCAPE)||die "cannot open $cosmicCAPE for reading";

#
## Space restrictions
#

my $space_window = 20;       # degrees lat or lon

#
## Loop through each line in the txt file to colocate the CAPE values
## by thier space restrictions.
#

LINE:
while (my $line = <RAOB>) {
	my($index, $raoblat, $raoblon, $mycape, $cape, $mycin, $cin) = split (' ',$line);
	while (my $cosmicline = <COSMIC>) {
		my($cosmiclat, $cosmiclon, $cosmictime $cosmiccape, $cosmiccin) = split (' ',$line);
		next LINE if ($raoblat - $cosmiclat < 0 || $raoblat - $cosmiclat > $spacewindow );
 		next LINE if ($raoblon - $cosmiclon < 0 || $raoblon - $cosmiclon > $spacewindow );
		next LINE if ($cosmictime < 22 || $cosmictime > 02 ); # or 10 and 14

		#
		## While in the loop add to a new file $mycape, $cosmiccape, $mycin, $cosmiccin.
		#			

		open (OUT,">colocated.$month.$day.$year");
		print OUT "$mycape $cosmiccape $mycin $cosmiccin\n";
		close OUT;
	}
}













