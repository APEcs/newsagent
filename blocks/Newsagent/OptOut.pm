# @file
# This file contains the implementation of the opt-out facility.
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
package Newsagent::OptOut;

use strict;
use experimental qw(smartmatch);
use base qw(Newsagent::Newsletter); # This class extends the Newsagent block class
use Webperl::Utils qw(path_join);
use JSON;
use v5.12;
use Data::Dumper;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the OptOut facility, loads the System::Feed model
# and other classes required to generate the subscriptions pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::OptOut object on success, undef on error.
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

    return $self;
}



sub _generate_optout_form {
    my $self = shift;
    my $user = $self -> {"session"} -> get_user_byid();

    my $checked = $user -> {"opt_out"} ? 'checked="checked"' : '';

    if($self -> {"cgi"} -> param('setoptout')) {
        my $state = $self -> {"cgi"} -> param("optout");

        $self -> log("optout.set", "User has submitted new optout preferences - state is ".($state ? "1" : "0"));

        $self -> {"session"} -> {"auth"} -> {"app"} -> set_user_optout($user -> {"user_id"},
                                                                       $state ? 1 : 0);

        return ($self -> {"template"} -> replace_langvar("OPTOUT_TITLE"),
                $self -> {"template"} -> message_box("{L_OPTOUT_TITLE}",
                                                     "articleok",
                                                     "{L_OPTOUT_SUMMARY}",
                                                     "{L_OPTOUT_DESC}",
                                                     undef,
                                                     "messagecore",
                                                     [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                        "colour"  => "blue",
                                                            "action"  => "location.href='".$self -> build_url(block => "feeds", pathinfo => [])."'"} ])
            );
    }

    $self -> log("optout.set", "User viewing optout form");

    my $feeds = $self -> {"feed"} -> get_feeds(override => 1);
    my $overrides = "";
    foreach my $feed (@{$feeds}) {
        $overrides .= $self -> {"template"} -> load_template("optout/feed.tem",
                                                             {
                                                                 "***feed***" => $feed -> {"description"},
                                                             });
    }

    return ($self -> {"template"} -> replace_langvar("OPTOUT_TITLE"),
            $self -> {"template"} -> load_template("optout/content.tem",
                                                   {
                                                       "***optout***"    => $checked,
                                                       "***overrides***" => $overrides,
                                                   })
        );

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

    my $error = $self -> check_login();
    return $error if($error);

    # Exit with a permission error unless the user has permission to list newsletters
    # this could be deduced by checking the user's permissions against all newsletters,
    # but that'll take longer than needed.
    if(!$self -> check_permission("optout")) {
        $self -> log("error:newsletter:permission", "User does not have permission to control opt-out");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_OPTOUT_DESC}",
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
        # API call - dispatch to appropriate handler.
        given($apiop) {
            default {
                return $self -> api_response($self -> api_errorhash('bad_op',
                                                                    $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> multi_param('pathinfo');

        given($pathinfo[1]) {
            default {
                ($title, $content) = $self -> _generate_optout_form($pathinfo[0]);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("optout/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "optout");
    }
}

1;
