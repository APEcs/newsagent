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
use List::Util qw(min);
use JSON;
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
        if($self -> {"roles"} -> user_has_capability($section -> {"metadata_id"}, $userid, "newsletter.schedule")) {
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
                    $result -> {"id_".$section -> {"schedule_id"}} -> {"next_run"} = $self -> get_newsletter_issuedates($section);
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
        or return $self -> self_error("Request for non-existant section '$id'");

    # Pull the schedule data in as most things using sections will need it.
    $section -> {"schedule"} = $self -> get_schedule_byid($section -> {"schedule_id"})
        or return undef;

    return $section;
}


## @method $ get_newsletter($name, $userid)
# Locate a newsletter by name.
#
# @param name   The name of the newsletter to fetch.
# @param userid An optional userid. If specified, the user must have
#               schedule access to the newsletter or a section of it.
# @return A reference to a hash containing the newsletter on success, undef on error.
sub get_newsletter {
    my $self   = shift;
    my $name   = shift;
    my $userid = shift;

    $self -> clear_error();

    # Determine whether the user can access the newsletter. If this
    # returns undef or a filled in hashref, it can be returned.
    my $newsletter = $self -> get_user_newsletter($name, $userid);
    return $newsletter if(!defined($newsletter) || $newsletter -> {"id"});

    return $self -> self_error("User $userid does not have permission to access $name");
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
    my $self     = shift;
    my $newsname = shift;
    my $userid   = shift;

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
        # This needs to handle access with no user - note that this is explicitly undef userid NOT simply !$userid
        # the latter could come from a faulty session, the former can only happen via explicit invocation.
        return $newsletter
            if(!defined($userid) || $self -> {"roles"} -> user_has_capability($newsletter -> {"metadata_id"}, $userid, "newsletter.schedule"));

        # user doesn't have simple access, check access to sections of this newsletter
        my $secth = $self -> {"dbh"} -> prepare("SELECT `metadata_id`
                                                 FROM `".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}."`
                                                 WHERE `schedule_id` = ?");
        $secth -> execute($newsletter -> {"id"})
            or return $self -> self_error("Unable to execute section query: ".$self -> {"dbh"} -> errstr);

        while(my $section = $secth -> fetchrow_arrayref()) {
            # If the user has schedule capability on the section, they can access the newsletter
            return $newsletter
                if($self -> {"roles"} -> user_has_capability($section -> [0], $userid, "newsletter.schedule"));
        }
    }

    return {};
}


## @method $ get_newsletter_datelist($newsletter, $count)
# Given a newsletter and an issue count, produce a hash describing the
# days on which the newsletter will be generated. If the newsletter is
# a manual release newsletter, this returns undef.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @param count      The number of issues to generate dates for
# @return a reference to a hash containing the newsletter date list
#         in the form { "YYYY" => { "MM" => [ DD, DD, DD], "MM" => [ DD, DD, DD] }, etc}
#         or undef
sub get_newsletter_datelist {
    my $self       = shift;
    my $newsletter = shift;
    my $count      = shift;

    return undef unless($newsletter -> {"schedule"});
    my $lastrun = $newsletter -> {"last_release"} || time();

    my $values = undef;
    my $cron  = DateTime::Event::Cron -> from_cron($newsletter -> {"schedule"});
    my $start = DateTime -> from_epoch(epoch => $lastrun);

    my $prev = $cron -> previous($start);
    my $late = 0;

    # check whether the last release went out, if not go back to it.
    if(!$newsletter -> {"last_release"} || $newsletter -> {"last_release"} < $prev -> epoch()) {
        $start = $cron -> previous($prev);
        $late = 1;
    }

    # iterate over the requested cron runs
    my $iter = $cron -> iterator(after => $start);
    for(my $i = 0; $i < $count; ++$i) {
        my $next = $iter -> next;
        push(@{$values -> {"hashed"} -> {$next -> year} -> {$next -> month}}, $next -> day);
        push(@{$values -> {"dates"}}, {"year"  => $next -> year,
                                       "month" => $next -> month,
                                       "day"   => $next -> day,
                                       "epoch" => $next -> epoch,
                                       "late"  => (!$i && $late)});
    }

    return $values;
}


## @method $ get_newsletter_datelist_json($newsletter, $count)
# Fetch the list of newsletter release dates as a json string. This does
# the same job as get_newsletter_datelist() except that it returns the
# newsletter release day information as a JSON-encoded string rather
# than a reference to a hash.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @param count      The number of issues to generate dates for
# @return A string containing the JSON encoded information about the release
#         dates. If th enewsletter is manual release, this returns an
#         empty string.
sub get_newsletter_datelist_json {
    my $self       = shift;
    my $newsletter = shift;
    my $count      = shift;

    my $data = $self -> get_newsletter_datelist($newsletter, $count);
    return "" unless($data);

    return encode_json($data -> {"hashed"});
}


## @method @ get_newsletter_daterange($newsletter, $issue)
# Determine the date range for a given newsletter issue. This attempts
# to work out, based on the schedule set in the specified newsletter
# and an optional start date, when the current issue will be released, and
# when the previous issue should have been released. If the newsletter
# has no schedule - it is manual release - this can't produce a range.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @param issue      A reference to an array containing the issue year, month, and day.
# @return An array of two values: the previous issue release date, and
#         the next issue release date, both as unix timestamps. If the
#         newsletter is a manual release, this returns undefs
sub get_newsletter_daterange {
    my $self       = shift;
    my $newsletter = shift;
    my $dates      = shift;
    my $issue      = shift;

    if($newsletter -> {"schedule"}) {
        my $start = DateTime -> now(); # Start off with a fallback of now

        my $firstyear  = $dates -> {"dates"} -> [0] -> {"year"};
        my $firstmonth = $dates -> {"dates"} -> [0] -> {"month"};
        my $firstday   = $dates -> {"dates"} -> [0] -> {"day"};
        my $usenext    = 0;

        # If an issue day has been set, try to use it
        if($issue) {
            $start = eval { DateTime -> new(year  => $issue -> [0],
                                            month => $issue -> [1],
                                            day   => $issue -> [2]) };
            $self -> {"logger"} -> die_log($self -> {"cgi"}, "Bad issue date specified") if($@);

            $usenext = ($issue -> [0] == $firstyear && $issue -> [1] == $firstmonth && $issue -> [2] == $firstday);
        } else {
            $start = eval { DateTime -> new(year  => $firstyear,
                                            month => $firstmonth,
                                            day   => $firstday) };
            $self -> {"logger"} -> die_log($self -> {"cgi"}, "Bad start day in dates data") if($@);
            $usenext = 1;
        }

        my $cron = DateTime::Event::Cron -> new($newsletter -> {"schedule"});
        my $next_time = $cron -> next($start);
        my $prev_time = $cron -> previous($next_time);

        # Override the previous date for the next release, capturing everything
        # that should be released since the last release.
        $prev_time = DateTime -> from_epoch(epoch => $newsletter -> {"last_release"})
            if($usenext);

        return ($prev_time -> epoch(), $next_time -> epoch(), $usenext);
    } else {
        return (undef, time(), 1);
    }
}


## @method $ get_newsletter_issuedates($newsletter)
# given a schedule, determine when the next release will (or should have) happen,
# and when the one after that will be.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @return A refrence to an array of hashes containing the issue dates on success,
#         undef if the newsletter is a maual release newsletter.
sub get_newsletter_issuedates {
    my $self       = shift;
    my $newsletter = shift;

    $self -> clear_error();

    my $data = $self -> get_newsletter_datelist($newsletter, 2)
        or return $self -> self_error("Attempt to fetch date list for manual release newsletter");

    my $result = [];
    foreach my $day (@{$data -> {"dates"}}) {
        push(@{$result}, {"late" => $day -> {"late"},
                          "timestamp" => $day -> {"epoch"}});
    }

    return $result;
}


## @method @ get_issuedate($article)
# Given an article, complete with section and schedule information included,
# determine when the article should appear in a newsletter. Note that this
# will only return values for articles associated with automatic newsletters.
#
# @param article A reference to the article to get the newsletter date for.
# @return The article release time, and a flag indicating whether the release
#         is late
sub get_issuedate {
    my $self    = shift;
    my $article = shift;

    return (undef, undef)
        unless($article -> {"section_data"} -> {"schedule"} -> {"schedule"});

    # first get the times of releases
    my $releases = $self -> get_newsletter_issuedates($article -> {"section_data"} -> {"schedule"});

    # next is easy - it's the first of the releases
    if($article -> {"release_mode"} eq "next") {
        return ($releases -> [0] -> {"timestamp"}, $releases -> [0] -> {"late"});

    } elsif($article -> {"release_mode"} eq "after") {

        # 'after' articles can fall into several places. Either it's some time before he first release
        # (in which case it is due to go out in it), or it is in a later release.
        # Next release check first...
        if($article -> {"release_time"} < $releases -> [0] -> {"timestamp"}) {
            return ($releases -> [0] -> {"timestamp"}, $releases -> [0] -> {"late"});

        # It's not in the next release, so work out which future one it's in
        } else {
            my $cron  = DateTime::Event::Cron -> new($article -> {"section_data"} -> {"schedule"} -> {"schedule"});
            my $issue = $cron -> next(DateTime -> from_epoch(epoch => $article -> {"release_time"}));

            return ($issue -> epoch, $issue -> epoch < time());
        }
    }
}


## @method $ late_release($newsletter)
# Determine whether the specified newsletter has not released an issue when
# it should have already done so. This checks to see whether the specified
# newsletter is late in esnding out an issue - manual release newsletters
# are never late, so this will always return false for them.
#
# @param newsletter Either a reference to a hash containing the newsletter
#                   to check, or the name of the newsletter.
# @return true if the newsletter is late, false if it is not, undef on error.
sub late_release {
    my $self       = shift;
    my $newsletter = shift;

    $self -> clear_error();

    # first get the newsletter - either using the newsletter passed,
    # or searching for it by name
    my $newsletter_data;
    if(ref($newsletter) eq "HASH") {
        $newsletter_data = $newsletter;
    } else {
        $newsletter_data = $self -> get_newsletter($newsletter)
        or return undef;
    }

    # manual release newsletters are never late
    return 0 unless($newsletter_data -> {"schedule"});

    # automatic releae newsletters can be, so find out when a release will
    # happen, or should have happend by
    my $releases = $self -> get_newsletter_issuedates($newsletter_data);

    # All we really care about is whether the first issue is late
    return $releases -> [0] -> {"late"};
}



sub get_newsletter_messages {
    my $self     = shift;
    my $newsid   = shift;
    my $userid   = shift;
    my $getnext  = shift;
    my $mindate  = shift;
    my $maxdate  = shift;
    my $fulltext = shift;

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
        # User can only even potentially edit if one is defined and non-zero.
        $section -> {"editable"} = $userid && $self -> {"roles"} -> user_has_capability($section -> {"metadata_id"}, $userid, "newsletter.schedule");

        # Fetch the messages even if the user can't edit the section, so they can
        # see the content in context
        $section -> {"messages"} = $self -> _fetch_section_messages($newsid, $section -> {"id"}, $getnext, $mindate, $maxdate, $fulltext);
    }

    return $sections;
}


sub reorder_articles_fromsortdata {
    my $self     = shift;
    my $sortdata = shift;
    my $userid   = shift;

    $self -> clear_error();

    # Each entry in $sortdata should be of the form list-<schedule_id>-<section_id>_msg-<article_id>
    # to each section has its own ordering, so the list needs parsing and processing to make updating
    # a bit more sane...
    my $sections;
    my $sid = 1;
    my $schedule_id;
    foreach my $row (@{$sortdata}) {
        my ($schedule, $section, $article) = $row =~ /^list-(\d+)-(\d+)_msg-(\d+)$/;

        # using straight ! is safe here; valid IDs are always >0
        $self -> self_error("Malformed data in provides sort data")
            if(!$schedule || !$section || !$article);

        $schedule_id = $schedule if(!$schedule_id);
        $sections -> {$section} -> {"order"} = $sid++ if(!$sections -> {$section} -> {"order"});

        push(@{$sections -> {$section} -> {"articles"}}, $article);
    }

    foreach my $section_id (sort { $sections -> {$a} -> {"order"} <=> $sections -> {$b} -> {"order"} } keys(%{$sections})) {
        # Make sure the user has permission to do anything in the section
        my $section = $self -> get_section($section_id)
            or return undef;

        if($self -> {"roles"} -> user_has_capability($section -> {"metadata_id"}, $userid, "newsletter.schedule")) {
            # User can edit the section, so set the roder of the articles within it
            for(my $pos = 0; $pos < scalar(@{$sections -> {$section_id} -> {"articles"}}); ++$pos) {
                $self -> update_section_relation($sections -> {$section_id} -> {"articles"} -> [$pos], $schedule_id, $section_id, $pos + 1)
                    or return undef;
            }
        }
    }

    return 1;
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
        or return $self -> self_error("Request for non-existant section '$id'");

    # Pull the digest data in
    $section -> {"digest"} = $self -> get_digest($section -> {"digest_id"})
        or return undef;

    return $section;
}


# ============================================================================
#  Relation control

## @method $ add_section_relation($articleid, $scheduleid, $sectionid, $sort_order)
# Create a relation between the specified article and the provided section of a schedule.
#
# @param articleid  The ID of the article to set up the relation for.
# @param scheduleid The ID of the schedule the article should be part of.
# @param sectionid  The ID of the section in the schedule to add the article to.
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


## @method $ update_section_relation($articleid, $scheduleid, $sectionid, $sort_order)
# Update the section and sort order of an article. This will not move the article to
# a new schedule, but it can move it to a different section within the schedule, and
# change its location within the section. All the arguments are required - including
# the sort order, unlike with add_section_relation() - and the section must be part
# of the specified section.
#
# @param articleid  The ID of the article to update the relation for.
# @param scheduleid The ID of the schedule the article is part of.
# @param sectionid  The ID of the section in the schedule the article should be in.
# @param sort_order The position in the section to assign to the relation.
# @return true on success, undef on error.
sub update_section_relation {
    my $self       = shift;
    my $articleid  = shift;
    my $scheduleid = shift;
    my $sectionid  = shift;
    my $sort_order = shift;

    $self -> clear_error();

    my $moveh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"articlesection"}."`
                                             SET `section_id` = ?, `sort_order` = ?
                                             WHERE `article_id` = ?
                                             AND `schedule_id` = ?");
    $moveh -> execute($sectionid, $sort_order, $articleid, $scheduleid)
        or return $self -> self_error("Unable to perform article section relation update: ". $self -> {"dbh"} -> errstr);

    return 1;
}


# ============================================================================
#  Internal implementation

sub _fetch_section_messages {
    my $self     = shift;
    my $schedid  = shift;
    my $secid    = shift;
    my $getnext  = shift;
    my $mindate  = shift;
    my $maxdate  = shift;
    my $fulltext = shift;
    my $filter   = "";

    if($getnext) {
        $filter  = " AND (`a`.`release_mode` = 'next' OR (`a`.`release_mode` = 'after'";
    } else {
        $filter  = " AND (`a`.`release_mode` = 'after'";
    }

    $filter .= " AND `a`.`release_time` > $mindate"  if(defined($mindate) && $mindate =~ /^\d+$/);
    $filter .= " AND `a`.`release_time` <= $maxdate" if($maxdate && $maxdate =~ /^\d+$/);
    $filter .= ")";
    $filter .= ")" if($getnext);

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
