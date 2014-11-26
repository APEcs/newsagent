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
use experimental qw(smartmatch);
use base qw(Newsagent::Newsletter); # This class extends the Newsagent block class
use Webperl::Utils qw(path_join);
use JSON;
use v5.12;
use Data::Dumper;


# ============================================================================
#  Content support

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
        my $highlight = ($newslet -> {"value"} eq $active -> {"name"}) ? "active" : "";
        my $title = $self -> {"template"} -> replace_langvar("NEWSLETTER_MODE_".uc($newslet -> {"mode"}), {"***name***" => $newslet -> {"name"}});

        $result .= $self -> {"template"} -> load_template("newsletter/list/newsletter.tem", {"***highlight***" => $highlight,
                                                                                             "***id***"        => $newslet -> {"value"},
                                                                                             "***name***"      => $newslet -> {"name"},
                                                                                             "***mode***"      => $newslet -> {"mode"},
                                                                                             "***title***"     => $title,});
    }

    # Fallback for users with no newsletters.
    $result = $self -> {"template"} -> load_template("newsletter/list/nonewsletter.tem")
        if(!$result);

    return $result;
}


## @method private $ _build_controls($newsletter, $usenext, $reldate, $dates)
# Create the content to show in the controls area of the newsletter list.
#
# @param newsletter A reference to a hash containing the newsletter data.
# @param usenext    Is the next newsletter being shown?
# @param reldate    The release date of the newsletter (may be in the past for
#                   late newsletters.
# @param dates      A reference to a hash containing the potential release
#                   dates for the newsletter. This may be undef for manual
#                   newsletters, but is required for automated newsletters.
# @return A string contaning the controls.
sub _build_controls {
    my $self       = shift;
    my $newsletter = shift;
    my $usenext    = shift;
    my $reldate    = shift;
    my $dates      = shift;
    my $blocked    = shift;
    my $publish    = $self -> check_permission("newsletter.publish", $newsletter -> {"metadata_id"});
    my $pubtem;

    my $pubmode = "nopublish";
    $pubmode = $blocked ? "publish-blocked" : "publish"
        if($publish);

    # Manual release newsletters get a 'publish' option (which may be disabled) if the
    # list is currently showing the next newsletter. This is generally always the case,
    # but check for it anyway to be certain.
    if(!$newsletter -> {"schedule"}) {
        if($usenext) {
            $pubtem = $self -> {"template"} -> load_template("newsletter/list/control-manual-".$pubmode.".tem");
        }
        return  $self -> {"template"} -> load_template("newsletter/list/control-manual.tem", { "***schedule***" => $newsletter -> {"id"},
                                                                                               "***publish***"  => $pubtem });

    # Automatic release newsletters get a 'publish' option (which, again, may be disabled)
    # if the next newsletter is currently being shown, and it is a late release.
    } else {
        if($usenext && $self -> {"schedule"} -> late_release($newsletter)) {
            $pubtem = $self -> {"template"} -> load_template("newsletter/list/control-auto-".$pubmode.".tem");
        }

        my $next_date = DateTime -> from_epoch(epoch => $reldate);
        return $self -> {"template"} -> load_template("newsletter/list/control-auto.tem", { "***schedule***"   => $newsletter -> {"id"},
                                                                                            "***allowdates***" => encode_json($dates -> {"hashed"}),
                                                                                            "***next_date***"  => $next_date -> strftime("%d/%m/%Y"),
                                                                                            "***publish***"    => $pubtem});
    }
}


# ============================================================================
#  Content generators

## @method private @ _generate_newsletter_preview($newsname, $issue)
# Generate a preview of the selected newsletter
#
# @param newsid The name of the currently selected newsletter
# @param issue  A reference to an array containing the issue date (YYYY, MM, DD)
# @return Three strings: the page title, the contents of the page, and the
#         extra header string.
sub _generate_newsletter_preview {
    my $self     = shift;
    my $newsname = shift;
    my $issue    = shift;
    my ($title, $extrahead) = ("Unknown newsletter", undef);

    my ($content, $newsletter) = $self -> build_newsletter($newsname, $issue, $self -> {"session"} -> get_session_userid());
    if($newsletter) {
        $title     = $newsletter -> {"description"};
#        $extrahead = $self -> {"template"}  -> load_template(path_join($newsletter -> {"template"}, "extrahead.tem"));
    }

    return ($self -> {"template"} -> replace_langvar("NEWSLETTER_LIST_PREVIEW", {"***newsletter***" => $title }),
            $self -> {"template"} -> load_template("newsletter/list/preview.tem", {"***newsletter***" => $title,
                                                                                   "***content***"    => $content}),
            $extrahead);
}


## @method private @ _generate_newsletter_list($newsname, $issue)
# Generate the contents of a page listing the messages in the specified newsletter.
#
# @param newsid The name of the currently selected newsletter
# @param issue  A reference to an array containing the issue date (YYYY, MM, DD)
# @return Two strings: the page title, and the contents of the page.
sub _generate_newsletter_list {
    my $self     = shift;
    my $newsname = shift;
    my $issue    = shift;
    my $userid   = $self -> {"session"} -> get_session_userid();
    my ($newsletlist, $msglist, $controls, $intro, $sections) = ("", "", "", "", []);

    # Fetch the list of schedules and sections the user can edit
    my $schedules  = $self -> {"schedule"} -> get_user_schedule_sections($userid);

    # And get the newsletter the user has selected
    my $newsletter = $self -> {"schedule"} -> active_newsletter($newsname, $userid);

    # If a newsletter is selected, build the page
    if($newsletter) {
        $newsletlist = $self -> _build_newsletter_list($schedules, $newsletter);

        # Fetch the list of dates teh newsletter is released on (this is undef for manual releases)
        my $dates = $self -> {"schedule"} -> get_newsletter_datelist($newsletter, $self -> {"settings"} -> {"config"} -> {"newsletter:future_count"});

        # And work out the date range for articles that should appear in the selected issue
        my ($mindate, $maxdate, $usenext) = $self -> {"schedule"} -> get_newsletter_daterange($newsletter, $dates, $issue);

        # Fetch the messages set for the current newsletter
        my ($messages, $blocked) = $self -> {"schedule"} -> get_newsletter_messages($newsletter -> {"id"}, $userid, $usenext, $mindate, $maxdate);
        foreach my $section (@{$messages}) {
            my $contents = "";

            # build the list of messages inside the current section
            foreach my $message (@{$section -> {"messages"}}) {
                my $title = $message -> {"title"} || $self -> {"template"} -> format_time($message -> {"release_time"});

                $contents .= $self -> {"template"} -> load_template("newsletter/list/message.tem", {"***msgid***" => $message -> {"id"},
                                                                                                    "***subject***" => $title,
                                                                                                    "***summary***" => $message -> {"summary"}});
            }

            $msglist .= $self -> {"template"} -> load_template("newsletter/list/section.tem", {"***title***"    => $section -> {"name"},
                                                                                               "***messages***" => $contents,
                                                                                               "***schedule***" => $newsletter -> {"id"},
                                                                                               "***section***"  => $section -> {"id"},
                                                                                               "***editable***" => $section -> {"editable"} ? "edit" : "noedit",
                                                                                               "***required***" => $section -> {"required"} ? "required" : "",
                                                                                               "***empty***"    => scalar(@{$section -> {"messages"}}) ? "" : "empty"
                                                               });
        }

        $controls = $self -> _build_controls($newsletter, $usenext, $maxdate, $dates, $blocked);
    } else {
        $newsname = undef;
    }

    my $previewpath = [$newsname, "preview"];
    push(@{$previewpath}, $issue -> [0], $issue -> [1], $issue -> [2])
        if($issue && scalar(@{$issue}));

    return ($self -> {"template"} -> replace_langvar("NEWSLETTER_LIST_TITLE"),
            $self -> {"template"} -> load_template("newsletter/list/content.tem", {"***newslets***"   => $newsletlist,
                                                                                   "***messages***"   => $msglist,
                                                                                   "***intro***"      => $intro,
                                                                                   "***controls***"   => $controls,
                                                                                   "***nlist-url***"  => $self -> build_url(block    => "newsletters",
                                                                                                                            params   => [],
                                                                                                                            pathinfo => []),
                                                                                   "***issue-url***"  => $self -> build_url(block    => "newsletters",
                                                                                                                            params   => [],
                                                                                                                            pathinfo => [$newsname, "issue"]),
                                                                                   "***preview-url***" => $self -> build_url(block    => "newsletters",
                                                                                                                             params   => [],
                                                                                                                             pathinfo => $previewpath)
                                                   }));

}


# ============================================================================
#  API functions

## @method $ _build_sortorder_response()
# Generate a hash containing the response to a sort order change.
#
# @return A reference to a hash containing the API response.
sub _build_sortorder_response {
    my $self = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    # the sort information is in JSON format
    my $sortinfo = $self -> {"cgi"} -> param("sortinfo")
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("NEWSLETTER_ERR_NOSORT"));

    my $sortdata = eval { decode_json($sortinfo) }
        or return $self -> api_errorhash('bad_data',
                                         $self -> {"template"} -> replace_langvar("NEWSLETTER_ERR_BADSORT"));


    # Sortdata should now be a reference to an array of strings describing newsletter articles
    # use that to update the sort ordering.
    $self -> {"schedule"} -> reorder_articles_fromsortdata($sortdata, $userid)
        or return $self -> api_errorhash('api_error', $self -> {"schedule"} -> errstr());

    return { "result" => { "status" => $self -> {"template"} -> replace_langvar("NEWSLETTER_LIST_SAVED") } };
}


## @method $ _build_publish_response()
# Generate a hash containing the response to a sort order change.
#
# @return A reference to a hash containing the API response.
sub _build_publish_response {
    my $self   = shift;
    my $userid = $self -> {"session"} -> get_session_userid();
    my ($args, $error, @issue);

    ($args -> {"issue"}, $error) = $self -> validate_string("issue", {"required"   => 0,
                                                                      "nicename"   => "Issue",
                                                                      "formattest" => '^\d{4}-\d{2}-\d{2}$',
                                                                      "formatdesc" => "Issue format: YYYY-MM-DD",
                                                            });
    return $self -> api_errorhash("api_error", $error) if($error);

    ($args -> {"name"}, $error) = $self -> validate_string("name", {"required"   => 1,
                                                                    "nicename"   => "Newsletter",
                                                                    "formattest" => '^\w+$',
                                                                    "formatdesc" => $self -> {"template"} -> replace_langvar("NEWSLETTER_API_BADNAME"),
                                                           });
    return $self -> api_errorhash("api_error", $error) if($error);

    # If an issue has been provided, split it
    @issue = $args -> {"issue"} =~ /^(\d{4})-(\d{2})-(\d{2})$/
        if($args -> {"issue"});

    $error = $self -> publish_newsletter($args -> {"name"}, \@issue, $userid);
    return $self -> api_errorhash("api_error", $error) if($error);

    return { "result" => { "status" => $self -> {"template"} -> replace_langvar("NEWSLETTER_API_PUBLISHED") } };
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
        $self -> log("error:newsletter:permission", "User does not have permission to list newsletters");

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
            when("publish")   { $self -> api_response($self -> _build_publish_response()); }
            when("sortorder") { $self -> api_response($self -> _build_sortorder_response()); }
            default {
                return $self -> api_response($self -> api_errorhash('bad_op',
                                                                    $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[1]) {
            when("preview") { ($title, $content, $extrahead) = $self -> _generate_newsletter_preview($pathinfo[0], [$pathinfo[2], $pathinfo[3], $pathinfo[4]]); }
            when("issue")   { ($title, $content)             = $self -> _generate_newsletter_list($pathinfo[0], [$pathinfo[2], $pathinfo[3], $pathinfo[4]]); }
            default {
                ($title, $content) = $self -> _generate_newsletter_list($pathinfo[0]);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("newsletter/list/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "newsletterlist");
    }
}

1;
