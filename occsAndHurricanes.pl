#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#
my $pkgdoc = <<'EOD';
#/**----------------------------------------------------------------------    
# @file       occsAndHurricanes.pl
#
# Correlates occultations and cyclones.
# 
# @author     Michael Hernandez, Doug Hunt
# @since      06/08/2006
# @version    $Header$
# @cdaacTask  no
# @usage      occsAndHurricanes.pl year mission
# @example    occsAndHurricanes.pl 2005 champ
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

my $yr      = shift;
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
my $sql = "SELECT distinct(region) FROM fid_cyclone WHERE yr = '$yr'";
my $regions = $dbh->selectcol_arrayref($sql);

my %matches = ();

foreach my $region (@{$regions}) {

    # must do two sub selects first to get (virtual) tables 'met' and 'occ' from which
    # one can do the appropriate selection.
    my $sql = "SELECT name, lat, lon, time FROM fid_cyclone WHERE
           yr = $yr AND region = '$region'";

    my $storm_rows = $dbh->selectall_arrayref($sql);

    my $time_window  = 180 * 60; # seconds
    my $space_window = 20;       # degrees lat or lon

    foreach my $row (@$storm_rows) {

        my ($name, $lat, $lon, $time) = @$row;

        my ($yr,  $doy)  = TimeClass->new->set_gps($time)->get_yrdoyhms_gps;
    
        print "$name, $lat/$lon, $yr.$doy\n";
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

        $matches{$region}{$name} += @$occ_rows;
    
    }

}

foreach my $region (sort keys %matches) {
    print "$region:\n";
    foreach my $storm (sort keys %{$matches{$region}}) {
        printf "%-15s: %2d\n", $storm, $matches{$region}{$storm};
    }
}

print "Done!\n"; 