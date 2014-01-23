#!/usr/bin/perl -w

# @file
# This file contains the Twitter cache builder. It should be called periodically
# to update the twitter user cache used to generate typeahead content in the
# compose and edit pages.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use lib "/var/www/webperl";

use FindBin;
use DBI;
use Net::Twitter::Lite::WithAPIv1_1;
use Webperl::ConfigMicro;
use Webperl::Utils qw(path_join);
use v5.12;

# Work out where the script is, so module and config loading can work.
my $scriptpath;
BEGIN {
    if($FindBin::Bin =~ /(.*)/) {
        $scriptpath = $1;
    }
}
use lib "$scriptpath/modules";


use Data::Dumper;


## @fn void check_insert_users($dbh, $settings, $users, $level)
# Go through the list of specified users, adding any users not already present
# in the Twitter autocompletion cache.
#
# @param dbh      A reference to the database handle to issue queries through.
# @param settings A reference to the system settings.
# @param users    A reference to an array of users to check.
# @param level    The user level this is a user at.
sub check_insert_users {
    my $dbh      = shift;
    my $settings = shift;
    my $users    = shift;
    my $level    = shift;

    # Use the unique constraint on the screen_name column to allow updates to data
    # without special update code.
    my $userh = $dbh -> prepare("INSERT INTO `".$settings -> {"twitter"} -> {"autocache"}."`
                                 (`screen_name`, `name`, `profile_img`, `level`, `updated`)
                                 VALUES(?, ?, ?, ?, UNIX_TIMESTAMP())
                                 ON DUPLICATE KEY UPDATE
                                     `name` = VALUES(`name`),
                                     `profile_img` = VALUES(`profile_img`),
                                     `updated` = VALUES(`updated`)");

    foreach my $user (@{$users}) {
        my $rows = $userh -> execute($user -> {"screen_name"}, $user -> {"name"}, $user -> {"profile_image_url_https"}, $level);
        die "Unable to execute user insert for ".$user -> {"screen_name"}.": ".$dbh -> errstr."\n" if(!$rows);
    }
}


## @fn void update_follower_cache($dbh, $twitter, $settings, $screen_name, $level)
# Fetch the list of followers set for the Twitter account with the specified
# screen name, and update the Twitter autocompletion cache table if any
# new entries have been added.
#
# @param dbh         A reference to the database handle to issue queries through.
# @param twitter     A reference to a Twitter API interaction object.
# @param settings    A reference to the system settings.
# @param screen_name The twitter username of the user to fetch follower data for.
# @param level       The user level to add users at.
sub update_follower_cache {
    my $dbh         = shift;
    my $twitter     = shift;
    my $settings    = shift;
    my $screen_name = shift;
    my $level       = shift;

    my $cursor = -1;
    do {
        my $followers = $twitter -> followers_list({"screen_name" => $settings -> {"twitter"} -> {"screen_names"},
                                                    "count"       => 200,
                                                    "skip_status" => 1,
                                                    "cursor"      => $cursor});
        check_insert_users($dbh, $settings, $followers -> {"users"}, $level)
            if(scalar(keys(%{$followers -> {"users"}})));

        $cursor = $followers -> {"next_cursor_str"};
    } while($cursor);
}


## @fn void update_friend_cache($dbh, $twitter, $settings, $screen_name, $level)
# Fetch the list of friends set for the Twitter account with the specified
# screen name, and update the Twitter autocompletion cache table if any
# new entries have been added.
#
# @param dbh         A reference to the database handle to issue queries through.
# @param twitter     A reference to a Twitter API interaction object.
# @param settings    A reference to the system settings.
# @param screen_name The twitter username of the user to fetch friend data for.
# @param level       The user level to add users at.
sub update_friend_cache {
    my $dbh         = shift;
    my $twitter     = shift;
    my $settings    = shift;
    my $screen_name = shift;
    my $level       = shift;

    my $cursor = -1;
    do {
        my $friends = $twitter -> friends_list({"screen_name" => $settings -> {"twitter"} -> {"screen_names"},
                                                "count"       => 200,
                                                "skip_status" => 1,
                                                "cursor"      => $cursor});
        check_insert_users($dbh, $settings, $friends -> {"users"}, $level)
            if(scalar(keys(%{$friends -> {"users"}})));

        $cursor = $friends -> {"next_cursor_str"};
    } while($cursor);
}


my $settings = Webperl::ConfigMicro -> new(path_join($scriptpath, "config/site.cfg"))
    or die "Unable to open configuration file: ".$Webperl::SystemModule::errstr."\n";

die "No twitter cache table defined in configuration, unable to proceed.\n"
    unless($settings -> {"twitter"} -> {"autocache"});

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "Unable to connect to database: ".$DBI::errstr."\n";

my $twitter = Net::Twitter::Lite::WithAPIv1_1 -> new(consumer_key        => $settings -> {"twitter"} -> {"consumer_key"},
                                                     consumer_secret     => $settings -> {"twitter"} -> {"consumer_secret"},
                                                     access_token        => $settings -> {"twitter"} -> {"access_token"},
                                                     access_token_secret => $settings -> {"twitter"} -> {"token_secret"},
                                                     ssl                 => 1);

# Work out which sort of user relation to use
my $mode = $ARGV[0] || "friends";
$mode = "friends" unless($mode eq "followers");
