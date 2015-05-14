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
#  Terrifying vistas of madness

## @method $ check_email($address, $userid)
# Determine whether the user is allowed to use the email address specified. This
# will implement restriction A described in the Newsagent::Subscriptions class
# documentation. This will only return true if the email address specified is
# not the default or alternate email address for a user, or it matches the
# alternate address for the user with the specified ID.
#
# @param address The email address to check the validity of.
# @param userid  The userid of the user wanting to use the email. If there is no
#                logged in user, this should be undef.
# @return true if the email is available/valid for use, false otherwise.
sub check_email {
    my $self    = shift;
    my $address = shift;
    my $userid  = shift;

    # First, simple lookup - does a user exist with the email address as a default?
    my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byemail($address);
    if($user && $user -> {"user_id"}) {
        # If the email address belongs to the specified user, it's okay to use it
        # (realistically, this should never happen, as this should not be called
        # if the email address belongs to the user, but handle it anyway...)
        # this will return false, unless the email address belongs to the user.
        return ($userid && $user -> {"user_id"} == $userid);
    }

    # Is the email in use as a subscription address (either as an alternate, or
    # email-only subscription)?
    my $sub = $self -> _get_subscription_byemail($address);
    if($sub && $sub -> {"id"}) {
        # The email is in use as an alternate address. Is it one already used by this
        # user? If so, they can continue to use it - if it's in use by another user
        # then this one can't use it. If no users have claimed the address (ie: it
        # is a subscription set up by a user without an account/not logged it), then
        # it's okay to use it.
        return (!$sub -> {"user_id"} || $sub -> {"user_id"} == $userid);
    }

    # Get here and it appears that the address is not in use, so it
    # should be available to the user
    return 1;
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

    # Fetch the subscription header if possible. This will always produce a defined
    # value - even if it's just a reference to an empty hash - except on error.
    my $subscription = $self -> _get_subscription_header($userid, $email)
        or return undef;

    # check that a sub header exists, and that it has the right email
    if($subscription -> {"id"}) {
        # In theory, this should only ever run when userid is not undef - if it is, the email
        # will always match the subscription email, otherwise _get_subscription_header() couldn't
        # have found it to begin with.
        $self -> _set_subscription_email($subscription -> {"id"}, $email)
            or return undef;
    } else {
        $subscription = $self -> _create_subscription_header($userid, $email)
            or return undef;
    }

    # and make sure the feeds are setup
    foreach my $feed (@{$feeds}) {
        $self -> _set_subscription_feed($subscription -> {"id"}, $feed)
            or return undef;
    }

    return $self -> _get_subscription_byid($subscription -> {"id"});
}


## @method $ subscription_exists($userid, $email)
# Determine whether the subscription for the specified userid or email is
# active.
#
# @param userid The ID of the user to check the subscription for. If this is
#               not specified, the email address must be provided. If this is
#               specified, the email address is ignored.
# @param email  The email address to check the subscription for.
# @return A reference to a hash containing the subscription data on success,
#         undef on error.
sub subscription_exists {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Fetch the subscription header if possible. This will always
    # return a defined value except on error.
    my $subscription = $self -> _get_subscription_header($userid, $email)
        or return undef;

    return $subscription -> {"id"} ? $subscription : $self -> self_error("No subscription exists for the specified user");
}


# ============================================================================
#  Activation related

## @method $ requires_activation($userid, $email)
# Determine whether the subscription for the specified userid or email is
# active.
#
# @param userid The ID of the user to check the subscription for. If this is
#               not specified, the email address must be provided.
# @param email  The email address to check the subscription for.
# @return True if the account requires activation, false if it does not, undef
#         on error or no subscription exists.
sub requires_activation {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Fetch the subscription header if possible. This will always
    # return a defined value except on error.
    my $subscription = $self -> subscription_exists($userid, $email)
        or return undef;

    # Got a subscription, if it's not active it requires activation...
    return (!$subscription -> {"active"});
}


## @method $ get_activation_code($userid, $email, $newcode)
# Fetch the activation code for the subscription associated with the specified
# userid or email address.
#
# @param userid  The ID of the user to fetch the authcode for. If this is
#                not specified, the email address must be provided. If this is
#                specified, the email address is ignored.
# @param email   The email address to fetch the authcode for.
# @param newcode If true, a new authcode is set for the subscription, otherwise
#                the existing authcode (if any) is returned. If a new actcode is
#                set, the subscription is simultaenously deactivated.
# @return The authcode for the subscription (or an empty string if no authcode
#         has been set) on success, undef on error (including a request to
#         fetch the authcode for a subscription that does not exist)
sub get_activation_code {
    my $self    = shift;
    my $userid  = shift;
    my $email   = shift;
    my $newcode = shift;

    $self -> clear_error();

    # Fetch the subscription header if possible. This will always
    # return a defined value except on error.
    my $subscription = $self -> subscription_exists($userid, $email)
        or return undef;

    # No subscription
    return $self -> self_error("No subscription found for the specified user")
        if(!$subscription -> {"id"});

    # Update the authcode if needed (this will clear activation, too)
    $self -> _set_authcode($subscription, $self -> _generate_authcode()) or return undef
        if($newcode);

    return $subscription -> {"authcode"} || "";
}


sub activate_subscription {
    my $self = shift;
    my $code = shift;




}


# ============================================================================
#  Internal implementation - Header handling

## @method private $ _create_subscription_header($userid, $email)
# Create a new subscription header. If the email address is specfied, the subscription
# must be confirmed before subscription messages will be sent.
#
# @param userid The ID of the user to create the subscription for. If this is not
#               specified the email *must* be specified.
# @param email  The optional alternative email address to use for the subscription.
# @return A reference to a hash containing the subscription header on success,
#         undef on error.
sub _create_subscription_header {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    return $self -> self_error("No userid or email specified")
        if(!$userid && !$email);

    # If the email address is set the subscription can't start active, even if
    # the userid is present.
    my $active = !defined($email);

    # Need an auth code?
    my $authcode = $self -> _generate_authcode()
        if(!$active);

    # try to add the subscription data
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
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
    my $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `id` = ?");
    $subh -> execute($newid)
        or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref()
        or return $self -> self_error("Unable to locate subscription with id $newid");

    return $subdata;
}


## @method private $ _get_subscription_header($userid, $email)
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
sub _get_subscription_header {
    my $self   = shift;
    my $userid = shift;
    my $email  = shift;

    $self -> clear_error();

    # Look up existing subscription by userid first, if one has been given
    if($userid) {
        my $subh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                                WHERE `user_id` = ?");
        $subh -> execute($userid)
            or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

        # If the subscription has been located, return it. Note that the email address set
        # in the data may be different from the supplied address - the caller much handle that!
        my $subdata = $subh -> fetchrow_hashref();
        return $subdata if($subdata);

    # Try looking for a subscription via email
    } elsif($email) {
        my $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                                WHERE `email` LIKE ? AND `user_id` IS NULL");
        $subh -> execute($email)
            or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

        my $subdata = $subh -> fetchrow_hashref();
        return $subdata if($subdata);
    }

    return {};
}


# ============================================================================
#  Internal implementation - Lookup

## @method private $ _get_subscription_byid($subid)
# Given a subscription ID, fetch the data for the subscription (including feeds)
# if such a subscription exists.
#
# @param subid the Id of the subscription to fetch the data for.
# @return A reference to a hash containing the subscription data on success, a
#         reference to an empty hash if the subscription does not exist, or
#         undef if an error occurred.
sub _get_subscription_byid {
    my $self  = shift;
    my $subid = shift;

    $self -> clear_error();

    my $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `id` = ?");
    $subh -> execute($subid)
        or return $self -> self_error("Unable to search for subscription by ID: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref();

    # If the header has been found, pull in the feed list too.
    if($subdata) {
        $subdata -> {"feeds"} = $self -> _get_subscription_feeds($subdata -> {"id"})
            or return undef;
    }

    return ($subdata || {});
}


## @method private $ _get_subscription_byemail($email)
# Search for subscriptions set up to use the specified email address as the email
# to send digests to. This will search for subscriptions with or without userid
# information set - it purely looks for subscriptions with the specified email.
#
# @param email The email address to search for.
# @return A reference to a hash containing the subscription information if the
#         email address has been used for one, an empty hashref if it has not,
#         undef on error.
sub _get_subscription_byemail {
    my $self  = shift;
    my $email = shift;

    $self -> clear_error();

    my $subh = $self -> {"dbh"} -> prepare("SELECT  * FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `email` LIKE ?
                                            LIMIT 1"); # LIMIT should be redundant, but better to be sure.
    $subh -> execute($email)
        or return $self -> self_error("Unable to search for subscriptions by email: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref();

    # If the header has been found, pull in the feed list too.
    if($subdata) {
        $subdata -> {"feeds"} = $self -> _get_subscription_feeds($subdata -> {"id"})
            or return undef;
    }

    return ($subdata || {});
}


# ============================================================================
#  Internal implementation - feed handling

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


# ============================================================================
#  Internal implementation - email and related

## @method private $ _set_subscription_email($subid, $email)
# Update the email address associated with the specified subscription. If the
# email address is set,
#
# @param subid The ID of the subscription header to update the email for.
# @param email The email address to set; this may be undef to NULL the
#              email setting (ONLY do this when the subscription user_id
#              is not NULL, otherwise the subscription will become unusable)
# @return true on success, undef on error.
sub _set_subscription_email {
    my $self  = shift;
    my $subid = shift;
    my $email = shift;

    $self -> clear_error();

    # If the email address is set the subscription must be deactivated
    my $active = !defined($email);

    # Need an auth code?
    my $authcode = $self -> _generate_authcode()
        if(!$active);

    my $seth = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            SET `email` = ?, `active` = ?, `authcode` = ?
                                            WHERE `id` = ?");
    my $rows = $seth -> execute($email, $active, $authcode, $subid);
    return $self -> self_error("Unable to perform subscription email update: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription email update failed, no rows inserted") if($rows eq "0E0");

    return 1;
}


## @method private $ _set_authcode($subscription, $authcode)
# Update the authcode associated with the specified subscription.
#
# @param subscription A reference to a hash containing the subscription data.
# @param authcode     The new authcode to set for the subscription. This will also
#                     set the subscription to inactive.
# @return A reference to a hash containing the subscription data on success, undef
#         on error.
sub _set_authcode {
    my $self         = shift;
    my $subscription = shift;
    my $authcode     = shift;

    my $seth = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            SET `authcode` = ?, `active` = 0
                                            WHERE `id` = ?");
    my $rows = $seth -> execute($authcode, $subscription -> {"id"});
    return $self -> self_error("Unable to perform subscription update: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription update failed, no rows inserted") if($rows eq "0E0");

    $subscription -> {"active"}   = 0;
    $subscription -> {"authcode"} = $authcode;

    return $subscription;
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