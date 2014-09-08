# @file
# This file contains the implementation of the article listing facility.
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
package Newsagent::Newsletter::List;

use strict;
use base qw(Newsagent::Article); # This class extends the Newsagent block class
use Webperl::Utils qw(is_defined_numeric);
use DateTime::Event::Cron;
use POSIX qw(ceil);
use v5.12;


# ============================================================================
#  Content generators

## @method private $ _build_newsletter_list($schedules, $active)
# Generate a list of divs that can be used to select the newsletter to edit.
#
# @param schedules A reference to a hash containing the schedule data.
# @param active    A reference to a hash containing the active newsletter information.
# @return A string containing the newsletter list.
sub _build_newsletter_list {
    my $self      = shift;
    my $schedules = shift;
    my $active    = shift;
    my $result    = "";

    foreach my $newslet (@{$schedules -> {"_schedules"}}) {
        my $highlight = ($newlet -> {"value"} == $active -> {"id"}) ? "active" : "";

        $result .= $self -> {"template"} -> load_template("newsletter/list/newsletter.tem", {"***highlight***" => $highlight,
                                                                                             "***id***"        => $newslet -> {"id"},
                                                                                             "***name***"      => $newslet -> {"name"}});
    }

    # Fallback for users with no newsletters.
    $result = $self -> {"template"} -> load_template("newsletter/list/nonewsletter.tem")
        if(!$result);

    return $result;
}



## @method private @ _generate_newsletterlist($newsid)
# Generate the contents of a page listing the messages in the specified newsletter.
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_newsletterlist {
    my $self   = shift;
    my $newsid = shift;
    my $userid = $self -> {"session"} -> get_session_userid();
    my ($newsletlist, $usedmsg, $availmsg, $sections) = ("", "", "", []);

    # Fetch the list of schedules and sections the user can edit
    my $schedules  = $self -> {"schedule"} -> get_user_schedule_sections($userid);

    # And get the newsletter the user has selected
    my $newsletter = $self -> {"schedule"} -> active_newsletter($newsid, $userid);

    # If a newsletter is selected, build the page
    if($newsletter) {
        $newsletlist = $self -> _build_newsletter_list($schedules, $newsletter);

        # Fetch the messages set for the current message
        my $messages = $self -> {"schedule"} -> get_newslettter_messages($newsletter -> {"id"}, $userid);
        foreach my $section (@{$messages}) {
            my $contents = "";

            # build the list of messages inside the current section
            foreach my $message (@{$section -> {"messages"}}) {
                $contents .= _build_message($message, 'used');
            }

            $usedmsg .= $self -> {"template"} -> load_template("newsletter/list/section.tem", {"***title***"    => $section -> {"name"},
                                                                                               "***messages***" => $contents});
        }
    }

    return ($self -> {"template"} -> replace_langvar("NEWSLETTER_LIST_TITLE"),
            $self -> {"template"} -> load_template("newsletter/list/content.tem", {"***mewslets***" => $newsletlist,
                                                                                   "***usedmsg***"  => $usedmsg,
                                                                                   "***availmsg***" => $availmsg,

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
    if(!$self -> check_permission("newsletter.list")) {
        $self -> log("error:article:permission", "User does not have permission to list newsletters");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_LISTNEWSLETTER_DESC}",
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
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[2]) {
            when("page") { ($title, $content) = $self -> _generate_newsletterlist($pathinfo[0], $pathinfo[2]); }
            default {
                ($title, $content) = $self -> _generate_newsletterlist($pathinfo[0], 1);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("newsletter/list/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "newsletterlist");
    }
}

1;
