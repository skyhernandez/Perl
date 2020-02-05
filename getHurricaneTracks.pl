#!/ops/tools/bin/perl
#
##  Copyright (c) 1995-2004 University Corporation for Atmospheric Research
## All rights reserved
#
my $pkgdoc = <<'EOD';
#/**----------------------------------------------------------------------    
# @file       getHurricaneTracks.pl
# This script fetches hurrican track data from the web and updates
# the mission_cyclone database table.
# 
# @author     Michael Hernandez
# @since      06/08/2006
# @version    $Header$
# @cdaacTask  no
# @usage      getHurricaneTracks.pl YYYY mission [--new]
# @           If --new is specified, initialize the <mission>_cyclone
# @           database table.
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

my $yr = shift;
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

# initialize database if requested
if ($new) {

    $dbh->do ("DROP TABLE $mission\_cyclone");            # drop table
    $dbh->do ("DROP SEQUENCE $mission\_cyclone_id_seq");  # drop table's id number sequence (start from 1)
    $dbh->do ("CREATE TABLE ${mission}_cyclone
                             (id              SERIAL,  -- key
                              yr              INT2,    -- year of storm
                              region          TEXT,    -- Basin: atlantic,  w_pacific, e_pacific,
                                                       --        s_pacific, s_indian,  indian_oc
                              name            TEXT,    -- name of storm (all caps)
                              lat             FLOAT4,  -- Latitude  N (-90 to 90)
                              lon             FLOAT4,  -- Longitude E (-180 to 180)
                              time            FLOAT8,  -- Current time in GPS seconds
                              wind            FLOAT4,  -- Sustained wind speed in knots
                              pres            FLOAT4,  -- Eye pressure in millibars
                              category        TEXT)"); # Category based on Saffir-Simpson scale.
}



#
## fetch track information from web
#

my $base   = 'http://weather.unisys.com/hurricane';

my $content = LWP::Simple::get($base);
die "Couldn't get it!" unless defined $content;
#print "Found:\n$content\n";

#
## parse top level content looking for year directories
#

my @regions = ('atlantic',  'w_pacific', 'e_pacific', 
	       's_pacific', 's_indian',  'indian_oc');

my @urls = ();

# <a href="atlantic/2006[H]/index.html">
foreach my $region (@regions) {
  my ($url) = $content =~ m{
    <a\shref=\"($region/${yr}H*/index\.html)
  }smx;

  push (@urls, $url) if (defined($url));
}

print "URLs found: @urls\n";

# $storm_data{region}{storm_name}[recnum][lat, lon, time, wind, pressure, status]
my %storm_data = ();

foreach my $region_page (@urls) {

    my $content = LWP::Simple::get("$base/$region_page");
    die "Couldn't get $region_page!" unless defined $content;



    my @cyclone_names = $content =~ m{
                                      (\w+)/track\.dat
                                     }smxg;
    
    print "for $region_page, found: @cyclone_names\n";
    foreach my $cyclone (@cyclone_names) {
        my $track_page = $region_page;
        $track_page =~ s{/index\.html}{};
        $track_page .= "/$cyclone/track.dat";
    
        my $track_file = LWP::Simple::get("$base/$track_page");
        die "Couldn't get $track_page!" unless defined $content;

        # Add track.dat data to %storm_data
        my $region = (split m{/}, $region_page)[0];
        readTrack ($region, $track_file, \%storm_data);
    }
}

# Get rid of storms for this year that may have been added
# in previous runs.
$dbh->do ("DELETE from $mission\_cyclone WHERE yr='$yr'");

# Add track information to database
updateDB ($dbh, $yr, $mission, \%storm_data);

$dbh->disconnect;

print "Done!\n";

#
## Subroutines
#

#/**----------------------------------------------------------------------
# @sub       readTrack
#
# Read important information from a track.dat file and add it to the
# hash structure passed in.
#
# Track.dat files look like this:
#
#    Date: 10-13 JUN 2006
#    Tropical Storm ALBERTO
#    ADV  LAT    LON      TIME     WIND  PR  STAT
#      1  21.10  -85.30 06/10/13Z   30  1003 TROPICAL DEPRESSION
#      2  21.50  -85.60 06/10/15Z   30  1003 TROPICAL DEPRESSION
#     2A  21.70  -85.60 06/10/18Z   30  1003 TROPICAL DEPRESSION
#      3  21.80  -85.70 06/10/21Z   30  1004 TROPICAL DEPRESSION
#      ...   
#
# @parameter  $region     -- Name of region (atlantic, e_pacific, etc)
# @           $track_file -- perl scalar with contents of track.dat file
# @                          (this has cyclone track, strength, etc)
# @           $data_ref   -- reference to hash structure to be updated
# @                          $data_ref->{region}{storm_name}[recnum]
# @                             [lat, lon, time, wind, pressure, status]
# @return     nothing
# @exception  Exception thrown on error reading track.dat file
# ----------------------------------------------------------------------*/
sub readTrack {
    my $region     = shift;
    my $track_file = shift;
    my $data_ref   = shift;

    my @file_lines = split (/\n/, $track_file);

    # Date: 10-13 JUN 2006
    my ($dayrange, $month, $yr) = (split(' ', shift @file_lines))[1,2,3];

    #    Tropical Storm ALBERTO
    my $name = (split(' ', shift @file_lines))[-1];

    my $heading = shift @file_lines; # ignore this line

  LINE:
    foreach my $line (@file_lines) {

        next LINE if ($line =~ /DISSIPATED/);
        
        #      1  21.10  -85.30 06/10/13Z   30  1003 TROPICAL DEPRESSION
        my ($adv, $lat, $lon, $time, $wind, $pr, @stat) = split (' ', $line);
        
        print "$name: $adv, $lat, $lon, $time, $wind, $pr, @stat\n";
        next LINE if ($lat < -90 || $lat > 90);
        if ($lon < -180 || $lon > 180) {
            print "Bad longitude for $name: $line\n";
            next LINE;
        }

        my ($mo, $day, $hr) = split (m{/}, $time);
        $hr =~ s/Z//;

            
        my $gps_sec = eval { TimeClass->new->set_ymdhms_gps($yr, $mo, $day, $hr, 0, 0)->get_gps };
        if ($@) {
            # $mo -= 1;
            next LINE;
        }
    
        push (@{$data_ref->{$region}->{$name}},
              [$lat, $lon, $gps_sec, $wind, $pr, join ' ', @stat])
            if ($adv =~ /^\d+$/);
        
    }
    

}

#/**----------------------------------------------------------------------
# @sub        updateDB
#
# Add track information to the database.
#
# @parameter  $dbh        -- Database handle
# @           $yr
# @           $mission
# @           $data_ref   -- Storm data structure:
# @                          $data_ref->{region}{storm_name}[recnum]
# @                             [lat, lon, time, wind, pressure, status]
# @return     nothing
# @exception  Exception thrown on error updating database
# ----------------------------------------------------------------------*/
 
sub updateDB {
    my ($dbh, $yr, $mission, $data_ref) = @_;

    foreach my $region (sort keys %{$data_ref}) {
        foreach my $storm (sort keys %{$data_ref->{$region}}) {
            print "Adding records for $storm...\n";
            my @storm_recs = @{$data_ref->{$region}{$storm}};
            foreach my $rec (@storm_recs) {
                my ($lat, $lon, $time, $wind, $pres, $category) = @$rec;
                $pres = $Dplib::err if ($pres eq '-');
                
                $category = "\'$category\'";
                my $valstring = join ',', ($yr, "\'$region\'", "\'$storm\'",
                                           $lat, $lon, $time, $wind, $pres, $category);
                my $keys = 'yr, region, name, lat, lon, time, wind, pres, category';
                $dbh->do ("INSERT into $mission\_cyclone ($keys) VALUES ($valstring)");
            }
        }
    }

    return;
    
}
