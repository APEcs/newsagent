## @file
# This file contains the implementation of the recipient/method matrix model.
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
package Newsagent::System::Matrix;

use strict;
use base qw(Webperl::SystemModule); # This class extends the system module
use v5.12;

use Webperl::Utils qw(path_join hash_or_hashref);

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Create a new Matrix object to manage matrix interaction.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Matrix object, or undef if a problem occured.
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

## @method $ get_user_matrix($userid)
# Generare a nested array structure (really a tree) describing the recipients the
# specified user is allowed to send notifications to, and the methods by which the
# notifications may be sent.
#
# @param userid The ID of the user to get the recipient/method matrix for.
# @return A reference to an array containing the user's recipient/method matrix
#         on success, undef on error.
sub get_user_matrix {
    my $self   = shift;
    my $userid = shift;

    $self -> self_error();

    $self -> {"logger"} -> log("debug", $userid, undef, "In get_user_matrix")
        if($self -> {"settings"} -> {"config"} -> {"debug"});

    return $self -> _build_matrix($userid);
}


## @method $ get_article_settings($args, $articleid, $methods)
# Obtain the notification method data.
#
# @param args      A reference to a hash to store the notification data in.
# @param articleid The article to fetch notification data for
# @param methods   A reference to a hash of notification method objects
# @return true on success, undef on error.
sub get_article_settings {
    my $self      = shift;
    my $args      = shift;
    my $articleid = shift;
    my $methods   = shift;

    $self -> clear_error();

    $self -> _fetch_enabled_methods($args, $articleid, $methods)
        or return undef;

    return 1;
}


## @method $ get_pending_notifications()
# Generate a list of currently pending notifications that are capable of being sent
# (ie: the article has been published, at least 5 minutes have elapsed between
# publish time and this call).
#
# @return A reference to an array of pending article notifications
sub get_pending_notifications {
    my $self = shift;

    $self -> clear_error();

    # Default delay is 5 minutes. Entries must have been released at least this long
    # ago to qualify for pending release
    my $time_delay = time() - (($self -> {"settings"} -> {"config"} -> {"Notification:hold_delay"} || 5) * 60);

    my $pendingh = $self -> {"dbh"} -> prepare("SELECT `m`.`name`, `n`.`id`, `n`.`article_id`, `n`.`year_id`, `a`.`release_time`
                                                FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."` AS `n`,
                                                     `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."` AS `m`,
                                                     `".$self -> {"settings"} -> {"database"} -> {"articles"}."` AS `a`
                                                WHERE `m`.`id` = `n`.`method_id`
                                                AND `a`.`id` = `n`.`article_id`
                                                AND `n`.`status` = 'pending'
                                                AND (`a`.`release_mode` = 'visible'
                                                     OR (`a`.`release_mode` = 'timed'
                                                         AND `a`.`release_time` <= UNIX_TIMESTAMP()
                                                        )
                                                    )
                                                AND `a`.`release_time` < ?
                                                ORDER BY `a`.`release_time`, `m`.`name`");
    $pendingh -> execute($time_delay)
        or return $self -> self_error("Unable to perform pending notification lookup: ".$self -> {"dbh"} -> errstr);

    return $pendingh -> fetchall_arrayref({});
}


# ============================================================================
#  Private incantations

## @method private $ _fetch_enabled_methods($args, $articleid, $methods)
# Generate a hash containing the enabled recipients and methods, and a hash of used methods.
#
#
sub _fetch_enabled_methods {
    my $self      = shift;
    my $args      = shift;
    my $articleid = shift;
    my $methods   = shift;

    $self -> clear_error();

    # First we need to fetch the list of notification headers - this will give the
    # list of used methods, and can be used to loop up the recipients
    my $notifyh = $self -> {"dbh"} -> prepare("SELECT n.*, m.name
                                               FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify"}."` AS n,
                                                    `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."` AS m
                                               WHERE m.id = n.method_id
                                               AND n.article_id = ?");

    # And a query will be needed to fetch recipients
    my $reciph = $self -> {"dbh"} -> prepare("SELECT rm.recipient_id
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"article_notify_rms"}."` AS a,
                                                   `".$self -> {"settings"} -> {"database"} -> {"notify_matrix"}."` AS rm
                                              WHERE rm.id = a.recip_meth_id
                                              AND a.article_notify_id = ?");

    # Start the ball rolling on fetching headers
    $notifyh -> execute($articleid)
        or return $self -> self_error("Unable to fetch notification headers: ".$self -> {"dbh"} -> errstr());

    while(my $header = $notifyh -> fetchrow_hashref()) {
        # All the years will be the same, so use the first one encountered
        $args -> {"notify_matrix"} -> {"year"} = $header -> {"year_id"}
            if(!$args -> {"notify_matrix"} -> {"year"});

        # Fetch all recipient/method maps associated with this notification
        $reciph -> execute($header -> {"id"})
            or return $self -> self_error("Unable to fetch notification map: ".$self -> {"dbh"} -> errstr());

        while(my $recip = $reciph -> fetchrow_arrayref()) {
            push(@{$args -> {"notify_matrix"} -> {"used_methods"} -> {$header -> {"name"}}}, $recip -> [0]);
            $args -> {"notify_matrix"} -> {"enabled"} -> {$recip -> [0]} -> {$header -> {"method_id"}} = 1;
        }

        # May as well fetch the method-specific data here, too!
        $args -> {"methods"} -> {$header -> {"name"}} = $methods -> {$header -> {"name"}} -> get_article($articleid);
    }
}


## @method private $ _build_matrix($userid, $parent)
# Determine which entries in the recipient/method notification matrix the user has
# access to send notifications through. This generates a hash of permitted methods
# and recipients.
#
# @param userid The ID of the user to generate the matrix for
# @param parent The ID of the recipient to use in the parent field of the query,
#               if not set this defaults to 0.
# @return A reference to an array containing the tree of recipients.
sub _build_matrix {
    my $self   = shift;
    my $userid = shift;
    my $parent = shift || 0;

    $self -> clear_error();

    my $recipients = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"notify_recipients"}."`
                                                  WHERE parent = ?
                                                  ORDER BY position");
    $recipients -> execute($parent)
        or return $self -> self_error("Unable to perform recipient lookup: ".$self -> {"dbh"} -> errstr);

    my $method_recips = $self -> {"dbh"} -> prepare("SELECT mr.*, m.name
                                                     FROM `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."` AS m,
                                                          `".$self -> {"settings"} -> {"database"} -> {"notify_matrix"}."` AS mr
                                                     WHERE mr.recipient_id = ?
                                                     AND m.id = mr.method_id
                                                     ORDER BY m.name");

    # Fetch all the matched recipients, to avoid problems with reentrance
    my $reciplist = $recipients -> fetchall_arrayref({})
        or return $self -> self_error("Error fetching recipients: ".$self -> {"dbh"} -> errstr);

    # No point doing anything if there are no recipients at this level
    return [] if(!scalar(@{$reciplist}));

    # Check each recipient to determine whether the user has any acces to it or a sub-recipient
    my @result = ();
    foreach my $recip (@{$reciplist}) {
        # Fetch the list of method settings for this recipient
        $method_recips -> execute($recip -> {"id"})
            or return $self -> self_error("Unable to preform matrix lookup: ".$self -> {"dbh"} -> errstr);

        my $methods = [];
        while(my $row = $method_recips -> fetchrow_hashref()) {

            # Does the user have permission to access the method for the recipient?
            if($self -> {"roles"} -> user_has_capability($row -> {"metadata_id"}, $userid, "notify")) {
                $self -> {"logger"} -> log("debug", $userid, undef, "User $userid has notify permission for ".$row -> {"id"})
                    if($self -> {"settings"} -> {"config"} -> {"debug"});

                # If the user has permission, store it
                push(@{$methods}, $row);
            } elsif($self -> {"settings"} -> {"config"} -> {"debug"}) {
                $self -> {"logger"} -> log("debug", $userid, undef, "User $userid noes not have notify permission for ".$row -> {"id"});
            }
        }

        # Get any sub-recipients
        my $children = $self -> _build_matrix($userid, $recip -> {"id"})
            or return undef;

        # Store the methods and children if defined
        $recip -> {"methods"}  = $methods  if(scalar(@{$methods}));
        $recip -> {"children"} = $children if(scalar(@{$children}));

        # Store the recipient if it has any children or accessible methods
        push(@result, $recip) if($recip -> {"methods"} || $recip -> {"children"});
    }

    return \@result;
}

1;
