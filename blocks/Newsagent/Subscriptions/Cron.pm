## @file
# This file contains the implementation of the cron-triggered subscription
# dispatcher
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
package Newsagent::Subscriptions::Cron;

use strict;
use base qw(Newsagent::Subscriptions); # This class extends the Subscriptions block class
use v5.12;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Cron facility, loads the System::Article model
# and other classes required to perform the cron job, in addition to the classes
# loaded by the Subscriptions module.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Subscriptions object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"schedule"} = Newsagent::System::Schedule -> new(dbh      => $self -> {"dbh"},
                                                               settings => $self -> {"settings"},
                                                               logger   => $self -> {"logger"},
                                                               roles    => $self -> {"system"} -> {"roles"},
                                                               metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"article"} = Newsagent::System::Article -> new(feed     => $self -> {"feed"},
                                                             schedule => $self -> {"schedule"},
                                                             dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Cron job implementation


sub _run_cronjob {
    my $self = shift;


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

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {

        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[0]) {

            default {
                ($title, $content) = $self -> _run_cronjob();
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("subscriptions/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "subscriptions");
    }
}

1;