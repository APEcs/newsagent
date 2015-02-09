#!/usr/bin/perl -w

# A script to migrate the simple single-size images to multi resized images.

use strict;
use lib "/var/www/webperl";
use DBI;
use File::Path qw(make_path);
use Webperl::ConfigMicro;
use Webperl::Utils qw(path_join);
use DateTime;

# these are the output sizes for the images
my $image_sizes = { "icon"  => '-resize 130x63^ -gravity Center -crop 130x63+0+0 +repage',
                    "media" => '-resize 128x128^ -gravity Center -crop 128x128+0+0 +repage' ,
                    "thumb" => '-resize 350x167^',
                    "large" => '-resize 450x450\>'
};

sub make_destdir {
    my $location = shift;
    my $size     = shift;
    my $settings = shift;

    $location =~ s|/[^/]+$||;

    my $fullpath = path_join($settings -> {"config"} -> {"Article:upload_image_path"}, $size, $location);
    if(!-d $fullpath) {
        eval { make_path($fullpath); };
        die "Unable to create image store directory: $@"
            if($@);
    }
}


sub need_resize {
    my $location = shift;
    my $settings = shift;

    my $done_resize = 1;
    foreach my $size (keys(%{$image_sizes})) {
        $done_resize = 0
            if(!-f path_join($settings -> {"config"} -> {"Article:upload_image_path"}, $size, $location));
    }

    return !$done_resize;
}


sub resize_image {
    my $location = shift;
    my $settings = shift;

    print "Converting image at $location...\n";
    my $source = path_join($settings -> {"config"} -> {"Article:upload_image_path"}, $location);
    foreach my $size (keys(%{$image_sizes})) {
        make_destdir($location, $size, $settings);

        my $dest = path_join($settings -> {"config"} -> {"Article:upload_image_path"}, $size, $location);
        my $cmd = join(" ", ($settings -> {"config"} -> {"Media:convert_path"}, $source, $image_sizes -> {$size}, $dest));

        print "\tRunning $size convert for $location... ";
        my $result = `$cmd 2>&1`;
        die "Image conversion failed: $result\n"
            if($result);
        print "done.\n";
    }
}


# Fallback user ID and time
my $fallback_user = 2;
my $fallback_time = 1370442650; # when Newsagent was first installed...

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

my $set_creator = $dbh -> prepare("UPDATE `".$settings -> {"database"} -> {"images"}."`
                                   SET `uploader` = ?, `uploaded` = ?
                                   WHERE `id` = ?");

my $firstuse = $dbh -> prepare("SELECT `a`.`creator_id`, `a`.`created`, `u`.`realname`, `u`.`username`
                                FROM `".$settings -> {"database"} -> {"articles"}."` AS `a`,
                                     `".$settings -> {"database"} -> {"articleimages"}."` AS `i`,
                                     `".$settings -> {"database"} -> {"users"}."` AS `u`
                                WHERE `a`.`id` = `i`.`article_id`
                                AND `a`.`creator_id` = `u`.`user_id`
                                AND `i`.`image_id` = ?
                                ORDER BY `a`.`created` ASC
                                LIMIT 1");

$images -> execute()
    or die "Unable to fetch image information: ".$dbh -> errstr."\n";

while(my $image = $images -> fetchrow_hashref()) {
    # check whether the image has already been resized, skip if done
    if(!need_resize($image -> {"location"}, $settings)) {
        print "Skipping image ".$image -> {"id"}." (".$image -> {"location"}."): resize already done.\n";
        next;
    }

    $firstuse -> execute($image -> {"id"})
        or die "Unable to fetch image first use information: ".$dbh -> errstr."\n";

    # If there is no creator (image isn't used), fall back on defaults.
    my $first = $firstuse -> fetchrow_hashref() || { "creator_id" => $fallback_user,
                                                     "created"    => $fallback_time};

    resize_image($image -> {"location"}, $settings);

    # Update the creator information
    my $created = DateTime -> from_epoch( epoch => $first -> {"created"} );
    print "Setting image ".$image -> {"id"}." creator to ".($first -> {"realname"} || $first -> {"username"})." at ".$created."\n";

    $set_creator -> execute($first -> {"creator_id"}, $first -> {"created"}, $image -> {"id"})
        or die "Failed to update image creator information: ".$dbh -> errstr."\n";
}
