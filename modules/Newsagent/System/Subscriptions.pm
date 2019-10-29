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
use Webperl::Utils qw(hash_or_hashref);
use v5.12;
use Data::Dumper;

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
    my $self      = shift;
    my $address   = shift;
    my $userid    = shift;

    # First, simple lookup - does a user exist with the email address as a default?
    my $user = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_byemail($address);
    if($user && $user -> {"user_id"}) {
        # If the email address belongs to the specified user, it's okay to use it
        # (realistically, this should never happen, as this should not be called
        # if the email address belongs to the user, but handle it anyway...)
        # this will return false, unless the email address belongs to the user.
        return ($userid && $user -> {"user_id"} == $userid);
    }

    # Is the email in use as an alternate subscription address?
    my $sub = $self -> _get_subscription_byemail($address, 1);
    if($sub && $sub -> {"id"}) {
        # The email is in use as an alternate address. Is it one already used by this
        # user? If so, they can continue to use it - if it's in use by another user
        # then this one can't use it.
        return ($userid && $sub -> {"user_id"} == $userid);
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
        # Note: herein lies a problem. At this point, we have a pre-existing subscription, that
        # may or may not be a user's. If it is a user's, it may be active, or have an inactive
        # alternate email associated with it - potentially sharing an email with an email-only
        # subscription. Consider the following:
        #
        #  Anonymous User sets up subscription s0 to f0, f1 using email e0, system sends auth
        #  code to e0, user activates it to prove ownership.
        #  Anonymous user later gets an account, but it is set up to use email e1. User logs in,
        #  and creates subscription s1 to f1 and f2 using alternate email e0, system sends auth
        #  code to e0 (ie: s1 is inactive, note s0 is unaffected at this point). Now one of two
        #  things can happen:
        #
        #  - user activates s1 using authcode sent to e0. This will automatically merge s0 into
        #    s1 as the system detects the common e0 and gives priority to s1.
        #  - user does not activate s1, but returns later to modfy s1 to remove e0. This
        #    will automatically activate s1 sending emails to e1, but it will NOT merge the
        #    existing s0 into s1 as there is now no common email. This means that now the user
        #    is getting f0,f1 sent to e0, and f1,f2 sent to e1.
        #
        #  If the subscription is both not activated and activated, how tall is Imhotep?
        #
        # The user has two options - they can either add e0 back into s1, activate, and thus get
        # s0 merged into s1; alternatively each message sent to e0 for s0 will contain an unsub
        # link that should let the user delete s0.
        #
        # An alternative, more dangerous option is to uncomment the following:
        #
        # $self -> _merge_subscriptions($subscription -> {"id"}, $subscription -> {"user_id"}, $subscription -> {"email"})
        #     if($subscription -> {"user_id"} && $subscription -> {"email"});
        #
        # that will merge any email only subscriptions for a user, even if they haven't activated
        # the subscription. Butit opens the door for subscription hijacking and deletion.

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


## @method $ add_to_subscription($subid, $feeds)
# Add the specified feeds from the user's subscription. This attempts to add
# the feeds specified in the feeds array from the user's subscription, if they are
# not already in the subscription.
#
# @param subid The ID of the subscription to add the feeds to.
# @param feeds A reference to an array of IDs of feeds to add from the subscription.
# @return The number of feeds added, or undef on error.
sub add_to_subscription {
    my $self  = shift;
    my $subid = shift;
    my $feeds = shift;

    # Can't do anything if there's no feeds to remove
    return 0 if(!scalar(@{$feeds}));

    my $count = 0;
    foreach my $feed (@{$feeds}) {
        my $added = $self -> _set_subscription_feed($subid, $feed);
        return undef if(!defined($added));

        $count += $added;
    }

    return $count;
}


## @method $ remove_from_subscription($subid, $feeds)
# Remove the specified feeds from the user's subscription. This attempts to remove
# the feeds specified in the feeds array from the user's subscription, if they are
# subscribed to by the user.
#
# @param subid The ID of the subscription to remove the feeds from.
# @param feeds A reference to an array of IDs of feeds to remove from the subscription.
# @return The number of feeds removed, or undef on error.
sub remove_from_subscription {
    my $self  = shift;
    my $subid = shift;
    my $feeds = shift;

    # Can't do anything if there's no feeds to remove
    return 0 if(!scalar(@{$feeds}));

    my @params = ($subid, @{$feeds});
    my $query  = "AND `feed_id` IN (?".(",?" x (scalar(@{$feeds}) - 1)).")";

    my $removeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."`
                                               WHERE `sub_id` = ?
                                               $query");
    my $rows = $removeh -> execute(@params);
    return $self -> self_error("Unable to perform feed removal: ".$self -> {"dbh"} -> errstr) if(!$rows);
    $rows = 0 if($rows eq "0E0");

    return $rows;
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


## @method $ delete_subscription(%args)
# Remove the subscription identified by either a subscription ID or a
# authorisation code. The specified arguments should contain either
#
# - sub_id: The ID of the subscription to delete.
# - authcode: The authcode of the subscription to delete.
#
# @param args A hash, or reference to a hash, containing the arguments.
# @return true on successful deletion, undef on error.
sub delete_subscription {
    my $self = shift;
    my $args = hash_or_hashref(@_);

    $self -> clear_error();

    return $self -> self_error("No subscription identifier available")
        if(!$args -> {"subid"} && !$args -> {"authcode"});

    # Easy case is when an ID is provided
    return $self -> _delete_subscription_byid($args -> {"subid"})
        if($args -> {"subid"});

    # Otherwise, a code must be available, and a matching subscription provided
    return $self -> self_error("Authorisation code required")
        unless($args -> {"authcode"});

    my $subscription = $self -> _get_subscription_bycode($args -> {"authcode"})
        or return undef;

    return $self -> self_error("No subscription matches the provided authorisation code")
        if(!$subscription -> {"id"});

    return $self -> _delete_subscription_byid($subscription -> {"id"});
}


## @method $ mark_run($subid)
# Mark the lastrun time on the specified subscription. This updates the
# lastrun time, so that the subscription cron job can keep track of which
# subscriptions need to be sent.
#
# @param subid The Id of the subscription to update the lastrun time for.
# @return true on success, undef on error.
sub mark_run {
    my $self  = shift;
    my $subid = shift;

    $self -> clear_error();

    my $touch = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                             SET `lastrun` = UNIX_TIMESTAMP()
                                             WHERE `id` = ?");
    $touch -> execute($subid)
        or return $self -> self_error("Unable to update subscription $subid: ".$self -> {"dbh"} -> errstr());

    return 1;
}


# ============================================================================
#  Lookup related


## @method $ get_subscription(%args)
# Attempt to fetch the data associated with a subscription. Supported arguments
# are:
#
# - user_id: Locate the subscription associated with the specified user.
# - authcode: Locate the subscription with the specified auth code.
# - id: Locate the subscription with the specified ID.
#
# @return A reference to a subscription data hash on success, an empty hash
#         reference if there is no data available, undef on error.
sub get_subscription {
    my $self = shift;
    my $args = hash_or_hashref(@_);

    if($args -> {"user_id"}) {
        return $self -> _get_subscription_byuserid($args -> {"user_id"});

    } elsif($args -> {"authcode"}) {
        return $self -> _get_subscription_bycode($args -> {"authcode"});

    } elsif($args -> {"id"}) {
        return $self -> _get_subscription_byid($args -> {"id"});
    }

    return $self -> self_error("No supported search parameters provided to get_subscription");
}


## @method $ get_pending_subscriptions($threshold)
# Fetch a list of subscriptions that should be checked for digesting. This
# fetches a list of subscriptions that have not been checked since the
# threshold specified.
#
# @param threshold The date before which subscriptions should be checked.
# @return A reference to an array of hashes, one entry for each subscription
#         that must be checked on success, undef on error.. Note that this may be a reference to an
#         empty array if there are no pending subscriptions.
sub get_pending_subscriptions {
    my $self      = shift;
    my $threshold = shift;

    $self -> clear_error();

    my $pendh = $self -> {"dbh"} -> prepare("SELECT `id`
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                             WHERE `active` = 1
                                             AND (`lastrun` IS NULL
                                                   OR `lastrun` <= ?)");
    $pendh -> execute($threshold)
        or return $self -> self_error("Unable to search for subscriptions that need checking for digests after '$threshold': ".$self -> {"dbh"} -> errstr());

    # Go through each of the subscriptions, pulling in the data for each one.
    # This will include the feeds the subscription is subscribed to.
    my @subs;
    while(my $subid = $pendh -> fetchrow_arrayref()) {
        my $subdata = $self -> _get_subscription_byid($subid -> [0])
            or return undef;

        # Regenerate the authcode for email-only subscriptions to prevent reuse
        if($subdata -> {"email"} && !$subdata -> {"user_id"}) {
            $subdata -> {"authcode"} = $self -> _generate_authcode();

            $self -> _set_authcode($subdata, $subdata -> {"authcode"}, 1)
                or return undef;
        }

        push(@subs, $subdata);
    }

    return \@subs;
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
#                the existing authcode (if any) is returned. If a new authcode is
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


## @method $ activate_subscription_bycode($code)
# Activate the subscription that has the specified activation code set. This will
# clear the activation code for the subscription and enable it.
#
# @param code The authcode to locate an inactive subscription for.
# @return true on success, undef on error (including no matching authcode).
sub activate_subscription_bycode {
    my $self = shift;
    my $code = shift;

    $self -> clear_error();

    my $subscription = $self -> _get_subscription_bycode($code);
    return $self -> self_error("No subscriptions have the specified activation code.")
        unless($subscription && $subscription -> {"id"});

    return $self -> activate_subscription_byid($subscription -> {"id"});
}


## @method $ activate_subscription_byid($subid)
# Activate the subscription specified. This will clear the activation code for
# the subscription and enable it, potentially merging any email-only subscriptions
# that have the same address as the specified subscription, if it is a user
# subscription.
#
# @param subid The ID of the subscription to activate (even if it's already active!)
# @return true on success, undef on error.
sub activate_subscription_byid {
    my $self  = shift;
    my $subid = shift;

    $self -> clear_error();

    # Clear the subscription authcode. The checks after the execute should handle bad IDs
    my $seth = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            SET `active` = 1, `authcode` = ?
                                            WHERE `id` = ?");
    my $rows = $seth -> execute($self -> _generate_authcode(), $subid);
    return $self -> self_error("Unable to perform subscription activation: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription activation failed, no matching subscription found") if($rows eq "0E0");

    # Fetch the subscription data, as we need the userid and email address stored therein.
    # Note that the return /should/ be
    my $subdata = $self -> _get_subscription_byid($subid);
    return $self -> self_error("Request for unknown subscription with id $subid")
        unless($subdata && $subdata -> {"id"});

    # handle merging...
    return $self -> _merge_subscriptions($subid, $subdata -> {"user_id"}, $subdata -> {"email"});
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
    my $active = $email ? 1 : 0;

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
    my $subh = $self -> {"dbh"} -> prepare("SELECT  *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
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
        my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                                FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                                WHERE `user_id` = ?");
        $subh -> execute($userid)
            or return $self -> self_error("Unable to search for subscriptions by user id: ".$self -> {"dbh"} -> errstr());

        # If the subscription has been located, return it. Note that the email address set
        # in the data may be different from the supplied address - the caller much handle that!
        my $subdata = $subh -> fetchrow_hashref();
        return $subdata if($subdata);

    # Try looking for a subscription via email
    } elsif($email) {
        my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                                FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
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

    my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
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


## @method private $ _get_subscription_byemail($email, $reqalt)
# Search for subscriptions set up to use the specified email address as the email
# to send digests to. This will search for subscriptions with or without userid
# information set - it purely looks for subscriptions with the specified email.
#
# @param email  The email address to search for.
# @param reqalt If true, the email address
# @return A reference to a hash containing the subscription information if the
#         email address has been used for one, an empty hashref if it has not,
#         undef on error.
sub _get_subscription_byemail {
    my $self   = shift;
    my $email  = shift;
    my $reqalt = shift;

    $self -> clear_error();

    my $userpart = $reqalt ? "AND `user_id` IS NOT NULL" : "";

    my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `email` LIKE ?
                                            $userpart
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


## @method private $ _get_subscription_bycode($code)
# Given a subscription activation code, fetch the data for the subscription
# (including feeds) if such a subscription exists.
#
# @param code The activation code to search for.
# @return A reference to a hash containing the subscription data on success, a
#         reference to an empty hash if the subscription does not exist, or
#         undef if an error occurred.
sub _get_subscription_bycode {
    my $self = shift;
    my $code = shift;

    $self -> clear_error();

    # First, look up the code to see whether there is a match to activate
    my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `authcode` = ?");
    $subh -> execute($code)
        or return $self -> self_error("Unable to search for subscriptions by activation code: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref();

    # If the header has been found, pull in the feed list too.
    if($subdata) {
        $subdata -> {"feeds"} = $self -> _get_subscription_feeds($subdata -> {"id"})
            or return undef;
    }

    return ($subdata || {});
}


## @method private $ _get_subscription_byuserid($userid)
# Given a userid, attempt to locate the subscription associated with the user.
#
# @param userid The ID of the user to locate a subscription for.
# @return A reference to a hash containing the subscription data on success, a
#         reference to an empty hash if the subscription does not exist, or
#         undef if an error occurred.
sub _get_subscription_byuserid {
    my $self   = shift;
    my $userid = shift;

    $self -> clear_error();
    print STDERR "Searcing for subs for user '$userid'";

    # First, look up the code to see whether there is a match to activate
    my $subh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            WHERE `user_id` = ?");
    $subh -> execute($userid)
        or return $self -> self_error("Unable to search for subscriptions by email address: ".$self -> {"dbh"} -> errstr());

    my $subdata = $subh -> fetchrow_hashref();
    print STDERR "subscription result: ".Dumper($subdata);

    # If the header has been found, pull in the feed list too.
    if($subdata) {
        $subdata -> {"feeds"} = $self -> _get_subscription_feeds($subdata -> {"id"})
            or return undef;
    }

    return ($subdata || {});
}


# ============================================================================
#  Internal implementation - feed handling

## @method private $ _delete_subscription_byid($subid)
# Delete the subscription with the specified ID and all its associated feed
# subscriptions.
#
# @param subid The ID of the subscription to delete
# @return true on success, undef on error.
sub _delete_subscription_byid {
    my $self  = shift;
    my $subid = shift;

    $self -> clear_error();

    # remove the header first...
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                             WHERE `id` = ?");
    $nukeh -> execute($subid)
        or return $self -> self_error("Unable to delete subscription $subid: ".$self -> {"dbh"} -> errstr);

    # ... and all feed relations
    $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."`
                                          WHERE `sub_id` = ?");
    $nukeh -> execute($subid)
        or return $self -> self_error("Unable to delete feed subscriptions for subscription $subid: ".$self -> {"dbh"} -> errstr);

    return 1;
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
    my $checkh = $self -> {"dbh"} -> prepare("SELECT `id`
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."`
                                              WHERE `sub_id` = ?
                                              AND `feed_id` = ?");
    $checkh -> execute($subid, $feedid)
        or return $self -> self_error("Unable to search for subscription/feed relation: ".$self -> {"dbh"} -> errstr);

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


## @method private $ _get_subscription_feeds($subid)
# Fetch the list of feed IDs the specified subscription is subscribed to.
#
# @param subid The subscription ID to fetch the feed list for.
# @return A reference to an array of feed IDs on success (which may be
#         an empty array if there are no feeds set up for the subscription),
#         or undef on error.
sub _get_subscription_feeds {
    my $self  = shift;
    my $subid = shift;
    my @feeds = ();

    $self -> clear_error();

    my $feedh = $self -> {"dbh"} -> prepare("SELECT `s`.`feed_id`
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"subfeeds"}."` AS `s`,
                                                  `".$self -> {"settings"} -> {"database"} -> {"feeds"}."` AS `f`
                                             WHERE `s`.`sub_id` = ?
                                             AND `f`.`id` = `s`.`feed_id`
                                             ORDER BY `f`.`name`");
    $feedh -> execute($subid)
        or return $self -> self_error("Unable to fetch subscription/feed relations: ".$self -> {"dbh"} -> errstr);

    while(my $feed = $feedh -> fetchrow_arrayref()) {
        push(@feeds, $feed -> [0]);
    }

    return \@feeds;
}


## @method private $ _merge_subscriptions($subid, $userid, $email)
# Attempt to merge any email-only subscriptions associated with the specified
# user's default email address, or the alternate address provided, into the
# subscription with the specified ID.
#
# @param subid  The ID of the subscription to merge feed subscriptions into.
# @param userid The ID of the user merging the subscriptions.
# @param email  The alternate email address to merge subscriptions from.
# @return true on success, undef on error.
sub _merge_subscriptions {
    my $self   = shift;
    my $subid  = shift;
    my $userid = shift;
    my $email  = shift;

    # If there is no userid, there's nothing to do here, but return true as
    # this has been 'successful' at doing nothing.
    return 1 if(!$userid);

    # There's a userid, so search for any subscriptions to merge into the user's subscription:
    # 1: look for email-only subscriptions using the user's default email, and merge them
    # 2: look for email-only subscriptions using the email address specified, and merge them

    # We need the user's email, so...
    my $user = $self -> {"session"} -> get_user_byid($userid)
        or return $self -> self_error("Unable to merge subscriptions: unknown user $userid");

    foreach my $addr ($user -> {"email"}, $email) {
        next if(!$addr); # Skip empty emails

        # note that this *doesn't* use _get_subscription_byemail()! That function will search
        # by email alone, whereas what we want to do is look specifically
        my $header = $self -> _get_subscription_header(undef, $addr);

        # If there's a subscription associated with the email address, fetch the feeds
        # associated with it...
        if($header) {
            my $feeds = $self -> _get_subscription_feeds($header -> {"id"});

            # If there are any feeds set for the subscription, they should be copied into
            # the list of feed subscriptions for the user's main subcription
            if($feeds && scalar(@{$feeds})) {
                foreach my $feed (@{$feeds}) {
                    $self -> _set_subscription_feed($subid, $feed)
                        or return undef;
                }
            }

            # And now remove the redundant subscription
            $self -> _delete_subscription_byid($header -> {"id"})
                or return undef;
        }
    }

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
    my $active = !$email;

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


## @method private $ _set_authcode($subscription, $authcode, $active)
# Update the authcode associated with the specified subscription.
#
# @param subscription A reference to a hash containing the subscription data.
# @param authcode     The new authcode to set for the subscription. This will also
#                     set the subscription to inactive.
# @param active       If true, keep the subscription active.
# @return A reference to a hash containing the subscription data on success, undef
#         on error.
sub _set_authcode {
    my $self         = shift;
    my $subscription = shift;
    my $authcode     = shift;
    my $active       = shift;

    $active = $active && $subscription -> {"active"};

    my $seth = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"subscriptions"}."`
                                            SET `authcode` = ?, `active` = ?
                                            WHERE `id` = ?");
    my $rows = $seth -> execute($authcode, $active, $subscription -> {"id"});
    return $self -> self_error("Unable to perform subscription update: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Subscription update failed, no rows inserted") if($rows eq "0E0");

    $subscription -> {"active"}   = $active;
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