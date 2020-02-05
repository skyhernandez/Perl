#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#
my $pkgdoc = <<'EOD';
#/**----------------------------------------------------------------------    
# @file       nonHurricaneStats.pl
#
# Look for matching occs 7 days before each point of the storm track
# for a given storm.
# 
# @author     Michael Hernandez, Doug Hunt
# @since      06/08/2006
# @version    $Header$
# @cdaacTask  no
# @usage      nonHurricaneStats.pl storm_name mission
# @example    nonHurricaneStats.pl KENNETH champ
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
use genStats;
use PDL;

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

my $matches_threshold = 5;
my $time_lag = 7; # number of days before storm to look for matches

my $total = 0;

print "Occultations 7 days before $storm\n";
STORMROW:
foreach my $row (@$storm_rows) {

    my ($region, $lat, $lon, $time, $wind, $pres, $category) = @$row;

    $time -= (86400 * $time_lag);
    
    my $tc = TimeClass->new->set_gps($time);
    my ($yr, $doy) = $tc->get_yrdoyhms_gps;
    my $stamp = $tc->get_stamp_gps;
    
    printf "%6.1f/%6.1f, $stamp: ", $lat, $lon;
    my $sql = "SELECT atm.filename,
                      gfs.filename from ${mission}_occt_atmprf as atm,
                                        ${mission}_occt_gfsprf as gfs,
                                        ${mission}_occt        as occ
               WHERE
               atm.bad = 0                                   AND
               abs(occ.atmdatastart - $time) < $time_window  AND
               abs(atm.latn - $lat)          < $space_window AND
               abs(atm.lonn - $lon)          < $space_window AND
               occ.occyr = '$yr'                             AND
               occ.occdoy = '$doy'                           AND
               occ.id = gfs.parent                           AND
               occ.id = atm.parent";

    my $results = $dbh->selectall_arrayref($sql);

    print "Found ", scalar(@$results), " matches...\n";
    next STORMROW if (@$results < $matches_threshold);
    
    my $z = sequence(81) * 0.5;
    my $args = {RESULTS   => $results,
                MISSION   => 'champ',
	        FIELD1    => 'Ref',     # compare refractivities
	        FIELD2    => 'Ref',     # compare refractivities
	        DIFFTYPE  => 'percent', # (a-b)/a
	        PLOT      => "$storm.minus7.$mission.$stamp.gfs.png/PNG",   # name of plot file
	        LEVELS    => $z,        # 0 to 40 km altitude range
	        INTERP    => 'cspline', # Cubic Spline interpolation
                XRANGE    => [-0.05, 0.05], # plus/minus 5 percent standard scale
	        PLOTTITLE => "Ref: ($mission - GFS)/$mission, $storm, $stamp"};
   

    my ($mean, $rms, $median, $min, $max, $n, $hash) = eval { genStats::genStats ($args); };
    if ($@) {
      my $sql = $$args{SQL};
      die "genStats failed for SQL = $sql.  Error = $@";
    }

    $mean->inplace->setbadtoval(-999);
    $rms->inplace->setbadtoval(-999);
    $n->inplace->setbadtoval(-999);
    open(OUT,">$storm.$mission.$stamp.minus7.gfs.txt");

    wcols "%5.1f %8.3f %8.3f %4d", $z, $mean->slice(":,(0)"),
                                       $rms->slice(":,(0)"),
                                       $n->slice(":,(0)"), *OUT,
                                           { HEADER => "Alt(km) Mean     RMS       N" };
    close(OUT);
}
