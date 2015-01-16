#!/usr/bin/perl -w

use strict;
use lib "/var/www/webperl";

use DBI;
use Webperl::ConfigMicro;
use Data::Dumper;

sub build_metadata_tree {
    my $dbh      = shift;
    my $settings = shift;

    my $query = $dbh -> prepare("SELECT * FROM ".$settings -> {"database"} -> {"metadata"}."
                                 ORDER BY id");
    $query -> execute()
        or die "Unable to execute query: ".$dbh -> errstr;

    my $tree = {};
    while(my $row = $query -> fetchrow_hashref()) {
        $tree -> {$row -> {"id"}} -> {"id"} = $row -> {"id"};

        push(@{$tree -> {$row -> {"parent_id"}} -> {"children"}}, $tree -> {$row -> {"id"}})
            if($row -> {"parent_id"});
    }

    return $tree;
}

my $settings = Webperl::ConfigMicro -> new("../config/site.cfg")
    or die "Unable to open configuration file: ".$Webperl::SystemModule::errstr."\n";

die "No 'language' table defined in configuration, unable to proceed.\n"
    unless($settings -> {"database"} -> {"language"});

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "Unable to connect to database: ".$DBI::errstr."\n";

my $tree = build_metadata_tree($dbh, $settings);
print Dumper($tree);