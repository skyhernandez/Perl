#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#
my $pkgdoc = <<'EOD';
#/**----------------------------------------------------------------------    
# @file       nonHurricaneStats.pl
#
# Print details of one hurricane
# 
# @author     Skylar Hernandez, Doug Hunt
# @since      06/08/2006
# @version    $Header$
# @cdaacTask  no
# @usage      anycaseStats.pl lat lon  mission YYYY.DDD[-DDD]
# @example    anycaseStats.pl 12.1 -63.3 champ 2004.240-241 # before hurricane IVAN example
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

if (@ARGV < 3) {
  print $pkgdoc;
  exit -1;
}

my $lat = shift;
my $lon = shift;
$ENV{cdaac_mission} = my $mission = shift;
my $daterange = shift;
my @dates = TimeRange->new->set_daterange($daterange)->get_dates;

my $dbname = $Dplib::cdaacDb;
my $dbhost = $Dplib::cdaacDB;

my $db      = "dbi:Pg:dbname=$dbname;host=$dbhost";
my $dbh     = DBI->connect($db, 'nobody', 'Nobody');
die "Cannot connect to database = $dbname, dbhost = $dbhost" unless (defined($dbh));

my $time_window  = 180 * 60; # seconds
my $space_window = 20;       # degrees lat or lon
my $occ_threshold = 5;       # Minimum number of matches

DATE:
foreach my $date (@dates) {

    my ($yr, $doy) = split (/\./, $date);
    my ($yrp, $doyp) = TimeClass->new->set_yrdoy_gps($date)->inc_sec_gps(-86400)->get_yrdoyhms_gps;

  HOUR:
    foreach my $hr (0, 3, 6, 9, 12, 15, 18, 21) {
        
        my $time = TimeClass->new->set_yrdoyhms_gps($yr, $doy, $hr, 0, 0)->get_gps;

        print "Processing for $yr.$doy.$hr at $lat/$lon:\n";
    
        my $sql = "SELECT atm.filename,
                  ecm.filename from ${mission}_occt_atmprf as atm,
                                    ${mission}_occt_ecmprf as ecm,
                                    ${mission}_occt        as occ
               WHERE
               atm.bad = 0                                   AND
               abs(occ.atmdatastart - $time) < $time_window  AND
               abs(atm.latn - $lat)          < $space_window AND
               abs(atm.lonn - $lon)          < $space_window AND
               (occ.yr  = '$yr'  OR occ.yr  = '$yrp')        AND
               (occ.doy = '$doy' OR occ.doy = '$doyp')       AND
               occ.id = ecm.parent                           AND
               occ.id = atm.parent";

        my $results = $dbh->selectall_arrayref ($sql);

        if (@$results < $occ_threshold) {
            print "Skipping $date.$hr (only ", scalar (@$results), " match(es))\n";
            next HOUR;
        }
        
        my $z = sequence(81) * 0.5;
        my $args = {RESULTS   => $results,
                    MISSION   => 'champ',
                    FIELD1    => 'Ref',     # compare refractivities
                    FIELD2    => 'Ref',     # compare refractivities
                    DIFFTYPE  => 'percent', # (a-b)/a
                    PLOT      => "$yr.$doy.$hr.$lat.$lon.$mission.png/PNG",   # name of plot file
                    LEVELS    => $z,        # 0 to 40 km altitude range
                    INTERP    => 'cspline', # Cubic Spline interpolation
                    PLOTTITLE => "Ref: ($mission - ECMWF)/$mission,$yr.$doy.$hr $lat, $lon"};
    
        my ($mean, $rms, $median, $minimum, $max, $n, $hash) = eval { genStats::genStats ($args); };
        if ($@) {
            my $sql = $$args{SQL};
            die "genStats failed for SQL = $sql.  Error = $@";
        }
        
        $mean->inplace->setbadtoval(-999);
        $rms->inplace->setbadtoval(-999);
        $n->inplace->setbadtoval(-999);
        wcols "%5.1f %8.3f %8.3f %4d", $z, $mean->slice(":,(0)"),
            $rms->slice(":,(0)"),
                $n->slice(":,(0)"), *STDOUT,
                    { HEADER => "Alt(km) Mean     RMS       N" };
    } # hour
    
} # date
 
