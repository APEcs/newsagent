## @file
# This file contains the implementation of the schedule model.
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
package Newsagent::System::Schedule;

use strict;
use DateTime::Event::Cron;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;
use Data::Dumper;

## @cmethod $ new(%args)
# Create a new Schedule object to manage tag allocation and lookup.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Schedule object, or undef if a problem occured.
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

## @method $ get_user_schedule_sections($userid)
# Fetch a list of the shedules and schedule sections the user has access to
# post messages in. This goes through the scheduled release settings and
# the sections for the same, and generates a hash containing the lists of
# each that the user can post to.
#
# @param userid The ID of the user to get the schedules and sections for.
# @return A reference to a hash containing the schedule and section data on
#         success, undef on error.
sub get_user_schedule_sections {
    my $self   = shift;
    my $userid = shift;

    $self -> clear_error();

    # What we're /actually/ interested in here is which sections the user
    # can post message to, the schedules they can post to come along as a
    # resuslt of that information. So we need to traverse the list of sections
    # recording which ones the user has permission to post to, and then
    # pull in the data for the schedules later as a side-effect.

    my $sectionh = $self -> {"dbh"} -> prepare("SELECT sec.id, sec.metadata_id, sec.name, sec.schedule_id, sch.name AS schedule_name, sch.description AS schedule_desc, sch.schedule
                                                FROM ".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}." AS sec,
                                                     ".$self -> {"settings"} -> {"database"} -> {"schedules"}." AS sch
                                                WHERE sch.id = sec.schedule_id
                                                ORDER BY sch.description, sec.sort_order");
    $sectionh -> execute()
        or return $self -> self_error("Unable to execute section lookup query: ".$self -> {"dbh"} -> errstr);

    my $result = {};
    while(my $section = $sectionh -> fetchrow_hashref()) {
        if($self -> {"roles"} -> user_has_capability($section -> {"metadata_id"}, $userid, "schedule")) {
            # Store the section name and id.
            push(@{$result -> {"id_".$section -> {"schedule_id"}} -> {"sections"}},
                 {"value" => $section -> {"id"},
                  "name"  => $section -> {"name"}});

            # And set the schedule fields if needed.
            if(!$result -> {"id_".$section -> {"schedule_id"}} -> {"schedule_name"}) {
                $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule_name"} = $section -> {"schedule_name"};
                $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule_desc"} = $section -> {"schedule_desc"};

                # Work out when the next two runs of the schedule are
                if($section -> {"schedule"}) {
                    my $cron = DateTime::Event::Cron -> new($section -> {"schedule"});
                    my $next_time = undef;
                    for(my $i = 0; $i < 2; ++$i) {
                        $next_time = $cron -> next($next_time);
                        push(@{$result -> {"id_".$section -> {"schedule_id"}} -> {"next_run"}}, $next_time -> epoch);
                    }

                    $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule_mode"} = "auto";
                } else {
                    $result -> {"id_".$section -> {"schedule_id"}} -> {"next_run"} = [ "", "" ];
                    $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule_mode"} = "manual";
                }

                # And store the cron for later user in the view
                $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule"} = $section -> {"schedule"};
            }
        }
    }

    foreach my $id (sort {$result -> {$a} -> {"schedule_desc"} cmp $result -> {$b} -> {"schedule_desc"}} keys(%{$result})) {
        push(@{$result -> {"_schedules"}}, {"value" => $result -> {$id} -> {"schedule_name"},
                                            "name"  => $result -> {$id} -> {"schedule_desc"},
                                            "mode"  => $result -> {$id} -> {"schedule_mode"}});
    }

    return $result;
}


## @method $ get_schedule_byid($id)
# Given a schedule ID, fetch the data for the schedule with that id.
#
# @param id The ID of the schedule to fetch the data for.
# @return A reference to a hash containing the schedule data on success,
#         undef on error or if the schedule does not exist.
sub get_schedule_byid {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $schedh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"schedules"}."`
                                              WHERE `id` = ?");
    $schedh -> execute($id)
        or return $self -> self_error("Unable to execute schedule lookup query: ".$self -> {"dbh"} -> errstr);

    return $schedh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existant schedule $id");
}


## @method $ get_schedule_byname($name)
# Given a schedule name, fetch the data for the schedule with that name. If
# you are unwise enough to have multiple schedules with the same name, this
# will return the first.
#
# @param name The name of the schedule to fetch the data for.
# @return A reference to a hash containing the schedule data on success,
#         undef on error or if the schedule does not exist.
sub get_schedule_byname {
    my $self = shift;
    my $name = shift;

    $self -> clear_error();

    my $shedh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"schedules"}."`
                                             WHERE `name` LIKE ?
                                             LIMIT 1");
    $shedh -> execute($name)
        or return $self -> self_error("Unable to execute schedule lookup query: ".$self -> {"dbh"} -> errstr);

    return $shedh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existant schedule $name");
}


## @method $ get_section($id)
# Given a section ID, return the data for the section, and the schedule it
# is part of.
#
# @param id The ID of the section to fetch the data for.
# @return A reference to the section data (with the schedule in a key
#         called "schedule") on success, undef on error/bad section
sub get_section {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $secth = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}."`
                                             WHERE `id` = ?");
    $secth -> execute($id)
        or return $self -> self_error("Unable to execute section lookup query: ".$self -> {"dbh"} -> errstr);

    my $section = $secth -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existant section $id");

    # Pull the schedule data in as most things using sections will need it.
    $section -> {"schedule"} = $self -> get_schedule_byid($section -> {"schedule_id"})
        or return undef;

    return $section;
}


## @method $ active_newsletter($newsname, $userid)
# Obtain the data for the active newsletter. If no ID is provided, or the user
# does not have schedule access to the newsletter or any of its sections, this
# will choose the first newsletter the user has schedule access to (in
# alphabetical order) and return the data for that.
#
# @param newsname The name of the active newsletter.
# @param userid   The ID of the user fetching the newsletter data.
# @return A reference to a hash containing the newsletter data to use as the active newsletter.
sub active_newsletter {
    my $self     = shift;
    my $newsname = shift;
    my $userid   = shift;

    $self -> clear_error();

    # Determine whether the user can access the newsletter. If this
    # returns undef or a filled in hashref, it can be returned.
    my $newsletter = $self -> get_user_newsletter($newsname, $userid);
    return $newsletter if(!defined($newsletter) || $newsletter -> {"id"});

    # Get here and the user does not have access to the requested newsletter. Find the
    # first newsletter the user does have access to.
    my $newsh = $self -> {"dbh"} -> prepare("SELECT `name`
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"schedules"}."`
                                             ORDER BY `name`");
    $newsh -> execute()
        or return $self -> self_error("Unable to execute schedule query: ".$self -> {"dbh"} -> errstr);

    while(my $row = $newsh -> fetchrow_arrayref()) {
        # check the user's access to the newsletter or its sections
        $newsletter = $self -> get_user_newsletter($row -> [0], $userid);
        return $newsletter if(!defined($newsletter) || $newsletter -> {"id"});
    }

    return $self -> self_error("User does not have any access to any newsletters");
}


## @method $ get_user_newsletter($newsname, $userid)
# Determine whether the user has schedule access to the specified
# newsletter, or one of the sections within the newsletter.
#
# @param newsname The ID of the newsletter to fetch
# @param userid The Id of the user requesting access.
# @return A reference to a hash containing the newsletter on success,
#         a reference to an empty hash if the user does not have access,
#         undef on error.
sub get_user_newsletter {
    my $self   = shift;
    my $newsname = shift;
    my $userid = shift;

    $self -> clear_error();

    # Try to locate the requested schedule
    my $schedh = $self -> {"dbh"} -> prepare("SELECT *
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"schedules"}."`
                                              WHERE `name` LIKE ?");
    $schedh -> execute($newsname)
        or return $self -> self_error("Unable to execute newsletter query: ".$self -> {"dbh"} -> errstr);

    # If the newsletter information has been found, determine whether the user has schedule access to
    # it, or a section inside it
    my $newsletter = $schedh -> fetchrow_hashref();
    if($newsletter) {
        # simple case: user has schedule access to the newsletter and all sections
        return $newsletter
            if($self -> {"roles"} -> user_has_capability($newsletter -> {"metadata_id"}, $userid, "schedule"));

        # user doesn't have simple access, check access to sections of this newsletter
        my $secth = $self -> {"dbh"} -> prepare("SELECT `metadata_id`
                                                 FROM `".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}."`
                                                 WHERE `schedule_id` = ?");
        $secth -> execute($newsletter -> {"id"})
            or return $self -> self_error("Unable to execute section query: ".$self -> {"dbh"} -> errstr);

        while(my $section = $secth -> fetchrow_arrayref()) {
            # If the user has schedule capability on the section, they can access the newsletter
            return $newsletter
                if($self -> {"roles"} -> user_has_capability($section -> [0], $userid, "schedule"));
        }
    }

    return {};
}


## @method @ get_newsletter_daterange($newsletter, $checkdate)
# Determine the date range for a given newsletter issue. This attempts
# to work out, based on the schedule set in the specified newsletter
# and an optional start date, when the current issue will be released, and
# when the previous issue should have been released. If the newsletter
# has no schedule - it is manual release - this can't produce a range.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @param checkdate  An optional unix timestamp to use. The end time is
#                   taken as the issue date that follows this timestamp,
#                   and the start is the issue date that prceeds it. If
#                   not set, this defaults to the current time.
# @return An array of two values: the previous issue release date, and
#         the next issue release date, both as unix timestamps. If the
#         newsletter is a manual release, this returns undefs
sub get_newsletter_daterange {
    my $self       = shift;
    my $newsletter = shift;
    my $checkdate  = shift || time();

    if($newsletter -> {"schedule"}) {
        my $cron = DateTime::Event::Cron -> new($newsletter -> {"schedule"});
        my $next_time = $cron -> next(DateTime -> from_epoch(epoch => $checkdate));
        my $prev_time = $cron -> previous($next_time);

        return ($prev_time -> epoch(), $next_time -> epoch());
    } else {
        return (undef, undef);
    }
}


sub get_newsletter_messages {
    my $self    = shift;
    my $newsid  = shift;
    my $userid  = shift;
    my $getnext = shift;
    my $mindate = shift;
    my $maxdate = shift;

    $self -> clear_error();

    # First get all the sections, ordered by the order they appear in the
    # newsletter.
    my $secth = $self -> {"dbh"} -> prepare("SELECT *
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}."`
                                             WHERE `schedule_id` = ?
                                             ORDER BY `sort_order`");
    $secth -> execute($newsid)
        or return $self -> self_error("Unable to execute section query: ".$self -> {"dbh"} -> errstr);

    my $sections = $secth -> fetchall_arrayref({})
        or return $self -> self_error("Unable to fetch results for section query");

    return $self -> self_error("No sections defined for newsletter $newsid")
        if(!scalar(@{$sections}));

    # Go through the sections, working out which ones the user can edit, and
    # fetching the messages for the sections
    foreach my $section (@{$sections}) {
        $section -> {"editable"} = $self -> {"roles"} -> user_has_capability($section -> {"metadata_id"}, $userid, "schedule");

        # Fetch the messages even if the user can't edit the section, so they can
        # see the content in context
        $section -> {"messages"} = $self -> _fetch_section_message_summaries($newsid, $section -> {"id"}, $getnext, $mindate, $maxdate);
    }

    return $sections;
}


# ============================================================================
#  Digesting


## @method $ get_digest($id)
# Given a digest ID, fetch the data for the digest with that id.
#
# @param id The ID of the digest to fetch the data for.
# @return A reference to a hash containing the digest data on success,
#         undef on error or if the digest does not exist.
sub get_digest {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $digesth = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"digests"}."`
                                               WHERE `id` = ?");
    $digesth -> execute($id)
        or return $self -> self_error("Unable to execute digest lookup query: ".$self -> {"dbh"} -> errstr);

    return $digesth -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existant digest $id");
}


## @method $ get_digest_section($id)
# Given a digest section ID, return the data for the section, and the digest it
# is part of.
#
# @note This DOES NOT fetch the data for the source schedule/section.
#
# @param id The ID of the digest section to fetch the data for.
# @return A reference to the digest section data (with the digest in a key
#         called "digest") on success, undef on error/bad section
sub get_digest_section {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $secth = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"digest_sections"}."`
                                             WHERE `id` = ?");
    $secth -> execute($id)
        or return $self -> self_error("Unable to execute section lookup query: ".$self -> {"dbh"} -> errstr);

    my $section = $secth -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existant section $id");

    # Pull the digest data in
    $section -> {"digest"} = $self -> get_digest($section -> {"digest_id"})
        or return undef;

    return $section;
}


# ============================================================================
#  Relation control

## @method $ add_section_relation($articleid, $scheduleid, $sectionid, $sort_order)
# Greate a relation between the specified article and the provided section of a schedule.
#
# @param articleid  The ID of the article to set up the relation for.
# @param scheduleid The ID of the schedule the article should be part of.
# @param sectionid  The ID of the section in the schefule to add the article to.
# @param sort_order The position in the section to add the article at. If this is
#                   omitted or zero, the article is added at the end of the section.
#                   Note that multiple articles may have the same sort_order, and
#                   no reordering of surrounding articles is done.
# @return true on success, undef on error.
sub add_section_relation {
    my $self       = shift;
    my $articleid  = shift;
    my $scheduleid = shift;
    my $sectionid  = shift;
    my $sort_order = shift;

    $self -> clear_error();

    # If there is no sort_order set, work out the next one.
    # NOTE: this is potentially vulnerable to atomicity violation problems: the
    # max value determined here could have changed by the time the code gets
    # to the insert. However, in this case, that's not a significant problem
    # as articles sharing sort_order values is safe (or at least non-calamitous)
    if(!$sort_order) {
        my $posh = $self -> {"dbh"} -> prepare("SELECT MAX(`sort_order`)
                                                FROM `".$self -> {"settings"} -> {"database"} -> {"articlesection"}."`
                                                WHERE `schedule_id` = ?
                                                AND `section_id` = ?");
        $posh -> execute($scheduleid, $sectionid)
            or return $self -> self_error("Unable to perform article section sort_order lookup: ". $self -> {"dbh"} -> errstr);

        my $posrow = $posh -> fetchrow_arrayref();
        $sort_order = $posrow ? $posrow -> [0] + 1 : 1;
    }

    # And do the insert
    my $secth = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articlesection"}."`
                                             (`article_id`, `schedule_id`, `section_id`, `sort_order`)
                                             VALUES(?, ?, ?, ?)");
    my $rows = $secth -> execute($articleid, $scheduleid, $sectionid, $sort_order);
    return $self -> self_error("Unable to perform article section relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article section relation insert failed, no rows inserted") if($rows eq "0E0");

    return 1;
}


# ============================================================================
#  Internal implementation

sub _fetch_section_message_summaries {
    my $self    = shift;
    my $schedid  = shift;
    my $secid   = shift;
    my $getnext = shift;
    my $mindate = shift;
    my $maxdate = shift;
    my $filter  = "";

    if($getnext) {
        $filter  = " AND (`a`.`release_mode` = 'next' OR `a`.`release_mode` = 'after')";
    } else {
        $filter  = " AND (`a`.`release_mode` = 'after')";
    }

    $filter .= " AND `a`.`release_time` > $mindate"  if($mindate && $mindate =~ /^\d+$/);
    $filter .= " AND `a`.`release_time` <= $maxdate" if($maxdate && $maxdate =~ /^\d+$/);

    my $query = "SELECT `a`.`id`, `a`.`title`, `a`.`summary`, `a`.`release_mode`, `a`.`release_time`
                 FROM `".$self -> {"settings"} -> {"database"} -> {"articlesection"}."` AS `s`,
                      `".$self -> {"settings"} -> {"database"} -> {"articles"}."` AS `a`
                 WHERE `a`.`id` = `s`.`article_id`
                 AND `s`.`schedule_id` = ?
                 AND `s`.`section_id` = ?
                 $filter
                 ORDER BY `s`.`sort_order`";

    # Pull out the messages ordered as set by the user
    my $messh = $self -> {"dbh"} -> prepare($query);
    $messh -> execute($schedid, $secid)
        or return $self -> self_error("Unable to perform section article lookup: ". $self -> {"dbh"} -> errstr);

    return $messh -> fetchall_arrayref({});
}

1;
