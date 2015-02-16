#!/usr/bin/perl -w

#

use strict;
use v5.14;
use experimental qw(smartmatch);
use lib "/var/www/webperl";
use lib "../blocks";
use lib "../modules";

use DBI;
use DateTime;

use Webperl::ConfigMicro;
use Webperl::Logger;
use Webperl::Modules;
use Webperl::Utils qw(path_join);

use Newsagent::System::Metadata;
use Newsagent::System::Roles;
use Newsagent::System::NotificationQueue;


my $logger = Webperl::Logger -> new()
        or die "FATAL: Unable to create logger object\n";

my $settings = Webperl::ConfigMicro -> new("../config/site.cfg")
    or die "Unable to open configuration file: ".$Webperl::SystemModule::errstr."\n";

die "No 'language' table defined in configuration, unable to proceed.\n"
    unless($settings -> {"database"} -> {"language"});

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die "Unable to connect to database: ".$DBI::errstr."\n";

# Pull configuration data out of the database into the settings hash
$settings -> load_db_config($dbh, $settings -> {"database"} -> {"settings"});

my $metadata = Newsagent::System::Metadata -> new(dbh      => $dbh,
                                                  settings => $settings,
                                                  logger   => $logger)
    or die "Unable to create metadata object\n";

my $roles = Newsagent::System::Roles -> new(dbh      => $dbh,
                                            settings => $settings,
                                            logger   => $logger,
                                            metadata => $metadata)
    or die "Roles system init failed\n";

my $modules = Webperl::Modules -> new(dbh      => $dbh,
                                      settings => $settings,
                                      logger   => $logger,
                                      metadata => $metadata)
    or die "Modules system init failed\n";

my $notify = Newsagent::System::NotificationQueue -> new(dbh      => $dbh,
                                                         settings => $settings,
                                                         logger   => $logger,
                                                         roles    => $roles,
                                                         metadata => $metadata,
                                                         module   => $modules)
    or die "NotificationQueue module init failed\n";

print "Sent,Sender,Target\n";
my $results = $notify -> get_notification_articles(1, [1, 2])
    or die "Stats failed: ".$notify -> errstr()."\n";

foreach my $result (@{$results}) {
    my $sent = DateTime -> from_epoch(epoch => $result -> {"release_time"});
    print $sent -> strftime("%F %T%z"),",",$result -> {"realname"},",",$result -> {"name"},"\n";
}
