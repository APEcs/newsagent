#!/usr/bin/perl -w

# A script to handle migrating data from the old single-feed schema to the new multi-feed
# schema.

use strict;
use lib "/var/www/webperl";

use DBI;
use Webperl::ConfigMicro;


my $settings = Webperl::ConfigMicro -> new("../config/site.cfg")
    or die "Unable to open configuration file: ".$Webperl::SystemModule::errstr."\n";

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "Unable to connect to database: ".$DBI::errstr."\n";

my $articles = $dbh -> prepare("SELECT `id`,`feed_id`
                                FROM `".$settings -> {"database"} -> {"articles"}."`");

my $relation = $dbh -> prepare("INSERT INTO `".$settings -> {"database"} -> {"articlefeeds"}."`
                                (`article_id`, `feed_id`)
                                VALUES(?, ?)");

# Fetch the articles
$articles -> execute()
    or die "Unable to fetch articles: ".$dbh -> errstr."\n";

while(my $article = $articles -> fetchrow_hashref()) {
    # Set up the feed/article relations
    $relation -> execute($article -> {"id"}, $article -> {"feed_id"})
        or die "Unable to create article feed relation: ".$dbh -> errstr."\n";
}

# no need for the feed_id field in the articles table anymore
my $dropcol = $dbh -> prepare("ALTER TABLE `".$settings -> {"database"} -> {"articles"}."` DROP `feed_id`");
$dropcol -> execute()
    or die "Unable to drop 'feed_id' column from the articles table: ".$dbh -> errstr."\n";

print "Done.\n";
