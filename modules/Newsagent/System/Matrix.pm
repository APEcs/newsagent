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


## @method $ get_available_methods()
# Obtain a list of the methods defined in the system. This does not filter based on
# the methods available to the user.
#
# @return A reference to an array of method hashes on success, undef on error
sub get_available_methods {
    my $self = shift;

    $self -> clear_error();

    my $methods = $self -> {"dbh"} -> prepare("SELECT id, name
                                               FROM  `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."`
                                               ORDER BY name");
    $methods -> execute()
        or return $self -> self_error("Unable to look up available methods: ".$self -> {"dbh"} -> errstr);

    return $methods -> fetchall_arrayref({});
}


## @method $ get_method_byid($methodid)
# Given a method ID, fetch the data for the method.
#
# @param methodid The ID of the method to fetch the data for
# @return A reference to the method data on succes, undef on error.
sub get_method_byid {
    my $self     = shift;
    my $methodid = shift;

    $self -> clear_error();

    my $methods = $self -> {"dbh"} -> prepare("SELECT *
                                               FROM  `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."`
                                               WHERE id = ?");
    $methods -> execute($methodid)
        or return $self -> self_error("Unable to look up available methods: ".$self -> {"dbh"} -> errstr);

    return ($methods -> fetchrow_hashref() || $self -> self_error("Request for unknown method '$methodid'"));
}


## @method $ get_recipient_byid($recipientid)
# Given a recipient ID, fetch the data for the recipient.
#
# @param recipientid The ID of the recipient to fetch the data for
# @return A reference to the recipient data on succes, undef on error.
sub get_recipient_byid {
    my $self        = shift;
    my $recipientid = shift;

    $self -> clear_error();

    my $recipients = $self -> {"dbh"} -> prepare("SELECT *
                                                  FROM  `".$self -> {"settings"} -> {"database"} -> {"notify_recipients"}."`
                                                  WHERE id = ?");
    $recipients -> execute($recipientid)
        or return $self -> self_error("Unable to look up available recipients: ".$self -> {"dbh"} -> errstr);

    return ($recipients -> fetchrow_hashref() || $self -> self_error("Request for unknown recipient '$recipientid'"));
}


## @method $ get_recipmethod($recipientid, $methodid, $yearid)
# Given a recipient and a method id, obtain the corresponding recipmethod data if
# possible.
#
# @param recipientid The ID of the recipient.
# @param methodid    The ID of the method.
# @param yearid      The ID of the year to fetch year-specific data for.
# @return A reference to a hash containing the recipmethod data corresponding to
#         the specified recipient and method on success, undef on error
sub get_recipmethod {
    my $self        = shift;
    my $recipientid = shift;
    my $methodid    = shift;
    my $yearid      = shift;

    $self -> clear_error();

    my $methods = $self -> {"dbh"} -> prepare("SELECT *
                                               FROM  `".$self -> {"settings"} -> {"database"} -> {"notify_matrix"}."`
                                               WHERE recipient_id = ? AND method_id = ?");
    $methods -> execute($recipientid, $methodid)
        or return $self -> self_error("Unable to look up recipmethod data: ".$self -> {"dbh"} -> errstr);

    my $target = $methods -> fetchrow_hashref()
        or return $self -> self_error("No recipmethod data for recipient $recipientid via method $methodid");

    my $yearh = $self -> {"dbh"} -> prepare("SELECT `settings`
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"notify_matrix_cfg"}."`
                                             WHERE `rm_id` = ?
                                             AND `year_id` = ?");

    $yearh -> execute($target -> {"id"}, $yearid)
        or return $self -> self_error("Unable to perform recipient method year data lookup: ".$self -> {"dbh"} -> errstr);

    # If there are year-specific settings, override the basic ones
    my $settings = $yearh -> fetchrow_arrayref();
    $target -> {"settings"} = $settings -> [0]
        if($settings && $settings -> [0]);

    # Do any year id substitutions needed
    $target -> {"settings"} =~ s/\{V_\[yearid\]\}/$yearid/g;

    return $target;
}


# ============================================================================
#  Private incantations


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
                                                     AND mr.settings IS NOT NULL
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
