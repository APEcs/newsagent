## @file
# This file contains the implementation of the tell us composition facility.
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
package Newsagent::TellUs::Compose;

use strict;
use base qw(Newsagent::TellUs); # This class extends the TellUs block class
use v5.12;

# ============================================================================
#  Content generators

## @method private @ _generate_compose($args, $error)
# Generate the page content for a compose page.
#
# @param args  An optional reference to a hash containing defaults for the form fields.
# @param error An optional error message to display above the form if needed.
# @return Two strings, the first containing the page title, the second containing the
#         page content.
sub _generate_compose {
    my $self  = shift;
    my $args  = shift || { };
    my $error = shift;

    # Fix up defaults
    $args -> {"queue"} = $self -> {"settings"} -> {"config"} -> {"TellUs:default_queue"}
        unless($args -> {"queue"});

    my $userid = $self -> {"session"} -> get_session_userid();
    my $queues = $self -> {"tellus"} -> get_queues($userid, "additem");
    my $types  = $self -> {"tellus"} -> get_types();

    # permission-based access to image button
    my $ckeconfig = $self -> check_permission('freeimg') ? "image_open.js" : "basic_open.js";

    # Wrap the error in an error box, if needed.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar("TELLUS_FORM_TITLE"),
            $self -> {"template"} -> load_template("tellus/compose/compose.tem", {"***errorbox***"  => $error,
                                                                                  "***form_url***"  => $self -> build_url(block => "tellus", pathinfo => ["add"]),
                                                                                  "***message***"   => $args -> {"message"},
                                                                                  "***queueopts***" => $self -> {"template"} -> build_optionlist($queues, $args -> {"queue"}),
                                                                                  "***typeopts***"  => $self -> {"template"} -> build_optionlist($types , $args -> {"type"}),
                                                                                  "***ckeconfig***" => $ckeconfig,
                                                   }));
}


## @method private @ _generate_success()
# Generate a success page to send to the user. This creates a message box telling the
# user that their message has been added - this is needed to ensure that users get a
# confirmation, but it isn't generated inside _add_message() or _validate_message() so
# that page refreshes don't submit multiple copies.
#
# @return The page title, content, and meta refresh strings.
sub _generate_success {
    my $self = shift;

    return ("{L_TELLUS_ADDED_TITLE}",
            $self -> {"template"} -> message_box("{L_TELLUS_ADDED_TITLE}",
                                                 "articleok",
                                                 "{L_TELLUS_ADDED_SUMMARY}",
                                                 "{L_TELLUS_ADDED_DESC}",
                                                 undef,
                                                 "messagecore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='".$self -> build_url(block => "feeds", pathinfo => [])."'"} ]),
            ""
        );
}


# ============================================================================
#  Addition functions

## @method private @ _add_message()
# Add a Tell Us message to the system. This validates and processes the values submitted by
# the user in the compose form, and stores the result in the database.
#
# @return Three values: the page title, the content to show in the page, and the extra
#         css and javascript directives to place in the header.
sub _add_message {
    my $self  = shift;
    my $error = "";
    my $args  = {};

    ($error, $args) = $self -> _validate_message();
    return $self -> _generate_compose($args, $error);
}


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

    # Exit with a permission error unless the user has permission to compose
    if(!$self -> check_permission("tellus")) {
        $self -> log("error:compose:permission", "User does not have permission to compose messages");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_TELLUS_DESC}",
                                                           undef,
                                                           "errorcore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]);

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
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');
        # Normal page operation.
        # ... handle operations here...

        if(!scalar(@pathinfo)) {
            ($title, $content, $extrahead) = $self -> _generate_compose();
        } else {
            given($pathinfo[0]) {
                when("add")      { ($title, $content, $extrahead) = $self -> _add_message(); }
                when("success")  { ($title, $content, $extrahead) = $self -> _generate_success(); }
                default {
                    ($title, $content, $extrahead) = $self -> _generate_compose();
                }
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("tellus/compose/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "compose");
    }
}

1;
