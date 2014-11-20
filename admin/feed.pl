#!/usr/bin/perl -w

use strict;
use v5.14;
use experimental qw(smartmatch);
use lib "/var/www/webperl";
use lib "../modules";

use DBI;
use Data::Dumper;
use Regexp::Common qw /URI/;

use Webperl::ConfigMicro;
use Webperl::Logger;

use Newsagent::System::Metadata;
use Newsagent::System::Roles;
use Newsagent::System::Feed;

# ============================================================================
#  Support functions

## @fn $ usage_string(void)
# Generate a string to show the user to document how to use this script
#
# @return A string to show to the user.
sub usage_string {

    return "Usage: feed.pl <command> options...\n\n".
        "Supported commands:\n".
        "    list\n".
        "       - list currently known feeds.\n\n".
        "    new <name> <description> <url> [parent]\n".
        "       - create a new feed with the specified name, description,\n".
        "         and default URL. If a parent feed is specified, the new\n".
        "         feed is added as a child of the specified feed.\n\n".
        "    grant <username> <feedname> <role> [role role ...]\n".
        "       - grand roles to a user on a feed. One or more roles may\n".
        "         be specified. Supported roles are:\n".
        "             author_home   - allow access at 'important' vis level\n".
        "             author_leader - allow access at 'leader' vis level\n".
        "             author_group  - allow access at 'general' vis level\n".
        "         users must have logged in before they can be given access.\n";
}


## @fn void print_feeds($tree, $id, $indent)
# Recursively print the tree of feeds. This prints out the feeds associated with the
# context with the specified ID, and then recurses to print out any child feeds.
#
# @param tree   A reference to a hash containing the tree data
# @param id     The ID of the feed context to print
# @param indent how much to indent feeds at this level.
sub print_feeds {
    my $tree   = shift;
    my $id     = shift;
    my $indent = shift || 0;

    foreach my $feed (@{$tree -> {$id} -> {"feeds"}}) {
        print "".(" " x $indent).$feed -> {"description"}." (".$feed -> {"name"}."): ".$feed -> {"default_url"}."\n";
    }

    if($tree -> {$id} -> {"children"}) {
        foreach my $child (sort @{$tree -> {$id} -> {"children"}}) {
            print_feeds($tree, $child, $indent + 2);
        }
    }
}


## @fn $ get_user($dbh, $settings, $username)
# Given a username, attempt to locate the user with that username.
#
# @param dbh      A reference to a database handle to issue queries through.
# @param settings A reference to a hash containing configration data.
# @param username The username of the user to locate
# @return The userid on success, undef if the user does not exist.
sub get_user {
    my $dbh      = shift;
    my $settings = shift;
    my $username = shift;

    my $userh = $dbh -> prepare("SELECT `user_id`
                                 FROM `".$settings -> {"database"} -> {"users"}."`
                                 WHERE `username` LIKE ?");
    $userh -> execute($username)
        or die "Unable to perform user lookup: ".$dbh -> errstr()."\n";

    my $user = $userh -> fetchrow_arrayref()
        or return undef;

    return $user -> [0];
}


# ============================================================================
#  Command functions

## @fn void list_feeds($feeds)
# list the feeds currently defined in the system.
#
# @param feeds    A reference to a Feed object
sub list_feeds {
    my $feeds    = shift;

    my $tree = $feeds -> get_feeds_tree()
        or die $feeds -> errstr()."\n";

    print "Feeds, showing \"Description (internal name): Default URL\"\n";
    print_feeds($tree, 1);
}


## @fn void new_feed($feeds, $name, $desc, $url, $parent)
# Create a new feed, but do not grant any new direct access to it.
#
# @param feeds    A reference to a Feed object
# @param name     The name of the feed to create.
# @param desc     The description of the new feed.
# @param url      The URL to use as the default URL for the feed.
# @param parent   An optional parent feed. If not specified, the new feed
#                 is created as a top-level feed.
sub new_feed {
    my $feeds     = shift;
    my $name      = shift;
    my $desc      = shift;
    my $url       = shift;
    my $parent    = shift;
    my $parent_id = 1;

    die "No feed name specified.\n" if(!$name);
    die "No description specified for new feed.\n" if(!$desc);
    die "No default URL specified for new feed.\n" if(!$url);
    die "Illegal URL specified for new feed.\n" unless($url =~ m|$RE{URI}{HTTP}{-scheme => 'https?'}|);

    # Before continuing, check the parent exists if needed
    if($parent) {
        $parent_id = $feeds -> get_metadata_id($parent)
            or die "Request for unknown parent feed '$parent'\n";
    }

    # And now the new feed
    my $feed_id = $feeds -> create_feed($name, $desc, $url, $parent_id)
        or die "Feed create failed: ".$feeds -> errstr()."\n";

    print "Added new feed with id $feed_id".($parent ? ", parent '$parent'" :"")."\n";
}


## @fn void grant_access($feeds, $metadata, $roles, $username, $feedname, @roles)
# Grant roles to a user on a feed.
#
# @param feeds    A reference to a Feed object
# @param metadata A reference to a metadata object.
# @param roles    A reference to a roles object.
# @param username The name of the user to give the roles to.
# @param feedname The name of the feed to grant the roles on.
# @param roles    A list of roles to grant.
sub grant_access {
    my $feeds    = shift;
    my $metadata = shift;
    my $roles    = shift;
    my $username = shift;
    my $feedname = shift;
    my @roles    = @_;

    die "No username specified.\n" if(!$username);
    die "No feed name specified.\n" if(!$feedname);
    die "No roles specified.\n" unless(scalar(@roles));

    # Attempt to locate the user
    my $userid = get_user($feeds -> {"dbh"}, $feeds -> {"settings"}, $username)
        or die "Request for unknown user '$username'.\n";

    # Attempt to locate the feed
    my $feed = $feeds -> get_feed_byname($feedname)
        or die "Request for unknown feed '$feedname'.\n";

    foreach my $role (@roles) {
        next unless($role);

        # Attempt to locate the role
        my $roleid = $roles -> role_get_roleid($role);
        if(!$roleid) {
            warn "Skipping request to assign unknown role '$role'.\n";
            next;
        }

        # Assign the role to the user
        $roles -> user_assign_role($feed -> {"metadata_id"}, $userid, $roleid)
            or die "Unable to grant '$role' to '$username' on feed '$feedname'\n.";

        print "Granted role '$role' to '$username' on feed '$feedname'\n";
    }
}


# ============================================================================
#  Dispatcher

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

my $metadata = Newsagent::System::Metadata -> new(dbh      => $dbh,
                                                  settings => $settings,
                                                  logger   => $logger)
    or die "Unable to create metadata object\n";

my $roles = Newsagent::System::Roles -> new(dbh      => $dbh,
                                            settings => $settings,
                                            logger   => $logger,
                                            metadata => $metadata)
    or die "Roles system init failed\n";

my $feeds = Newsagent::System::Feed -> new(dbh      => $dbh,
                                           settings => $settings,
                                           logger   => $logger,
                                           roles    => $roles,
                                           metadata => $metadata)
    or die "Feeds init failed\n";

given($ARGV[0]) {
    when("new")   { new_feed($feeds, $ARGV[1], $ARGV[2], $ARGV[3], $ARGV[4]); }
    when("list")  { list_feeds($feeds); }
    when("grant") { grant_access($feeds, $metadata, $roles, $ARGV[1], $ARGV[2], splice(@ARGV, 3)); }
    default {
        die usage_string();
    }
}