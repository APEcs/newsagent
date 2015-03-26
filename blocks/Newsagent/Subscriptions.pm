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
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$SystemModule::errstr);

    return $self;
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

    print STDERR Dumper($settings);

    return { "result" => { "button" => $self -> {"template"} -> replace_langvar("PAGE_ERROROK"),
                           "content" => "This is a test here..." } };
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
        print STDERR "Got apiop $apiop";

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
