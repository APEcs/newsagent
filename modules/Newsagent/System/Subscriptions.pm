## @file
# This file contains the implementation of the subscriptions model.
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
package Newsagent::System::Subscriptions;

use Crypt::Random qw(makerandom);
use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;

## @cmethod $ new(%args)
# Create a new Subscriptions object to manage tag allocation and lookup.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object.
# * session   - The system session object.
# * metadata  - The system Metadata object.
# * roles     - The system Roles object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Subscriptions object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    return $self;
}


# ============================================================================
#  Data access

## @method $ requires_activation($userid, $email)
# Determine whether the subscription for the specified userid or email is
# active.
#
# @param userid The ID of the user to check the subscription for. If this is
#               not specified, the email address must be provided. If this is
#               specified, the email address is ignored.
# @param email  The email address to check the subscription for.
# @return True if the account requires activation, false if it does not, undef
#         on error.
sub requires_activation {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Fetch the subscription header if possible. This will always
    # return a defined value except on error.
    my $subscription = $self -> _get_subscription($userid, $email)
        or return undef;

    # Got a subscription, if it's not active it requires activation...
    return (!$subscription -> {"active"});
}


## @method $ set_user_subscription($userid, $email, $feeds)
# Ensure that the user's subscription exists, and add any feeds supplied to the
# list of feeds the user is subscribed to.
#
# @param userid The ID of the user to set the subscription for. If not specified,
#               the email address must be provided.
# @param email  The email address to set for the subscription. If userid is specified,
#               and this does not match the user's email address, this is used as
#               the user's subscription address.
# @param feeds  A reference to a list of feed IDs.
# @return A reference to the subscription header on success, undef on error.
sub set_user_subscription {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;
    my $feeds  = shift;

    $self -> clear_error();

    # Fetch the subscription header if possible. This will always
    # return a defined value except on error.
    my $subscription = $self -> _get_subscription($userid, $email)
        or return undef;

    # check that a sub header exists, and that it has the right email
    if($subscription -> {"id"}) {
        $self -> _set_subscription_email($subscription -> {"id"}, $email) or return undef
            if($email && $subscription -> {"email"} ne $email);

    } else {
        $subscription = $self -> _create_subscription($userid, $email)
            or return undef;
    }

    foreach my $feed (@{$feeds}) {
        $self -> _set_subscription_feed($subscription -> {"id"}, $feed)
            or return undef;
    }

    return $subscription;
}


# ============================================================================
#  Internal implementation

## @method private $ _create_subscription($userid, $email)
# Create a new subscription header. If the email address is specfied, the subscription
# must be confirmed before subscription messages will be sent.
#
# @param userid The ID of the user to create the subscription for. If this is not
#               specified the email *must* be specified.
# @param email  The optional alternative email address to use for the subscription.
# @return A reference to a hash containing the subscription header on success,
#         undef on error.
sub _create_subscription {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # if the email has been set, check that the email is not already the user's email
    if($userid && $email) {
        my $user = $self -> {"session"} -> get_user_byid($userid)
            or return $self -> self_error("Unable to locate data for user: ".$self -> {"session"} -> errstr());

        # If the email addresses match, clear the specified email as it's redundant
        $email = undef
            if(lc($user -> {"email"}) eq lc($email));
    }

    # Get here with a defined email address, and the subscription can't start active
    my $active = !defined($email);

    # Need an auth code?
    my $authcode = $self -> _generate_authcode()
        if(!$active);

    # try to add the subscription data
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"config"} -> {"subscriptions"}."`
                                            (`user_id`, `email`, `active`, `authcode`)
                                            VALUES(?, ?, ?, ?)");
    my $rows = $newh -> execute($userid, $email, $active, $authcode);
    return $self -> self_error("Unable to perform subscription insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription insert failed, no rows inserted") if($rows eq "0E0");

    # Fetch the ID for the row just added
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"}
        or return $self -> self_error("Unable to obtain id for new subscription row");

    # And return the data (this could be made by hand here, but this ensures
    # the data really is in the database....
    my $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"config"} -> {"subscriptions"}."`
                                            WHERE `id` = ?");
    $subh -> execute($newid)
        or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref()
        or return $self -> self_error("Unable to locate subscription with id $newid");

    return $subdata;
}


## @method private $ _get_subscription($userid, $email)
# Fetch the subscription information for the user or email specified. This attempts
# to locate the subscription information based on first the user id specified - if
# one is available - and then the email. At least one of userid or email must be
# provided, and if the userid is set the email is ignored. Note that this means
# that the caller must ensure that the email addresses match if the userid is
# specified. If a userid is specified, but no matching subscription is found,
# this will return undef even if an email has been specified.
#
# @param userid The ID of the user to fetch the subscription for. If undef, the email
#               must be specified!
# @param email  The email address to search for a subscription for. If userid is
#               specified, this is ignored, even if searching by userid fails. If
#               userid is not set, this *must* be provided.
# @return A reference to a hash containing the subscription data on success, a
#         reference to an empty hash if no subscription data can be located, undef
#         on error.
sub _get_subscription {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Look up existing subscription by userid first, if one has been given
    if($userid) {
        my $subh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"config"} -> {"subscriptions"}."`
                                                WHERE `user_id` = ?");
        $subh -> execute($userid)
            or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

        # If the subscription has been located, return it. Note that the email address set
        # in the data may be different from the supplied address - the caller much handle that!
        my $subdata = $subh -> fetchrow_hashref();
        return $subdata if($subdata);

    # Try looking for a subscription via email
    } elsif($email) {
        $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"config"} -> {"subscriptions"}."`
                                         WHERE `email` LIKE ?");
        $subh -> execute($email)
            or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

        $subdata = $subh -> fetchrow_hashref();
        return $subdata if($subdata);
    }

    return {};
}


## @method private $ _set_subscription_feed($subid, $feedid)
# Add the specified feed to the list of feeds the user is subscribed to.
#
# @param subid  The ID of the subscription to add the feed to.
# @param feedid The ID of the feed to add to the subscription
# @return true on success (of if the feed is already in the subscription)
#         undef on error.
sub _set_subscription_feed {
    my $self   = shift;
    my $subid  = shift;
    my $feedid = shift;

    $self -> clear_error();

    # does a sub/feed relation exist?
    my $checkh = $self -> {"dbh"} -> prepare("SELECT `id` FROM `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."`
                                              WHERE `sub_id` = ?
                                              AND `feed_id` = ?");
    $checkh -> execute($subid, $feedid)
        or return $self -> self_error("Unable to search for subscription/feed relation");

    my $exists = $checkh -> fetchrow_arrayref();
    return 1 if($exists && $exists -> [0]);

    # sub/feed relation doesn't exist, so create it
    my $addh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."`
                                            (`sub_id`, `feed_id`)
                                            VALUES(?, ?)");
    my $rows = $addh -> execute($subid, $feedid);
    return $self -> self_error("Unable to perform sub/feed relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription/feed relation insert failed, no rows inserted") if($rows eq "0E0");

    return 1;
}


## @method private $ _generate_authcode()
# Generate a 64 character authentication code to set for subscription authentication.
#
# @return A 64 character auth code. Note that uniqueness is not guaranteed (if
#         highly likely), so it should not be used as an ID of any kind.
sub _generate_authcode {
    my $self = shift;

    return join("", map { ("a".."z", "A".."Z", 0..9)[rand 62] } 1..64);
}

1;