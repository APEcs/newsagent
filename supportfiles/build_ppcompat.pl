#!/usr/bin/perl -w

# A script to build ppcompat images from article images

use strict;
use lib "/var/www/webperl";
use DBI;
use File::Path qw(make_path);
use Webperl::ConfigMicro;
use Webperl::Utils qw(path_join);
use DateTime;

sub make_destdir {
    my $base     = shift;
    my $location = shift;

    $location =~ s|/[^/]+$||;

    my $fullpath = path_join($base, $location);
    if(!-d $fullpath) {
        eval { make_path($fullpath); };
        die "Unable to create image store directory: $@"
            if($@);
    }
}


my $settings = Webperl::ConfigMicro -> new("../config/site.cfg")
    or die "Unable to open configuration file: ".$Webperl::SystemModule::errstr."\n";

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "Unable to connect to database: ".$DBI::errstr."\n";

# Pull configuration data out of the database into the settings hash
$settings -> load_db_config($dbh, $settings -> {"database"} -> {"settings"});

# Some queries we'll need to do the processing
my $images = $dbh -> prepare("SELECT *
                              FROM `".$settings -> {"database"} -> {"images"}."`
                              WHERE `type` = 'file'");

my $srcbase = path_join($settings -> {"config"} -> {"Article:upload_image_path"}, "large");
my $dstbase = path_join($settings -> {"config"} -> {"Article:upload_image_path"}, "ppcompat");
my $size    = '-resize 500x298^ -gravity Center -crop 500x298+0+0 +repage';

$images -> execute()
    or die "Unable to fetch image information: ".$dbh -> errstr."\n";

while(my $image = $images -> fetchrow_hashref()) {
    my $srcname = path_join($srcbase, $image -> {"location"});
    my $dstname = path_join($dstbase, $image -> {"location"});

    print "Converting $srcname to $dstname.\n";
    make_destdir($dstbase, $image -> {"location"});

    my $cmd = join(" ", ($settings -> {"config"} -> {"Media:convert_path"}, $srcname, $size, $dstname));

    print "\tRunning convert for ".$image -> {"location"}."... ";
    my $result = `$cmd 2>&1`;
    die "Image conversion failed: $result\n"
        if($result);
    print "done.\n";
}