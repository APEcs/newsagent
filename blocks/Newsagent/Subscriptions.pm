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
package Newsagent::Subscriptions;

use strict;
use experimental qw(smartmatch);
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Feed;
use Newsagent::System::Subscriptions;
use JSON;
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

sub send_act_email {
    my $self    = shift;
    my $email   = shift;
    my $actcode = shift;

    # Build URLs to place in the email.
    my $acturl  = $self -> build_url("fullurl"  => 1,
                                     "block"    => "subscribe",
                                     "pathinfo" => [],
                                     "params"   => "actcode=".$actcode);
    my $actform = $self -> build_url("fullurl"  => 1,
                                     "block"    => "subscribe",
                                     "pathinfo" => [ "activate" ]);

    my $status = $self -> {"messages"} -> queue_message(subject => $self -> {"template"} -> replace_langvar("SUBS_ACTCODE_SUBJECT"),
                                                        message => $self -> {"template"} -> load_template("subscription/email_actcode.tem",
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

## @method private _build_feed_list($feeds)
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


# ============================================================================
#  API functions

## @method private $ _build_addsubscription_response()
#
sub _build_addsubscription_response {
    my $self = shift;

    # fetch the value data
    my $values = $self -> {"cgi"} -> param('values')
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("SUBS_ERR_NODATA"));

    my $settings = eval { decode_json($values) }
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
        if($settings -> {"email"} !~ /^[\w.+-]+\@([\w-]+\.)+\w+$/);

    # if the email has been set, check that the email is not already the user's email
    if($userid && $settings -> {"email"}) {
        my $user = $self -> {"session"} -> get_user_byid($userid)
            or return $self -> api_errorhash('internal', "Unable to locate data for user: ".$self -> {"session"} -> errstr());

        # If the email addresses match, clear the specified email as it's redundant
        # and would force subscription activation if it was retained.
        $settings -> {"email"} = undef
            if(lc($user -> {"email"}) eq lc($settings -> {"email"}));
    }

    my $feeds = $self -> _build_feed_list($settings -> {"feeds"});
    return $self -> api_errorhash('internal', $feeds) if(!ref($feeds));

    $self -> {"subscription"} -> set_user_subscription($anonymous ? undef : $userid,
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
        $self -> send_act_email($settings -> {"email"}, $actcode);

        $successmsg = $self -> {"template"} -> replace_langvar("SUBS_ACTEMAIL")
    } else {
        $successmsg = $self -> {"template"} -> replace_langvar("SUBS_SUBSCRIBED")
    }

    return { "result" => { "button"  => $self -> {"template"} -> replace_langvar("PAGE_ERROROK"),
                           "content" => $successmsg
                         }
           };
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

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                when('add') { return $self -> api_response($self -> _build_addsubscription_response()); }

                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[2]) {
            default {
                ($title, $content) = $self -> _generate_manage();
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("subscriptions/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "subscriptions");
    }
}

1;
