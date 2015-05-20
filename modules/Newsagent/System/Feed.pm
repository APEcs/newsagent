## @file
# This file contains the implementation of the feed model.
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

## @class
package Newsagent::System::Feed;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;
use Data::Dumper;

## @cmethod $ new(%args)
# Create a new Article object to manage tag allocation and lookup.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Article object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Check that the required objects are present
    return Webperl::SystemModule::set_error("No metadata object available.") if(!$self -> {"metadata"});
    return Webperl::SystemModule::set_error("No roles object available.")    if(!$self -> {"roles"});

    return $self;
}


# ============================================================================
#  Data access

## @method $ create_feed($name, $description, $default_url, $parent_id)
# Create a new feed
#
# @param name        The name of the feed to create
# @param description The description to give the feed
# @param default_url The URL to set for the feed
# @param parent_id   The ID of the metadata context to add this feed as a
#                    child of.
# @return The new feed ID on success, undef on error
sub create_feed {
    my $self        = shift;
    my $name        = shift;
    my $description = shift;
    my $default_url = shift;
    my $parent_id   = shift;

    $self -> clear_error();

    # make a context first
    my $metadata_id = $self -> {"metadata"} -> create($parent_id)
        or return $self -> self_error("Unable to create new metadata context: ".$self -> {"metadata"} -> errstr());

    # and now make a new feed
    my $feedh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                             (`metadata_id`, `name`, `description`, `default_url`)
                                             VALUES(?, ?, ?, ?)");
    my $rows = $feedh -> execute($metadata_id, $name, $description, $default_url);
    return $self -> self_error("Unable to perform feed insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Feed insert failed, no rows inserted") if($rows eq "0E0");

    my $feedid = $self -> {"dbh"} -> {"mysql_insertid"};

    $self -> {"metadata"} -> attach($metadata_id);
    return $feedid;
}


## @method $ get_feeds($filter)
# Fetch a list of all feeds defined in the system. This will generate an array
# containing the data for all the feeds, whether the user has any author
# access or not. This is intended to support listing pages like FeedList.
#
# @param filter An optional reference to an array of feed IDs to filter on.
# @return A reference to an array of hashrefs, each hashref contains feed
#         information, or undef on error.
sub get_feeds {
    my $self   = shift;
    my $filter = shift;

    $self -> clear_error();

    print STDERR "Filter: ".($filter ? Dumper($filter) : "not set")."\n";

    # If filters have been specified, build the filtering parameter
    my @params = ();
    my $query = "";
    if($filter) {
        push(@params, @{$filter});
        $query = "WHERE `id` IN(?".(",?" x (scalar(@{$filter}) - 1)).")";
    }

    my $feedsh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                              $filter
                                              ORDER BY `description`");
    $feedsh -> execute(@params)
        or return $self -> self_error("Unable to execute user feeds query: ".$self -> {"dbh"} -> errstr);

    return ($feedsh -> fetchall_arrayref({}) || $self -> self_error("No system defined feeds available"));
}


## @method $ get_feeds_tree(void)
# Generate a hash describing the feeds available in the system. This generates a
# hash that stores the feedinformation in a form that allows the relationships
# between feeds to be shown.
#
# @return A reference to a hash containing the feed hierarchy data on success,
#         undef on error.
sub get_feeds_tree {
    my $self = shift;

    my $feedh = $self -> {"dbh"} -> prepare("SELECT *
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                             ORDER BY `name`");
    # Fetch all the feeds as a flat list of rows
    $feedh -> execute()
        or return $self -> self_error("Unable to execute feed query: ".$self -> {"dbh"} -> errstr);

    # While fetching the feeds, try to build a tree
    my $tree = { "base" => { "1"  => 1 } };
    while(my $feed = $feedh -> fetchrow_hashref()) {
        # get the parent metadata ID
        my $parentid = $self -> {"metadata"} -> parentid($feed -> {"metadata_id"});
        return $self -> self_error("Request for bad metadata parent for ".$feed -> {"name"})
            if(!defined($parentid));

        if(!$parentid) {
            $parentid = "0";
            $tree -> {"base"} -> {$parentid} = 1;
        }

        $tree -> {$feed -> {"metadata_id"}} -> {"parent"} = $parentid;
        push(@{$tree -> {$parentid} -> {"children"}}, $feed -> {"metadata_id"});

        push(@{$tree -> {$feed -> {"metadata_id"}} -> {"feeds"}}, $feed);
    }

    return $tree;
}


## @method $ get_user_feeds($userid)
# Obtain the list of feeds the user has permission to post from. This
# checks through the list of available feeds, and determines whether
# the user is able to post messages from that feed before adding it to
# the list of feeds available to the user.
#
# @param userid The ID of the user requesting the feed list.
# @param levels A reference to an array of levels, as returned by get_all_levels()
# @return A reference to an array of hashrefs. Each hashref contains a feed
#         available to the user as a pair of key/value pairs.
sub get_user_feeds {
    my $self   = shift;
    my $userid = shift;
    my $levels = shift;

    $self -> clear_error();

    my $feedsh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                              ORDER BY `description`");
    $feedsh -> execute()
        or return $self -> self_error("Unable to execute user feeds query: ".$self -> {"dbh"} -> errstr);

    my @feedlist = ();
    while(my $feed = $feedsh -> fetchrow_hashref()) {
        foreach my $level (@{$levels}) {
            if($self -> {"roles"} -> user_has_capability($feed -> {"metadata_id"}, $userid, $level -> {"capability"})) {
                push(@feedlist, {"desc"       => $feed -> {"description"},
                                 "name"       => $feed -> {"name"},
                                 "id"         => $feed -> {"id"},
                                 "metadataid" => $feed -> {"metadata_id"}});
                last;
            }
        }
    }

    return \@feedlist;
}


## @method $ get_feed_url($feedname)
# Attempt to obtain a viewer URL for the specified feed. This checks against the feed
# table for a matching feed, and if one is not found there it checks the feedurls
# table.
#
# @param feedname The name of the feed to fetch a viewer URL for
# @return A string containing a viewer URL or undef on error/not found.
sub get_feed_url {
    my $self     = shift;
    my $feedname = shift;

    # Try getting a matching feed first, and if successful return its URL
    my $feed = $self -> get_feed_byname($feedname);
    return $feed -> {"default_url"} if($feed);

    # If that failed, try the feed_urls table
    $feed = $self -> get_feed_url_byname($feedname);
    return $feed -> {"url"} if($feed);

    return undef;
}


## @method $ add_feed_relations($articleid, $feeds)
# Add a relation between an article and one or more feeds
#
# @param articleid The ID of the article to add the relation for.
# @param feeds     A reference to an array of feed IDs to add relations to.
# @return True on success, undef on error.
sub add_feed_relations {
    my $self      = shift;
    my $articleid = shift;
    my $feeds     = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articlefeeds"}."`
                                            (`article_id`, `feed_id`)
                                            VALUES(?, ?)");
    foreach my $feedid (@{$feeds}) {
        my $rows = $newh -> execute($articleid, $feedid);
        return $self -> self_error("Unable to perform feed relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
        return $self -> self_error("Feed relation insert failed, no rows inserted") if($rows eq "0E0");
    }

    return 1;
}


## @method $ get_feed_byid($feedid)
# Obtain the data for the feed with the specified name, if possible.
#
# @param feedid The ID of the feed to fetch the data for.
# @return A reference to the feed data hash on success, undef on failure
sub get_feed_byid {
    my $self   = shift;
    my $feedid = shift;

    my $feedh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                              WHERE `id` = ?");
    $feedh -> execute($feedid)
        or return $self -> self_error("Unable to execute feed lookup query: ".$self -> {"dbh"} -> errstr);

    my $feedrow = $feedh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existent feed '$feedid', giving up");

    return $feedrow;
}


## @method $ get_feed_byname($name)
# Obtain the data for the feed with the specified name, if possible.
#
# @param name The name of the feed to get the ID for
# @return A reference to the feed data hash on success, undef on failure
sub get_feed_byname {
    my $self = shift;
    my $feed = shift;

    my $feedh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"feeds"}."`
                                              WHERE `name` LIKE ?");
    $feedh -> execute($feed)
        or return $self -> self_error("Unable to execute feed lookup query: ".$self -> {"dbh"} -> errstr);

    my $feedrow = $feedh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existent feed '$feed', giving up");

    return $feedrow;
}


## @method $ get_feed_url_byname($name)
# Obtain the data for the feed_url with the specified name, if possible.
#
# @param name The name of the feed_url to get the ID for
# @return A reference to the feed_url data hash on success, undef on failure
sub get_feed_url_byname {
    my $self = shift;
    my $name = shift;

    my $feedh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"feedurls"}."`
                                              WHERE `name` LIKE ?");
    $feedh -> execute($name)
        or return $self -> self_error("Unable to execute feed_url lookup query: ".$self -> {"dbh"} -> errstr);

    my $feedrow = $feedh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existent feed_url '$name', giving up");

    return $feedrow;
}


## @method $ get_metadata_id($feed)
# Given a feed name, obtain the ID of the metadata context associated with
# the feed.
#
# @param feed     The name of the feed to fetch the metadata conext Id for.
# @return The metadata context ID on success, undef if the feed does not exist.
sub get_metadata_id {
    my $self = shift;
    my $feed = shift;

    my $feeddata = $self -> get_feed_byname($feed)
        or return undef;

    return $feeddata -> {"metadata_id"};
}

1;
