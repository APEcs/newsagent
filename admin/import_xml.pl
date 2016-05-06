#!/usr/bin/perl

## @file
# Import an XML file into the newsagent database.
#
# This script takes an XML file of the form defined below, and inserts the
# articles in the XML file into the Newsagent database. Note that this code
# does not perform any kind of permissions checking on the feeds and users;
# this means that the articles may be created in feeds or at levels that
# the designated author could not normally create articles at.
#
# The XML file must be of the form:
# @verbatim
# <?xml version="1.0" encoding="UTF-8"?>
# <channel>
#   <item>
#     <title>article title</title>
#     <article><![CDATA[article text]]></article>
#     <date>RFC 822 date with 4 digit year</date>
#     <feeds>
#       <feed>feed short name</feed>
#       ... optionally more feeds ...
#     </feeds>
#     <levels>
#       <level>level short name</level>
#       ... optionally more levels ...
#     </levels>
#     <author>author username</author>
#   </item>
#   ... more items ...
# </channel>
# @endverbatim
#
# @warning
# This code does not do all its database operations through the model code.
# In particlar, user lookup is done directly on the database rather than
# going through the session and auth process.

use strict;
use v5.14;
use experimental qw(smartmatch);
use lib "/var/www/webperl";
use lib "../blocks";
use lib "../modules";

use DBI;
use Date::Parse;
use DateTime;
use Lingua::EN::Sentence qw(get_sentences);
use XML::LibXML;

use Webperl::ConfigMicro;
use Webperl::Logger;
use Webperl::Modules;
use Webperl::Template;
use Webperl::Utils qw(path_join);

use Newsagent::System::Metadata;
use Newsagent::System::Roles;
use Newsagent::System::Feed;
use Newsagent::System::Article;

use Data::Dumper;


## @fn $ build_feeds($feeds, @feedlist)
# Given a list of feed name elements, generate a list of feed IDs those
# elements correspond to.
#
# @param feeds    A reference to a Newsagent::System::Feeds object to query feeds though.
# @param feedlist A list of feed elements to look up.
# @return A reference to an array of feed ids.
sub build_feeds {
    my $feeds    = shift;
    my @feedlist = @_;

    my $result = [];
    foreach my $feed (@feedlist) {
        my $feeddata = $feeds -> get_feed_byname($feed -> textContent)
            or die "Unable to fetch data for feed '".$feed -> textContent."': ".$feeds -> errstr()."\n";

        push(@{$result}, $feeddata -> {"id"});
    }

    return $result;
}


## @fn $ build_levels(@levellist)
# Build a hash of levels to use when creating the article.
#
# @param levellist A list of level elements to process.
# @return A reference to a hash of levels.
sub build_levels {
    my @levellist = @_;

    my $result = {};
    foreach my $level (@levellist) {
        my $name = $level -> textContent;

        $result -> {$name} = $name;
    }

    return $result;
}


## @fn $ build_release_time($time)
# Build a unix timestmp to represent the RFC 822 date in the specified
# date element.
#
# @param time A reference to a time element.
# @return A unix timestamp representing the date.
sub build_release_time {
    my $time     = shift;
    my $timedata = $time -> textContent;

    return str2time($timedata);
}


## @fn $ truncate_text($template, $text, $limit)
# Given a string containing plain text (NOT HTML!), produce a string
# that can be used as a summary. This truncates the specified text to the
# nearest sentence boundary less than the specified limit.
#
# @param template A reference to a template object.
# @param text     The text to truncate to a sentence boundary less than the limit.
# @param limit    The number of characters the output may contain
# @return A string containing the truncated text
sub truncate_text {
    my $template = shift;
    my $text     = shift;
    my $limit    = shift;

    # If the text fits in the limit, just return it
    return $text
        if(length($text) <= $limit);

    # Otherwise, split into sentences and stick sentences together until the limit
    my $sentences = get_sentences($text);
    my $trunc = "";
    for(my $i = 0; $i < scalar(@{$sentences}) && (length($trunc) + length($sentences -> [$i])) <= $limit; ++$i) {
        $trunc .= $sentences -> [$i];
    }

    # If the first sentence was too long (trunc is empty), truncate to word boundaries instead
    $trunc = $template -> truncate_words($text, $limit)
        if(!$trunc);

    return $trunc;
}


## @fn $ build_summary($template, $article)
# Build a summary section based on the specified article text. This will strip the
# text of all html, and then try to build a summary on a sentance boundary.
#
# @param template A reference to a template object.
# @param article  A string containing the article text.
# @return The summary text.
sub build_summary {
    my $template = shift;
    my $article  = shift;

    my $nohtml = $template -> html_strip($article);
    return truncate_text($template, $nohtml, 240);
}


## @fn $ lookup_user($dbh, $settings, $username)
# Given a username, fetch the userid associated with the username.
#
# @param dbh A reference to a database handle to issue queries through.
# @param settings A reference to a settings object.
# @param username The username of the user to find the userid for.
# @return The user id on success, undef on error.
sub lookup_user {
    my $dbh      = shift;
    my $settings = shift;
    my $username = shift;

    my $query = $dbh -> prepare("SELECT `user_id`
                                 FROM `".$settings -> {"database"} -> {"users"}."`
                                 WHERE `username` LIKE ?");
    $query -> execute($username)
        or die "Unable to execute user lookup: ".$dbh -> errstr."\n";

    my $row = $query -> fetchrow_arrayref;
    return $row ? $row -> [0] : undef;
}


# Do basic checks on the filename specfied by the user before doing any setup
die "Usage: import_xml.pl <xmlfile>\n"
    if(!$ARGV[0]);

die "The specified xml file does not exist, or is not a valid file.\n"
    if(!-f $ARGV[0]);


# Perform model setup
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

my $template = Webperl::Template -> new(settings => $settings,
                                        logger   => $logger)
    or die "Template setup failed\n";

my $modules = Webperl::Modules -> new(dbh      => $dbh,
                                      settings => $settings,
                                      logger   => $logger,
                                      metadata => $metadata)
    or die "Modules system init failed\n";

my $feeds = Newsagent::System::Feed -> new(dbh      => $dbh,
                                           settings => $settings,
                                           logger   => $logger,
                                           metadata => $metadata,
                                           roles    => $roles)
    or die "Feed system init failed\n";

my $article = Newsagent::System::Article -> new(dbh      => $dbh,
                                                settings => $settings,
                                                logger   => $logger,
                                                metadata => $metadata,
                                                roles    => $roles,
                                                feed     => $feeds)
    or die "Article system init failed\n";


my $dom = XML::LibXML -> load_xml(location => $ARGV[0]);
foreach my $item ($dom -> findnodes("channel/item")) {
    my $setfeeds  = build_feeds($feeds, $item -> findnodes("feeds/feed"));
    my $setlevels = build_levels($item -> findnodes("levels/level"));
    my $release   = build_release_time($item -> findnodes("date"));

    my ($user)    = $item -> findnodes("author");
    my ($title)   = $item -> findnodes("title");
    my ($content) = $item -> findnodes("article");

    my $adata = { "feeds"        => $setfeeds,
                  "release_time" => $release,
                  "full_summary" => 1,
                  "title"        => $title -> textContent,
                  "article"      => $content -> textContent,
                  "summary"      => build_summary($template, $content -> textContent),
                  "release_mode" => "visible",
                  "levels"       => $setlevels,
    };

    my $userid = lookup_user($dbh, $settings, $user -> textContent)
        or die "Unable to locate user '".$user -> textContent."'\n";

    my $dt = DateTime -> from_epoch(epoch => $release);

    print "Adding '".$adata -> {"title"}."' for $dt... ";
    $article -> add_article($adata, $userid, undef, 0, undef)
        or die "Addition failed: ".$article -> errstr()."\n";
    print "Done.\n";
}