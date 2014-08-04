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
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;

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

    my $sectionh = $self -> {"dbh"} -> prepare("SELECT sec.id, sec.metadata_id, sec.name, sec.schedule_id, sch.name AS schedule_name, sch.schedule
                                                FROM ".$self -> {"settings"} -> {"database"} -> {"schedule_sections"}." AS sec,
                                                     ".$self -> {"settings"} -> {"database"} -> {"schedules"}." AS sch
                                                WHERE sch.id = sec.schedule_id
                                                ORDER BY sch.name, sec.sort_order");
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

                # Work out when the next two runs of the schedule are
                if($section -> {"schedule"}) {
                    my $cron = DateTime::Event::Cron -> new($section -> {"schedule"});
                    my $next_time = undef;
                    for(my $i = 0; $i < 2; ++$i) {
                        $next_time = $cron -> next($next_time);
                        push(@{$result -> {"id_".$section -> {"schedule_id"}} -> {"next_run"}}, $next_time -> epoch);
                    }
                } else {
                    $result -> {"id_".$section -> {"schedule_id"}} -> {"next_run"} = [ "", "" ];
                }

                # And store the cron for later user in the view
                $result -> {"id_".$section -> {"schedule_id"}} -> {"schedule"} = $section -> {"schedule"};
            }
        }
    }

    foreach my $id (sort(keys(%{$result}))) {
        push(@{$result -> {"_schedules"}}, {"value" => substr($id, 3),
                                            "name"  => $result -> {$id} -> {"schedule_name"}});
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


sub add_section_relation {
    my $self       = shift;
    my $articleid  = shift;
    my $scheduleid = shift;
    my $sectionid  = shift;
    my $priority   = shift;

    $self -> clear_error();

    my $secth = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articlesection"}."`
                                             (`article_id`, `schedule_id`, `section_id`, `priority`)
                                             VALUES(?, ?, ?, ?)");
    my $rows = $secth -> execute($articleid, $scheduleid, $sectionid, $priority);
    return $self -> self_error("Unable to perform article section relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article section relation insert failed, no rows inserted") if($rows eq "0E0");

    return 1;
}

1;
