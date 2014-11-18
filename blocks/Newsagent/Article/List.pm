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
package Newsagent::Article::List;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Article); # This class extends the Newsagent block class
use Webperl::Utils qw(is_defined_numeric);
use DateTime::Event::Cron;
use POSIX qw(ceil);
use v5.12;
use Data::Dumper;

# ============================================================================
#  General support

## @method private $ _release_time($article)
# Generate a string describing when the specified article is likely to be released.
#
# @param article A reference to a hash containing the article data.
# @return A string describing the release time for the article.
sub _release_time {
    my $self = shift;
    my $article = shift;

    # Articles with no cron info with the schedule are manual release
    if(!$article -> {"section_data"} -> {"schedule"} -> {"schedule"}) {
        return $self -> {"template"} -> replace_langvar("COMPOSE_SHED_MANUAL");

    # Otherwise the article is part of an auto-release newsletter, so we need to work
    # out /which/ newsletter it shoulld be in
    } else {
        my ($releasetime, $late) = $self -> {"schedule"} -> get_issuedate($article);
        return $self -> {"template"} -> load_template("article/list/newsletter-timed.tem", {"***lateclass***" => $late ? "late" : "",
                                                                                            "***next1***"     => $self -> {"template"} -> fancy_time($releasetime, 0, 1)});
    }
}


# ============================================================================
#  Validation/input

## @method private void _set_multiid_sessvar($param, $varname)
# Determines whether a query string parameter with the specified name has been
# provided, and if it has store the list of IDs set by that query string in
# the session variable with the given name. If the parameter has not been set,
# this will do nothing.
#
# @param param   The name of the query string parameter to check.
# @param varname The name of the session variable to store the value in.
sub _set_multiid_sessvar {
    my $self    = shift;
    my $param   = shift;
    my $varname = shift;
    my $regex   = shift || '((\d+),?)+';

    # Has a remove been requested?
    if($self -> {"cgi"} -> param("remove-$param")) {
        $self -> {"session"} -> set_variable($varname, undef);
    } else {
        # Only bother attempting anything if one or more values have been set for the parameter
        my $setval = $self -> {"cgi"} -> param($param);
        if(defined($setval)) {
            # Fetch the parameter in list context, filter out anything that isn't digits or
            # comma separated digits, and then squash into a comma separated string.
            my $value = join(",", grep(/^$regex$/, ($self -> {"cgi"} -> param($param))));

            # Value may potentially contain repeat commas or a trailing comma at this point
            $value =~ s/,+/,/g;
            $value =~ s/,$//;

            $self -> {"session"} -> set_variable($varname, $value);
        }
    }
}


## @method private void _validate_filter_settings()
# Check whether any filter settings have been changed, and if they have store
# the settings in the session.
sub _validate_filter_settings {
    my $self = shift;

    $self -> _set_multiid_sessvar("feeds", "articlelist_feeds");
    $self -> _set_multiid_sessvar("modes", "articlelist_modes", '(([a-z]+),?)+');
}


## @method private @ _get_feed_selection($articles, $settings)
# Generate the list of feeds, and the selected feeds, to show in the feed
# filter dropdown.
#
# @param articles A reference to a hash containing the article data.
# @param settings A reference to a hash containing the settings that were
#                 use when generating the article data.
# @return A reference to an array of option hashes, a reference to an array
#         of selected ids, and a flag indicating whether filtering is active
#         or not.
sub _get_feed_selection {
    my $self     = shift;
    my $articles = shift;
    my $settings = shift;
    my $active   = 0;

    my $feedlist = [];
    my $selids   = [];
    foreach my $feedid (sort { $articles -> {"metadata"} -> {"feeds"} -> {$a} -> {"description"} cmp $articles -> {"metadata"} -> {"feeds"} -> {$b} -> {"description"} } keys(%{$articles -> {"metadata"} -> {"feeds"}})) {
        push(@{$feedlist}, {"desc" => $articles -> {"metadata"} -> {"feeds"} -> {$feedid} -> {"description"},
                            "name" => $articles -> {"metadata"} -> {"feeds"} -> {$feedid} -> {"name"},
                            "id"   => $articles -> {"metadata"} -> {"feeds"} -> {$feedid} -> {"id"}});
    }

    if($settings -> {"feeds"}) {
        $active = 1;
        $selids = $settings -> {"feeds"};
    }

    return ($feedlist, $selids, $active);
}


## @method private @ _get_mode_selection($articles, $settings)
# Generate the list of modes, and the selected modes, to show in the mode
# filter dropdown.
#
# @param articles A reference to a hash containing the article data.
# @param settings A reference to a hash containing the settings that were
#                 use when generating the article data.
# @return A reference to an array of option hashes, a reference to an array
#         of selected ids, and a flag indicating whether filtering is active
#         or not.
sub _get_mode_selection {
    my $self     = shift;
    my $articles = shift;
    my $settings = shift;
    my $active   = 0;

    my $modelist = [];
    my $selmodes = [];

    foreach my $mode (@{$self -> {"filtermodes"}}) {
        push(@{$modelist}, { "desc"  => $mode -> {"desc"},
                             "id"    => $mode -> {"name"},
                             "value" => $mode -> {"name"}});
    }

     if($settings -> {"modes"}) {
        $active = $settings -> {"usermodes"};
        $selmodes = $settings -> {"modes"};
    }

    return ($modelist, $selmodes, $active);
}


## @method private $ _get_articlelist_settings($year, $month, $pagenum)
# Build the settings used to fetch the article list and build the article list
# user interface.
#
# @param year    The year to fetch articles for.
# @param month   The month to fetch articles for.
# @param pagenum The page of results the user is looking at.
# @return A reference to a hash of settings to use for the article list
sub _get_articlelist_settings {
    my $self     = shift;
    my $year     = shift;
    my $month    = shift;
    my $pagenum  = shift;
    my $settings = {"count"       => $self -> {"settings"} -> {"config"} -> {"Article::List:count"},
                    "pagenum"     => 1,
                    "hidedeleted" => 1,
                    "sortfield"   => "",
                    "sortdir"     => ""};

    # First up, handle pagination related operations
    $settings -> {"pagenum"} = $pagenum if(defined($pagenum) && $pagenum =~ /^\d+$/ && $pagenum > 0);
    $settings -> {"offset"}  = ($settings -> {"pagenum"} - 1) * $settings -> {"count"};

    # Now handle month and year
    my ($nowmonth, $nowyear) = (localtime)[4, 5];
    $nowyear  += 1900; # Handle localtime output
    $nowmonth += 1;

    my ($setmonth, $setyear);
    ($setyear) = $year =~ /^0*(\d+)$/
        if($year);

    ($setmonth) = $month =~ /^0*(\d+)$/
        if($month);

    # record the user settings or the default
    $settings -> {"month"} = $setmonth || $nowmonth;
    $settings -> {"year"}  = $setyear  || $nowyear;

    # And check and force ranges
    $settings -> {"month"} = $nowmonth
        if($settings -> {"month"} < 1 || $settings -> {"month"} > 12);

    $settings -> {"year"} = $nowyear
        if($settings -> {"year"} < 1900);

    # Calculate next and previous
    my $setdate  = DateTime -> new(year => $settings -> {"year"}, month => $settings -> {"month"});
    my $prevdate = $setdate -> clone() -> add(months => -1);
    my $nextdate = $setdate -> clone() -> add(months => 1);

    $settings -> {"prev"} -> {"month"} = $prevdate -> month();
    $settings -> {"prev"} -> {"year"}  = $prevdate -> year();
    $settings -> {"next"} -> {"month"} = $nextdate -> month();
    $settings -> {"next"} -> {"year"}  = $nextdate -> year();

    # Pull filtering settings out of the session
    $settings -> {"feeds"} = [ split(/,/, $self -> {"session"} -> get_variable("articlelist_feeds")) ]
        if($self -> {"session"} -> is_variable_set("articlelist_feeds"));

    if($self -> {"session"} -> is_variable_set("articlelist_modes")) {
        $settings -> {"modes"} = [ split(/,/, $self -> {"session"} -> get_variable("articlelist_modes")) ];
        $settings -> {"usermodes"} = 1;
    } else {
        $settings -> {"modes"} = [ split(/,/, $self -> {"settings"} -> {"config"} -> {"Article::List:default_modes"}) ];
    }

    return $settings;
}


# ============================================================================
#  Content generators

## @method private $ _build_pagination($settings)
# Generate the navigation/pagination box for the message list. This will generate
# a series of boxes and controls to allow users to move between pages of message
# list. Supported settings are:
#
# - maxpage   The last page number (first is page 1).
# - pagenum   The selected page (first is page 1)
# - mode      The view mode
# - year      The year displayed articles are from (defaults to current year)
# - month     The month displayed articles are from (defaults to current month)
#
# @param settings A reference to a hash containing settings
# @return A string containing the navigation block.
sub _build_pagination {
    my $self     = shift;
    my $settings = shift;

    # If there is more than one page, generate a full set of page controls
    if($settings -> {"maxpage"} > 1) {
        my $controls = "";

        my $active = ($settings -> {"pagenum"} > 1) ? "newer.tem" : "newer_disabled.tem";
        $controls .= $self -> {"template"} -> load_template("paginate/$active", {"***prev***"  => $self -> build_url(pathinfo => [$settings -> {"year"}, $settings -> {"month"}, $settings -> {"mode"}, $settings -> {"pagenum"} - 1])});

        $active = ($settings -> {"pagenum"} < $settings -> {"maxpage"}) ? "older.tem" : "older_disabled.tem";
        $controls .= $self -> {"template"} -> load_template("paginate/$active", {"***next***" => $self -> build_url(pathinfo => [$settings -> {"year"}, $settings -> {"month"}, $settings -> {"mode"}, $settings -> {"pagenum"} + 1])});

        return $self -> {"template"} -> load_template("paginate/block.tem", {"***pagenum***" => $settings -> {"pagenum"},
                                                                             "***maxpage***" => $settings -> {"maxpage"},
                                                                             "***pages***"   => $controls});
    # If there's only one page, a simple "Page 1 of 1" will do the trick.
    } else { # if($settings -> {"maxpage"} > 1)
        return $self -> {"template"} -> load_template("paginate/block.tem", {"***pagenum***" => 1,
                                                                             "***maxpage***" => 1,
                                                                             "***pages***"   => ""});
    }
}


## @method private $ _build_article_row($article, $now)
# Generate the article list row for the specified article.
#
# @param article The article to generate the list row for.
# @param now     The current time as a unix timestamp.
# @return A string containing the article row html.
sub _build_article_row {
    my $self    = shift;
    my $article = shift;
    my $now     = shift;

    # fix up the release status for timed entries
    $article -> {"release_mode"} = "released"
        if($article -> {"release_mode"} eq "timed" && $article -> {"release_time"} <= $now);

    # build the list of notification states
    my $methods = $self -> {"queue"} -> get_methods();
    my $states = "";
    foreach my $method (sort keys(%{$methods})) {
        $states .= $methods -> {$method} -> generate_notification_state($article -> {"id"});
    }

    my ($action, $actdate, $actuser) = ("{L_ALIST_CREATED}", $self -> {"template"} -> fancy_time($article -> {"updated"}), $article -> {"realname"} || $article -> {"username"});
    if($article -> {"updated"} != $article -> {"created"}) {
        $action = "{L_ALIST_UPDATED}";
        my $user = $self -> {"session"} -> get_user_byid($article -> {"updated_id"});
        $actuser = $user -> {"realname"} || $user -> {"username"}
            if($user);
    }

    my $feeds = "";
    my $reldate;

    if($article -> {"relmode"} == 0) {
        foreach my $feed (@{$article -> {"feeds"}}) {
            $feeds .= $self -> {"template"} -> load_template("article/list/feed.tem", {"***desc***" => $feed -> {"description"}});
        }
        $reldate = $self -> {"template"} -> fancy_time($article -> {"release_time"}, 0, 1);
    } else {
        $feeds = $self -> {"template"} -> load_template("article/list/newsletter.tem", {"***schedule***" => $article -> {"section_data"} -> {"schedule"} -> {"description"},
                                                                                        "***section***"  => $article -> {"section_data"} -> {"name"}});
        $reldate = $self -> _release_time($article);
    }


    return $self -> {"template"} -> load_template("article/list/row.tem", {"***modeclass***" => $article -> {"release_mode"},
                                                                           "***modeinfo***"  => $self -> {"relmodes"} -> {$article -> {"release_mode"}},
                                                                           "***date***"      => $reldate,
                                                                           "***afterdate***" => $self -> {"template"} -> format_time($article -> {"release_time"}),
                                                                           "***feeds***"     => $feeds,
                                                                           "***title***"     => $article -> {"title"} || $self -> {"template"} -> format_time($article -> {"release_time"}),
                                                                           "***action***"    => $action,
                                                                           "***actdate***"   => $actdate,
                                                                           "***actuser***"   => $actuser,
                                                                           "***status***"    => $states,
                                                                           "***preset***"    => $article -> {"preset"},
                                                                           "***controls***"  => $self -> {"template"} -> load_template("article/list/control_".$article -> {"release_mode"}.".tem"),
                                                                           "***id***"        => $article -> {"id"},
                                                                           "***editurl***"   => $self -> build_url(block => "edit", pathinfo => [$article -> {"id"}]),
                                                  });
}


## @method private @ _generate_articlelist($pagenum)
# Generate the contents of a page listing the articles the user has permission to edit.
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_articlelist {
    my $self     = shift;
    my $year     = shift;
    my $month    = shift;
    my $pagenum  = shift || 1;

    # Pull any specified filter settings out of the query string into the session
    $self -> _validate_filter_settings();

    # Work out the settings that will be used to fetch the articles to show the user
    my $settings = $self -> _get_articlelist_settings($year, $month, $pagenum);

    # Fetch the list, which may be an empty array - if it's undef, there was an error.
    my $articles = $self -> {"article"} -> get_user_articles($self -> {"session"} -> get_session_userid(), $settings);
    if($articles) {
        my $list = "";
        my $now = time();

        # Build the list of any articles present.
        foreach my $article (@{$articles -> {"articles"}}) {
            $list .= $self -> _build_article_row($article, $now);
        }
        $list = $self -> {"template"} -> load_template("article/list/empty_month.tem")
            if(!$list);

        my $maxpage = ceil($articles -> {"metadata"} -> {"count"} / $settings -> {"count"});

        # Build the list of feeds, modes, etc for the multiselects
        my ($feeds, $selfeeds, $showremfeed) = $self -> _get_feed_selection($articles, $settings);
        my ($modes, $selmodes, $showremmode) = $self -> _get_mode_selection($articles, $settings);

        return ($self -> {"template"} -> replace_langvar("ALIST_TITLE"),
                $self -> {"template"} -> load_template("article/list/content.tem", {"***articles***"    => $list,
                                                                                    # == Date control ==
                                                                                    "***month***"       => "{L_MONTH_LONG".$settings -> {"month"}."}",
                                                                                    "***year***"        => $settings -> {"year"},

                                                                                    # == Filtering ==
                                                                                    "***modes***"       => $self -> generate_multiselect("modes", "mode", "mode", $modes, $selmodes),
                                                                                    "***remove-mode***" => $showremmode ? $self -> {"template"} -> load_template("article/list/remove-mode.tem") : "",
                                                                                    "***feeds***"       => $self -> generate_multiselect("feeds", "feed", "feed", $feeds, $selfeeds),
                                                                                    "***remove-feed***" => $showremfeed ? $self -> {"template"} -> load_template("article/list/remove-feed.tem") : "",

                                                                                    # == Navigation & pagination ==
                                                                                    "***prevurl***"     => $self -> build_url(pathinfo => [$settings -> {"prev"} -> {"year"}, $settings -> {"prev"} -> {"month"}]),
                                                                                    "***nexturl***"     => $self -> build_url(pathinfo => [$settings -> {"next"} -> {"year"}, $settings -> {"next"} -> {"month"}]),
                                                                                    "***paginate***"    => $self -> _build_pagination({ maxpage => $maxpage,
                                                                                                                                        pagenum => $settings -> {"pagenum"},
                                                                                                                                        mode    => "page",
                                                                                                                                        year    => $settings -> {"year"},
                                                                                                                                        month   => $settings -> {"month"}
                                                                                                                                      })
                                                       })
               );
    } else {
        return $self -> build_error_box($self -> {"article"} -> errstr());
    }
}


# ============================================================================
#  API functions


# @param newmode The new mode to set for the article
sub _build_api_setmode_response {
    my $self    = shift;
    my $newmode = shift;
    my $setdate = shift;
    my $userid  = $self -> {"session"} -> get_session_userid();

    # Pull the article ID from the api data
    my @api  = $self -> {"cgi"} -> param('api');
    my $articleid = $api[2]
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_NOAID}"}));

    # Check that the article id is numeric
    ($articleid) = $articleid =~ /^(\d+)$/;
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_API_ERROR_BADAID}"}))
        if(!$articleid);

    $self -> log($newmode, "User setting article $articleid mode to $newmode");

    my $article = $self -> {"article"} -> get_article($articleid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));

    # check that the user has edit permission
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => "{L_PERMISSION_EDIT_DESC}"}))
        unless($self -> check_permission("edit", $article -> {"metadata_id"}, $userid));

    # Handle the situation where updating the mode will make the item visible,
    # but its release time is in the future (ie: it needs to be timed)
    $newmode = "timed"
        if($newmode eq "visible" && $article -> {"release_time"} > time() && !$setdate);

    # Only attempt to change the status if needed
    if($article -> {"release_mode"} ne $newmode) {
        # Do the update, and spit out the row html if successful
        $article = $self -> {"article"} -> set_article_status($articleid, $newmode, $userid, $setdate)
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));

        # abort edited/deleted article notifications
        if($newmode eq "deleted" || $newmode eq "edited") {
            $self -> {"queue"} -> cancel_notifications($articleid)
                or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"queue"} -> errstr()}));
        }

    } else {
        $self -> log($newmode, "Article $articleid is already marked as $newmode");
    }

    return $self -> _build_article_row($article);
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

    # Exit with a permission error unless the user has permission to list articles
    # Note that this should never actually happen - all users should have compose
    # permission of some kind - but this is here to make really sure of that.
    if(!$self -> check_permission("listarticles")) {
        $self -> log("error:article:permission", "User does not have permission to list articles");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_LISTARTICLE_DESC}",
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
            when("delete")   { return $self -> api_html_response($self -> _build_api_setmode_response("deleted")); }
            when("undelete") { return $self -> api_html_response($self -> _build_api_setmode_response("visible")); }
            when("hide")     { return $self -> api_html_response($self -> _build_api_setmode_response("hidden")); }
            when("unhide")   { return $self -> api_html_response($self -> _build_api_setmode_response("visible")); }
            when("publish")  { return $self -> api_html_response($self -> _build_api_setmode_response("visible", 1)); }
            default {
                return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                         $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my @pathinfo = $self -> {"cgi"} -> param('pathinfo');

        given($pathinfo[2]) {
            when("page") { ($title, $content) = $self -> _generate_articlelist($pathinfo[0], $pathinfo[1], $pathinfo[3]); }
            default {
                ($title, $content) = $self -> _generate_articlelist($pathinfo[0], $pathinfo[1], 1);
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("article/list/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "list");
    }
}

1;
