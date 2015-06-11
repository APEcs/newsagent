## @file
# This file contains the implementation of the subscription management pages.
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
# Dealing with a mix of email address subscription and user account subscription
# is a pain, because there are some hidden complexities in there (not just
# because Email Hates The Living for a change...) For a start, there are three
# obvious situations that may arise:
#
# 1. user is not logged in (and may not have an account), so an email address
#    must be specified.
# 2. user is logged in, but specifies an alternate email address.
# 3. user is logged in, does not specify an alternate email address, so their
#    default one is used.
#
# Handling is further complicated by the fact that a user could potentially set
# up a subscription without logging in (or before having an account) using one
# email address, and then log in and set up additional subscriptions using the
# same address (either as their primary address, or as an alternative address).
#
# So, to handle these:
#
# - In case 1: the user should not be allowed to use an email address that has
#   been set as the primary address or alternative address for a registered user.
#   If the user has used the address they provide before, the feeds they have
#   selected should be added to that address' subscriptions, the subscription
#   deactivated, and a new activation email sent.
#
# - In case 2:
#   a. if the alternate email address matches the logged-in user's default
#      address, the alternate address can be ignored (set to undef). This is
#      then handled in the same way as case 3.
#   b. if the alternate email is not the default address, it must not match
#      any other registered user's default or alternate email. The selected
#      feeds are added to the user's subscriptions, the subscription is
#      deactivated, and an activation email is sent to the email alternate
#      email address. During activation, if the default or alternate email
#      for a user matches an existing email-only subscription, the email-only
#      subscription should be removed and the subscriptions it had merged with
#      the user's subscriptions.
#
# - In case 3: selected feeds are added to the user's subscription, and
#   activated immediately. If any email-only subscriptions exist that have the
#   user's default email address, they should be merged into the user's
#   subscriptions, and the email-only subscription removed.
#
# From these cases, some general rules can be derived:
#
# A. when an email address has been specified, it must not match an existing user
#    default or alternate address, unless the user is logged in with the matching
#    account.
#
# B. when activating a subscription as a logged-in user, email-only subscriptions
#    with an address that matches the logged-in user's default or alternate email
#    should be deleted and the subscriptions associated with the removed
#    subscription should be moved to the user's subscription. Note that "activating
#    a subscription as a logged-in user" means two things here:
#
#   B1. the implicit, hidden activation involved in enabling the subscriptions for
#       a user's default account address.
#   B2. the explicit activation involved in validating an activation code for an
#       alternative address.
package Newsagent::Subscriptions;

use strict;
use experimental qw(smartmatch);
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Feed;
use Newsagent::System::Subscriptions;
use JSON();
use v5.12;
use Data::Dumper;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Subscriptions facility, loads the System::Article model
# and other classes required to generate the subscriptions pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Subscriptions object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       session  => $self -> {"session"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Feed initialisation failed: ".$SystemModule::errstr);

    $self -> {"subscription"} = Newsagent::System::Subscriptions -> new(dbh      => $self -> {"dbh"},
                                                                        settings => $self -> {"settings"},
                                                                        logger   => $self -> {"logger"},
                                                                        session  => $self -> {"session"},
                                                                        roles    => $self -> {"system"} -> {"roles"},
                                                                        metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Subscriptions initialisation failed: ".$SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Emailer functions

## @method private $ _send_act_email($email, $actcode)
# Send an email to the specified address indicating that the subscription
# has been disabled and an activation code must be entered to enable it.
#
# @method email   The email address to send the message to.
# @method actcode The activation code to send to the user.
# @return undef on success, otherwise an error message.
sub _send_act_email {
    my $self    = shift;
    my $email   = shift;
    my $actcode = shift;

    # Build URLs to place in the email.
    my $acturl  = $self -> build_url("fullurl"  => 1,
                                     "block"    => "subscribe",
                                     "pathinfo" => [ "activate" ],
                                     "api"      => [],
                                     "params"   => "actcode=".$actcode);
    my $actform = $self -> build_url("fullurl"  => 1,
                                     "block"    => "subscribe",
                                     "pathinfo" => [ "activate" ],
                                     "api"      => [],
                                     "params"   => "");

    my $status = $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("SUBS_ACTCODE_SUBJECT"),
                                                        message => $self -> {"template"} -> load_template("subscriptions/email_actcode.tem",
                                                                                                          {"***act_code***" => $actcode,
                                                                                                           "***act_url***"  => $acturl,
                                                                                                           "***act_form***" => $actform,
                                                                                                          }),
                                                         recipients       => [ $email ],
                                                         send_immediately => 1);
    return ($status ? undef : $self -> {"messages"} -> errstr());
}


# ============================================================================
#  Support functions

## @method private $ _build_feed_list($feeds)
# Given a list of feed names, produce a lsit of feed IDs to pass to set_user_subscription().
#
# @param feeds A reference to an array of feed names
# @return A reference to an array of feed IDs on success, an error message on error,
sub _build_feed_list {
    my $self  = shift;
    my $feeds = shift;

    my @feedids = ();
    foreach my $feed (@{$feeds}) {
        my $data = $self -> {"feed"} -> get_feed_byname($feed)
            or return $self -> {"feed"} -> errstr();

        push(@feedids, $data -> {"id"});
    }

    return \@feedids;
}


sub _build_feedstable {
    my $self  = shift;
    my $feeds = shift;
    my $rows  = "";

    foreach my $feedid (@{$feeds}) {
        my $feed = $self -> {"feed"} -> get_feed_byid($feedid);
        print STDERR "Got feed: ".Dumper($feed);

        $rows .= $self -> {"template"} -> load_template("subscriptions/subscription_row.tem", {"***id***"          => $feed -> {"id"},
                                                                                               "***description***" => $feed -> {"description"},
                                                                                               "***name***"        => $feed -> {"name"}
                                                        })
            if($feed);
    }

    return $rows;
}


## @method private $ _build_feedopts($allfeeds, $subscribed)
# Build the multiselect list that lets the user select additional feeds to subscribe to.
#
# @param allfeeds A refrence to an array of feed hashes.
# @return A string containing the multiselect list contents.
sub _build_feedopts {
    my $self       = shift;
    my $allfeeds   = shift;
    my $subscribed = shift;

    my $multidata = [];
    foreach my $feed (@{$allfeeds}) {
        push(@{$multidata}, {"desc" => $feed -> {"description"},
                             "name" => $feed -> {"name"},
                             "id"   => $feed -> {"id"}});
    }

    return $self -> generate_multiselect("feeds", "feed", "feed", $multidata);
}


# ============================================================================
#  Validation functions

## @method private @ _validate_activate()
# Validate, and possibly activate, a subscription based on an authorisation code.
#
# @return An array of two values; the first is true if the activation was successful,
#         and false if it was not (no code specified, or an error occurred). The
#         second is a possible error message if one is available.
sub _validate_activate {
    my $self = shift;

    # Has the user entered an activation code?
    my ($code, $error) = $self -> validate_string('actcode', { "required"   => 1,
                                                               "nicename"   => $self -> {"template"} -> replace_langvar("SUBS_ACTCODE_CODE"),
                                                               "minlen"     => 64,
                                                               "maxlen"     => 64,
                                                               "formattest" => '^[a-zA-Z0-9]+$',
                                                               "formatdesc" => $self -> {"template"} -> replace_langvar("SUBS_ACTFORM_CODEFMT"),
                                                  });

    # If there's no code to process, we can't do anything else in here, but it's not
    # necessarily an error condition
    return (0, $error) if(!$code || $error);

    # If there's a code, attempt to activate the subscription associated with it
    my $activated = $self -> {"subscription"} -> activate_subscription_bycode($code)
        or return (0, $self -> {"subscription"} -> errstr());

    # Get here and the activation has been successful.
    return (1, undef);
}


## @method $ _validate_resend()
# Determine whether the user has specified an email address, and if it is valid
# send a new code to the address if appropriate.
#
# @return An array of two values; the first is true if the code has been sent, false
#         if it has not. The second is a possible error message if one is available.
sub _validate_resend {
    my $self = shift;

    my $anonymous = $self -> {"session"} -> anonymous_session();
    my $userid = $self -> {"session"} -> get_session_userid();

    my ($email, $err) = $self -> validate_string('email', { "required" => 0,
                                                            "nicename" => $self -> {"template"} -> replace_langvar("SUBS_RESENDFORM_EMAIL"),
                                                            "minlen"   => 2,
                                                            "maxlen"   => 256,

                                                 });
    return (0, $err) if(!$email);

    # Check the email is vaguely valid
    return $self -> {"template"} -> replace_langvar("SUBS_ERR_BADEMAIL")
        if($email !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

    # Address is possibly valid, try sending a new code
    my $actcode = $self -> {"subscription"} -> get_activation_code($anonymous ? undef : $userid, $email, 1)
        or return (0, $self -> {"subscription"} -> errstr());

    # And send the activation email
    $self -> _send_act_email($email, $actcode);

    return (1, undef);
}


## @method private @ _validate_delete()
# Validate, and possibly delete a subscription based on an authorisation code.
#
# @return An array of two values; the first is true if the activation was successful,
#         and false if it was not (no code specified, or an error occurred). The
#         second is a possible error message if one is available.
sub _validate_delete {
    my $self = shift;

    # Has the user entered an authorisation code?
    my ($code, $error) = $self -> validate_string('authcode', { "required"   => 1,
                                                                "nicename"   => $self -> {"template"} -> replace_langvar("SUBS_DELFORM_CODE"),
                                                                "minlen"     => 64,
                                                                "maxlen"     => 64,
                                                                "formattest" => '^[a-zA-Z0-9]+$',
                                                                "formatdesc" => $self -> {"template"} -> replace_langvar("SUBS_DELFORM_CODEFMT"),
                                                  });

    # If there's no code to process, we can't do anything else in here, but it's not
    # necessarily an error condition
    return (0, $error) if(!$code || $error);

    my $deleted = $self -> {"subscription"} -> delete_subscription("authcode" => $code)
        or return (0, $self -> {"subscription"} -> errstr());

    # Get here and the activation has been successful.
    return (1, undef);
}


# ============================================================================
#  Content generation functions

## @method private @ _generate_resend_form()
# Generate a form through which the user may request a new subscription activation code.
#
# @return An array of two values: the page title string, the code form or success box.
sub _generate_resend_form {
    my $self  = shift;

    my ($sent, $error) = $self -> _validate_resend();

    if($sent) {
        my $url = $self -> build_url("block" => "subscribe", "pathinfo" => [ "activate" ]);
        my $now = $self -> {"template"} -> format_time(time());

        return ($self -> {"template"} -> replace_langvar("SUBS_RESEND_DONETITLE"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("SUBS_RESEND_DONETITLE"),
                                                     "security",
                                                     $self -> {"template"} -> replace_langvar("SUBS_RESEND_SUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("SUBS_RESEND_LONGDESC", {"***now***" => $now}),
                                                     undef,
                                                     "subcore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("SUBS_ACTFORM"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    } else {
        my $anonwarn = $self -> {"template"} -> load_template("subscriptions/resend_anonwarn.tem")
            if($self -> {"session"} -> anonymous_session());

        # Wrap the error message in a message box if we have one.
        $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
            if($error);

        return ($self -> {"template"} -> replace_langvar("SUBS_RESENDFORM"),
                $self -> {"template"} -> load_template("subscriptions/resend_form.tem", {"***error***"    => $error,
                                                                                         "***anonwarn***" => $anonwarn,
                                                                                         "***target***"   => $self -> build_url("block" => "subscribe", "pathinfo" => [ "resend" ])}));
    }
}


## @method private @ _generate_activate_form()
# Generate a form through which the user may enter their subscription activation code.
#
# @return An array of two values: the page title string, the code form or success box.
sub _generate_activate_form {
    my $self = shift;

    my ($active, $error) = $self -> _validate_activate()
        if($self -> {"cgi"} -> param("actcode"));

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    if(!$active) {
        return ($self -> {"template"} -> replace_langvar("SUBS_ACTFORM"),
                $self -> {"template"} -> load_template("subscriptions/act_form.tem", {"***error***"      => $error,
                                                                                      "***target***"     => $self -> build_url("block" => "subscribe"),
                                                                                      "***url-resend***" => $self -> build_url("block" => "subscribe", "pathinfo" => [ "resend" ]),}));
    } else {
        my $url = $self -> build_url("block" => "feeds", "pathinfo" => [], "params" => []);
        return ($self -> {"template"} -> replace_langvar("SUBS_ACTFORM"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("SUBS_ACTIVATE_DONETITLE"),
                                                     "security",
                                                     $self -> {"template"} -> replace_langvar("SUBS_ACTIVATE_SUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("SUBS_ACTIVATE_LONGDESC"),
                                                     undef,
                                                     "subcore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    }
}


## @method private @ _generate_delete_form()
# Generate a form through which the user may enter an auth code to delete a subscription.
#
# @return An array of two values: the page title string, the code form or success box.
sub _generate_delete_form {
    my $self = shift;

    my ($deleted, $error) = $self -> _validate_delete()
        if($self -> {"cgi"} -> param("authcode"));

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    if(!$deleted) {
        return ($self -> {"template"} -> replace_langvar("SUBS_DELFORM"),
                $self -> {"template"} -> load_template("subscriptions/delete_form.tem", {"***error***"      => $error,
                                                                                         "***target***"     => $self -> build_url("block" => "subscribe")}));
    } else {
        my $url = $self -> build_url("block" => "feeds", "pathinfo" => [], "params" => []);
        return ($self -> {"template"} -> replace_langvar("SUBS_DELFORM"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("SUBS_DELETE_DONETITLE"),
                                                     "security",
                                                     $self -> {"template"} -> replace_langvar("SUBS_DELETE_SUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("SUBS_ACTIVATE_LONGDESC"),
                                                     undef,
                                                     "subcore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    }
}


## @method private $ _generate_manage_form()

sub _generate_manage_form {
    my $self = shift;
    my $args;

    my $anonymous = $self -> {"session"} -> anonymous_session();
    if($anonymous) {
        # Anonymous sessions must have an authcode set in the session data
        my $code = $self -> {"session"} -> get_variable('authcode', '');

        return $self -> _generate_manage_authreq_form()
            unless($code);

        $args -> {"authcode"} = $code;
    } else {
        $args -> {"user_id"} = $self -> {"session"} -> get_session_userid();
    }

    my $subscription = $self -> {"subscription"} -> get_subscription($args);

    if($subscription && $subscription -> {"id"}) {
        # Generate the form body

        # First fetch the list of all available feeds, and a filtered list only
        # including the feeds subscribed to by the user.
        my $allfeeds = $self -> {"feed"} -> get_feeds();
        my $subfeeds = $self -> {"feed"} -> get_feeds($subscription -> {"feeds"});

        my $feedtable = $self -> _build_feedstable($subscription -> {"feeds"});
        my $feedopts  = $self -> _build_feedopts($allfeeds, $subfeeds);

        return ($self -> {"template"} -> replace_langvar("SUBS_MANAGE"),
                $self -> {"template"} -> load_template("subscriptions/subscription.tem", {"***feeds***"    => $feedtable,
                                                                                          "***feedopts***" => $feedopts,
                                                       }));
    } else {
        # No subscription found, complain.
        my $url = $self -> build_url("block" => "feeds", "pathinfo" => [], "params" => []);

        return ($self -> {"template"} -> replace_langvar("SUBS_MANAGE"),
                $self -> {"template"} -> message_box($self -> {"template"} -> replace_langvar("SUBS_MANAGE_NOSUBFOUND"),
                                                     "error",
                                                     $self -> {"template"} -> replace_langvar("SUBS_MANAGE_NOSUB_SUMMARY"),
                                                     $self -> {"template"} -> replace_langvar("SUBS_MANAGE_NOSUB_LONGDESC"),
                                                     undef,
                                                     "subcore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                        "colour"  => "blue",
                                                        "action"  => "location.href='$url'"} ]));
    }
}


# ============================================================================
#  API functions

## @method private $ _build_currentsub_list($subdata)
#
sub _build_currentsub_list {
    my $self    = shift;
    my $subdata = shift;
    my @feedlist;

    foreach my $feedid (@{$subdata -> {"feeds"}}) {
        my $feed = $self -> {"feed"} -> get_feed_byid($feedid);

        push(@feedlist, $feed );
    }

    return \@feedlist;
}


## @method private $ _build_addsubscription_response()
# Generate the API response to requests to add feeds to a user's subscription
# based on theri current session and/or a specified email address.
#
# @return A reference to a hash to send back to the client as an API response.
sub _build_addsubscription_response {
    my $self = shift;

    # fetch the value data
    my $values = $self -> {"cgi"} -> param('values')
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_NODATA"));

    my $settings = eval { JSON::decode_json($values) }
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_BADDATA"));

    # Is the user logged in?
    my $anonymous = $self -> {"session"} -> anonymous_session();
    my $userid = $self -> {"session"} -> get_session_userid();

    # Anonymous users *must* provide an email address
    return $self -> api_errorhash('bad_data', $self -> {"template"} -> replace_langvar("SUBS_ERR_NOREQEMAIL"))
        if($anonymous && !$settings -> {"email"});

    # If an email address has been provided, verify it is vaguely valid. As noted in Login.pm,
    # this is not fully compliant, but madness follows that way.
    return $self -> api_errorhash('bad_data', $self -> {"template"} -> replace_langvar("SUBS_ERR_BADEMAIL"))
        if($settings -> {"email"} && $settings -> {"email"} !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

    # if the email has been set, check that the email is not already the user's email
    if($userid && $settings -> {"email"}) {
        my $user = $self -> {"session"} -> get_user_byid($userid)
            or return $self -> api_errorhash('internal', "Unable to locate data for user: ".$self -> {"session"} -> errstr());

        # If the email addresses match, clear the specified email as it's redundant
        # and would force subscription activation if it was retained.
        $settings -> {"email"} = undef
            if($user -> {"email"} && lc($user -> {"email"}) eq lc($settings -> {"email"}));
    }

    # If an email has been set, and is still present, check that it isn't an existing user's default or alternative
    if($settings -> {"email"}) {
        my $accept_email = $self -> {"subscription"} -> check_email($settings -> {"email"}, $anonymous ? undef : $userid);

        return $self -> api_errorhash('internal', $self -> {"template"} -> replace_langvar("SUBS_ERR_USEREMAIL"))
            if(!$accept_email);
    }

    my $feeds = $self -> _build_feed_list($settings -> {"feeds"});
    return $self -> api_errorhash('internal', $feeds) if(!ref($feeds));

    # Set up the subscription - this will add the selected feeds to the user's
    # subscription, and hand back the subscription header we'll need later.
    my $subscription = $self -> {"subscription"} -> set_user_subscription($anonymous ? undef : $userid,
                                                                          $settings -> {"email"},
                                                                          $feeds)
        or return $self -> api_errorhash('internal', "Subscription failed: ".$self -> {"subscription"} -> errstr());

    my $successmsg;
    if($self -> {"subscription"} -> requires_activation($anonymous ? undef : $userid,
                                                        $settings -> {"email"})) {

        # Grab an activation code - this'll generate a new code each time.
        my $actcode = $self -> {"subscription"} -> get_activation_code($anonymous ? undef : $userid,
                                                                       $settings -> {"email"},
                                                                       1)
            or return $self -> api_errorhash('internal', $self -> {"subscription"} -> errstr());

        # And send the activation email
        $self -> _send_act_email($settings -> {"email"}, $actcode);

        $successmsg = $self -> {"template"} -> replace_langvar("SUBS_ACTEMAIL")
    } else {
        # activate the subscription directly. This won't actually do anything as far as activation
        # is concerned - the subscription isn't inactive - but it will do subscription merging as
        # required by point B (specifically B1) in the class description
        $self -> {"subscription"} -> activate_subscription_byid($subscription -> {"id"})
            or return $self -> api_errorhash('internal', $self -> {"subscription"} -> errstr());

        $successmsg = $self -> {"template"} -> replace_langvar("SUBS_SUBSCRIBED")
    }

    my $resp = { "result" => { "response" => { "button"  => $self -> {"template"} -> replace_langvar("PAGE_ERROROK"),
                                               "content" => $successmsg,
                               },
                               "feeds" => $self -> _build_currentsub_list($subscription)
                 }
    };

    return $resp;
}


sub _build_appendsubscription_response {
    my $self = shift;
    my $args = {};

    # Work out how to get hold of the subscription we're deleting from...
    my $anonymous = $self -> {"session"} -> anonymous_session();
    if($anonymous) {
        # Anonymous sessions must have an authcode set in the session data
        my $code = $self -> {"session"} -> get_variable('authcode', '');

        return $self -> api_errorhash('auth', $self -> {"template"} -> replace_langvar("SUBS_ERR_NOUSERDATA"))
            unless($code);

        $args -> {"authcode"} = $code;
    } else {
        $args -> {"user_id"} = $self -> {"session"} -> get_session_userid();
    }

    print STDERR "Appending subscription";

    # ...and now try to fetch the subscription; if there is no data, there's no subscription for the user
    # This can only really happen if there's no subscription, or the authcode is bad.
    my $subscription = $self -> {"subscription"} -> get_subscription($args);
    return $self -> api_errorhash('auth', $self -> {"template"} -> replace_langvar("SUBS_ERR_NOUSUBSCRPT"))
        if(!$subscription || !$subscription -> {"id"});

    my $values = $self -> {"cgi"} -> param('values')
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_NODATA"));

    my $settings = eval { JSON::decode_json($values) }
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_BADDATA"));


    print STDERR "Settings: ".Dumper($settings);

    my $rows = $self -> {"subscription"} -> add_to_subscription($subscription -> {"id"}, $settings -> {"feeds"});
    return $self -> api_errorhash("internal", $self -> {"subscription"} -> errstr)
        if(!defined($rows));

    my $resp = { "result" => { "response" => { "button"  => $self -> {"template"} -> replace_langvar("PAGE_ERROROK"),
                                               "content" => $self -> {"template"} -> replace_langvar("SUBS_SUBSCRIBED"),
                               },
                               "feeds" => $self -> _build_currentsub_list($subscription)
                 }
    };

    return $resp;
}


## @method private $ _build_remsubscription_response()
# Generate the API response to requests to remove feeds from a user's subscription
# based on their current session or an authcode.
#
# @return A reference to a hash to send back to the client as an API response.
sub _build_remsubscription_response {
    my $self = shift;
    my $args = {};

    # Work out how to get hold of the subscription we're deleting from...
    my $anonymous = $self -> {"session"} -> anonymous_session();
    if($anonymous) {
        # Anonymous sessions must have an authcode set in the session data
        my $code = $self -> {"session"} -> get_variable('authcode', '');

        return $self -> api_errorhash('auth', $self -> {"template"} -> replace_langvar("SUBS_ERR_NOUSERDATA"))
            unless($code);

        $args -> {"authcode"} = $code;
    } else {
        $args -> {"user_id"} = $self -> {"session"} -> get_session_userid();
    }

    # ...and now try to fetch the subscription; if there is no data, there's no subscription for the user
    # This can only really happen if there's no subscription, or the authcode is bad.
    my $subscription = $self -> {"subscription"} -> get_subscription($args);
    return $self -> api_errorhash('auth', $self -> {"template"} -> replace_langvar("SUBS_ERR_NOUSUBSCRPT"))
        if(!$subscription || !$subscription -> {"id"});

    my $values = $self -> {"cgi"} -> param('values')
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_NODATA"));

    my $settings = eval { JSON::decode_json($values) }
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_BADDATA"));

    my $rows = $self -> {"subscription"} -> remove_from_subscription($subscription -> {"id"}, $settings -> {"feeds"});
    return $self -> api_errorhash("internal", $self -> {"subscription"} -> errstr)
        if(!defined($rows));

    my $resp = { "result" => { "response" => { "button"  => $self -> {"template"} -> replace_langvar("PAGE_ERROROK"),
                                               "content" => $self -> {"template"} -> replace_langvar("SUBS_UNSUBSCRIBED"),
                               },
                               "feeds" => $self -> _build_currentsub_list($subscription)
                 }
    };

    return $resp;
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Produce the string containing this block's full page content. This generates
# the compose page, including any errors or user feedback.
#
# @return The string containing this block's page content.
sub page_display {
    my $self = shift;
    my ($title, $content, $extrahead);

    # NOTE: no need to check login here, this module can be used without logging in.

    # However, we do want to make sure that the subscribe control is enforced
    if(!$self -> check_permission("subscribe")) {
        $self -> log("error:subscribe:permission", "User does not have permission to subscribe to feeds");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_SUBSCRIBE_DESC}",
                                                           undef,
                                                           "errorcore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='".$self -> build_url(block => "feeds", pathinfo => [])."'"} ]);

        return $self -> {"template"} -> load_template("error/general.tem",
                                                      {"***title***"     => "{L_PERMISSION_FAILED_TITLE}",
                                                       "***message***"   => $message,
                                                       "***extrahead***" => "",
                                                       "***userbar***"   => $userbar -> block_display("{L_PERMISSION_FAILED_TITLE}"),
                                                      })
    }


    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        print STDERR "Got op $apiop";
        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                when('add')    { return $self -> api_response($self -> _build_addsubscription_response()   , KeyAttr => { 'feeds' => 'id' }); }
                when('append') { return $self -> api_response($self -> _build_appendsubscription_response(), KeyAttr => { 'feeds' => 'id' }); }
                when('rem')    { return $self -> api_response($self -> _build_remsubscription_response()   , KeyAttr => { 'feeds' => 'id' }); }

                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[0]) {
            when("activate")  { ($title, $content) = $self -> _generate_activate_form(); }
            when("resend")    { ($title, $content) = $self -> _generate_resend_form(); }
            when("delete")    { ($title, $content) = $self -> _generate_delete_form(); }
            when("manage")    { ($title, $content) = $self -> _generate_manage_form(); }
            default {
                ($title, $content) = $self -> _generate_manage();
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("subscriptions/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "subscriptions");
    }
}

1;
