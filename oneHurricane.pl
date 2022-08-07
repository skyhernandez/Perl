#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#
my $pkgdoc = <<'EOD';
#/**----------------------------------------------------------------------    
# @file       oneHurricane.pl
#
# Print details of one hurricane
# 
# @author     Skylar Hernandez, Doug Hunt
# @since      06/08/2006
# @version    $Header$
# @cdaacTask  no
# @usage      oneHurricane.pl storm_name mission 
# @example    occsAndHurricanes.pl IVAN champ
# -----------------------------------------------------------------------*/
EOD

# $Log$

use lib qw (. /ops/tools/lib);
use warnings;
use strict;
use LWP::Simple;
use TimeClass;
use Tempdir;
use Dplib;
use Getopt::Long;     # Used for processing command line flags
use DBI;

if (@ARGV < 2) {
  print $pkgdoc;
  exit -1;
}

my $storm = shift;
$ENV{cdaac_mission} = my $mission = shift;

# deal with command line options
my $new = 0;  # create database
GetOptions (
            "new!" => \$new,
	    ) || die "Cannot parse command line options!";


my $dbname = $Dplib::cdaacDb;
my $dbhost = $Dplib::cdaacDB;

my $db      = "dbi:Pg:dbname=$dbname;host=$dbhost";
my $dbh     = DBI->connect($db, 'nobody', 'Nobody');
die "Cannot connect to database = $dbname, dbhost = $dbhost" unless (defined($dbh));

# Find all regions in database
my $sql = "SELECT  region, lat, lon, time, wind, pres, category
           FROM fid_cyclone WHERE name = '$storm' ORDER BY time";
my $storm_rows = $dbh->selectall_arrayref($sql);

my $time_window  = 180 * 60; # seconds
my $space_window = 20;       # degrees lat or lon

my $total = 0;

print "Summary for $storm:\n";
print "Time                 Lat   Lon    Category             Matches\n";
foreach my $row (@$storm_rows) {

    my ($region, $lat, $lon, $time, $wind, $pres, $category) = @$row;

    my $tc = TimeClass->new->set_gps($time);
    my ($yr, $doy) = $tc->get_yrdoyhms_gps;
    my $stamp = $tc->get_stamp_gps;
    
    # print "$name, $lat/$lon, $yr.$doy\n";
    my $sql = "SELECT atm.filename from ${mission}_occt_atmprf as atm,
                                        ${mission}_occt        as occ
               WHERE
               atm.bad = 0                                   AND
               abs(occ.atmdatastart - $time) < $time_window  AND
               abs(atm.latn - $lat)          < $space_window AND
               abs(atm.lonn - $lon)          < $space_window AND
               occ.occyr = '$yr'                             AND
               occ.occdoy = '$doy'                           AND
               occ.id = atm.parent";
    
    my $occ_rows = $dbh->selectall_arrayref($sql);

    printf "$stamp  %5.1fN %6.1fE %-22s %3d\n", $lat, $lon, $category, scalar(@$occ_rows);

    $total += @$occ_rows;
}

print "Total of $total matches\n";
 
