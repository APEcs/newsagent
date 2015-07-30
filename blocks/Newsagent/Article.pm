## @file
# This file contains the implementation of the article base class.
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
package Newsagent::Article;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Feed;
use Newsagent::System::Schedule;
use Newsagent::System::Article;
use Newsagent::System::NotificationQueue;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Article, loads the System::Article model
# and other classes required to generate article pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Article object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new("timefmt" => '%a, %d %b %Y %H:%M:%S %z',
                                        @_)
        or return undef;

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

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
                                                             metadata => $self -> {"system"} -> {"metadata"},
                                                             magic    => $self -> {"system"} -> {"magic"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"queue"} = Newsagent::System::NotificationQueue -> new(dbh      => $self -> {"dbh"},
                                                                     settings => $self -> {"settings"},
                                                                     logger   => $self -> {"logger"},
                                                                     article  => $self -> {"article"},
                                                                     module   => $self -> {"module"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"schedrelops"} = [ {"value" => "next",
                                  "name"  => "{L_COMPOSE_RELNEXT}" },
                                 {"value" => "after",
                                  "name"  => "{L_COMPOSE_RELAFTER}" },
                                 {"value" => "nldraft",
                                  "name"  => "{L_COMPOSE_RELNONE}" },
                               ];

    $self -> {"relops"} = [ {"value" => "visible",
                             "name"  => "{L_COMPOSE_RELNOW}" },
                            {"value" => "timed",
                             "name"  => "{L_COMPOSE_RELTIME}" },
                            {"value" => "draft",
                             "name"  => "{L_COMPOSE_RELNONE}" },
                            {"value" => "preset",
                             "name"  => "{L_COMPOSE_RELPRESET}" },
        ];

    $self -> {"stickyops"} = [ {"value" => "0",
                                "name"  => "{L_COMPOSE_NOTSTICKY}" },
                               {"value" => "1",
                                "name"  => "{L_COMPOSE_STICKYDAYS1}" },
                               {"value" => "2",
                                "name"  => "{L_COMPOSE_STICKYDAYS2}" },
                               {"value" => "3",
                                "name"  => "{L_COMPOSE_STICKYDAYS3}" },
                               {"value" => "4",
                                "name"  => "{L_COMPOSE_STICKYDAYS4}" },
                               {"value" => "5",
                                "name"  => "{L_COMPOSE_STICKYDAYS5}" },
                               {"value" => "6",
                                "name"  => "{L_COMPOSE_STICKYDAYS6}" },
                               {"value" => "7",
                                "name"  => "{L_COMPOSE_STICKYDAYS7}" },
                          ];

    $self -> {"relmodes"} = { "hidden"   => "{L_ALIST_RELHIDDEN}",
                              "visible"  => "{L_ALIST_RELNOW}",
                              "timed"    => "{L_ALIST_RELTIME_WAIT}",
                              "released" => "{L_ALIST_RELTIME_PASSED}",
                              "draft"    => "{L_ALIST_RELNONE}",
                              "edited"   => "{L_ALIST_RELEDIT}",
                              "deleted"  => "{L_ALIST_RELDELETED}",
                              "preset"   => "{L_ALIST_RELTEMPLATE}",
                              "next"     => "{L_ALIST_RELNEWSNEXT}",
                              "after"    => "{L_ALIST_RELNEWSAFTER}",
                              "used"     => "{L_ALIST_RELNEWSUSED}",
                            };

    $self -> {"filtermodes"} = [{"name"  => "hidden",
                                 "desc"  => "{L_ALIST_FILTER_RELHIDDEN}"},
                                {"name"  => "visible",
                                 "desc"  => "{L_ALIST_FILTER_RELNOW}"},
                                {"name"  => "timed",
                                 "desc"  => "{L_ALIST_FILTER_RELTIME_WAIT}"},
                                {"name"  => "next",
                                 "desc"  => "{L_ALIST_FILTER_RELNEWSNEXT}"},
                                {"name"  => "after",
                                 "desc"  => "{L_ALIST_FILTER_RELNEWSAFTER}"},
                                {"name"  => "used",
                                 "desc"  => "{L_ALIST_FILTER_RELNEWSUSED}"},
                                {"name"  => "draft" ,
                                 "desc"  => "{L_ALIST_FILTER_RELNONE}"},
                                {"name"  => "edited",
                                 "desc"  => "{L_ALIST_FILTER_RELEDIT}"},
                                {"name"  => "preset",
                                 "desc"  => "{L_ALIST_FILTER_RELTEMPLATES}"},
                               ];

    $self -> {"imgops"} = [ {"value" => "none",
                             "name"  => "{L_COMPOSE_IMGNONE}" },
                            {"value" => "url",
                             "name"  => "{L_COMPOSE_IMGURL}" },
                            {"value" => "img",
                             "name"  => "{L_COMPOSE_IMG}" },
                          ];

    # Which states allow editing?
    $self -> {"cloneonly"} = { "hidden" => 1,
                               "used"   => 1 };

    $self -> {"allow_tags"} = [
        "a", "b", "blockquote", "br", "caption", "col", "colgroup", "comment",
        "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "ol", "p",
        "pre", "small", "span", "strong", "sub", "sup", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "tt", "ul",
        ];

    $self -> {"tag_rules"} = [
        a => {
            href   => qr{^(?:http|https)://}i,
            name   => 1,
            '*'    => 0,
        },
        table => {
            cellspacing => 1,
            cellpadding => 1,
            style       => 1,
            class       => 1,
            border      => 1,
            '*'         => 0,
        },
        td => {
            colspan => 1,
            rowspan => 1,
            style   => 1,
            '*'     => 0,
        },
        blockquote => {
            cite  => qr{^(?:http|https)://}i,
            style => 1,
            '*'   => 0,
        },
        span => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        div => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        p => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        img => {
            src    => 1,
            class  => 1,
            alt    => 1,
            width  => 1,
            height => 1,
            style  => 1,
            title  => 1,
            '*'    => 0,
        },
        ];

    return $self;
}


# ============================================================================
#  Validation code

## @method protected $ _validate_article_image($args, $imgid)
# Validate the image field for an article. This checks the values set for one
# of the possible images attached to an article.
#
# @param args  A reference to a hash to store validated data in.
# @param imgid The id of the image fields to check, should be 'a' or 'b'
# @return empty string on succss, otherwise an error string.
sub _validate_article_image {
    my $self  = shift;
    my $args  = shift;
    my $imgid = shift;
    my ($errors, $error) = ("", "");

    my $base = "image$imgid";

    ($args -> {"images"} -> {$imgid} -> {"mode"}, $error) = $self -> validate_options($base."_mode", {"required" => 1,
                                                                                                      "source"   => $self -> {"imgops"},
                                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_".uc($base))});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    given($args -> {"images"} -> {$imgid} -> {"mode"}) {
        # No additional validation needed for the 'none' case, but enumate it for clarity.
        when("none") {
        }

        # URL validation involves checking that the string the user has provided actually looks like a URL
        when("url") { ($args -> {"images"} -> {$imgid} -> {"url"}, $error) = $self -> validate_string($base."_url", {"required"   => 1,
                                                                                                                     "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL"),
                                                                                                                     "formattest" => $self -> {"formats"} -> {"url"},
                                                                                                                     "formatdesc" => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL_DESC"),
                                                                                   });
                      $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }

        # Image validation ("use an existing image") is basically checking that an entry with the corresponding ID is in the database.
        when("img") { ($args -> {"images"} -> {$imgid} -> {"img"}, $error) = $self -> validate_options($base."_imgid", {"required"   => 1,
                                                                                                                        "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMG"),
                                                                                                                        "source"     => $self -> {"settings"} -> {"database"} -> {"images"},
                                                                                                                        "where"      => "WHERE `id` = ?"});
                      $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }
    }

    return $errors;
}


## @method protected $ _validate_article_files($args)
# Validate the files field for an article. This checks the values set for
# the files attached to the article.
#
# @param args  A reference to a hash to store validated data in.
# @return empty string on succss, otherwise an error string.
sub _validate_article_files {
    my $self = shift;
    my $args = shift;

    my ($files, $error) = $self -> validate_string("files", {"required"   => 0,
                                                             "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_FILES"),
                                                             "formattest" => '^\d+(,\d+)*$',
                                                             "formatdesc" => $self -> {"template"} -> replace_langvar("COMPOSE_FORMAT")
                                                   });
    return $error if($error);

    if($files) {
        my @fileids = split(/,/, $files);

        # check that the file IDs are valid...
        my $count = 0;
        foreach my $id (@fileids) {
            my $file = $self -> {"article"} -> {"files"} -> get_file_info($id, $count);
            return $self -> {"article"} -> {"files"} -> errstr() if(!$file); # Bail on errors
            next if(!$file -> {"id"}); # Skip unknown files (Should this bail too? Possibly!)

            push(@{$args -> {"files"}}, $file);
            ++$count;
        }
    }

    return "";
}


## @method protected $ _validate_feeds_levels($args, $userid)
# Validate the selected feeds and posting levels submitted by the user.
#
# @param args   A reference to a hash to store validated data in. This will populate two
#               entries in the hash: `levels` is a reference to a hash, one element per
#               selected level, with the value set to the number of times the level was
#               selected; `feeds` contains a reference to a list of feed IDs selected.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_feeds_levels {
    my $self    = shift;
    my $args    = shift;
    my $userid  = shift;
    my $userset = {};

    # Get the levels, feeds, and which levels the user has access to on each feed
    my $sys_levels  = $self -> {"article"} -> get_all_levels();
    my $user_feeds  = $self -> {"feed"} -> get_user_feeds($userid, $sys_levels);
    my $user_levels = $self -> {"article"} -> get_user_levels($user_feeds, $sys_levels, $userid);

    # Fetch the list of selected feeds and levels
    my @set_feeds  = $self -> {"cgi"} -> param("feed");  # A list of selected feed IDs
    my @set_levels = $self -> {"cgi"} -> param("level"); # A list of selected level names ("home", "leader", etc)

    # Convert the arrays to a hash for faster/easier lookup
    my %feed_hash  = map { $_ => $_ } @set_feeds;
    my %level_hash = map { $_ => $_ } @set_levels;

    # First go through the feeds the user has turned on, and build a hash of levels
    # that represent the *minimum* available set of permissions
    my %avail_levels = map { $_ -> {"value"} => 1 } @{$sys_levels};
    foreach my $user_feed (@{$user_feeds}) {

        # Has the user enabled this feed?
        if($feed_hash{$user_feed -> {"id"}}) {

            # Yes, deactivate any levels the user does not have access to for this feed
            foreach my $level (keys(%avail_levels)) {
                $avail_levels{$level} = 0
                    unless($user_levels -> {$user_feed -> {"id"}} -> {$level});
            }
        }
    }

    # At this point $avail_levels contains 0 or 1 for each level defined in the system:
    # - if the user can post to ALL selected feed at a given level, $avail_levels contains 1 for that level
    # - if the user has selected ANY feed that they can not post to at a given level, $avail_levels contains 0 for that level.
    # Essentially, $avail_levels is the intersection of available levels for the user for the selected feeds.

    # How many levels are left? Is the user able to post the article at all?
    my $count = 0;
    foreach my $level (keys %avail_levels) {
        $count += $avail_levels{$level};
    }
    # If there are no levels left, exit with an error
    return $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL_ERRNOCOMMON") unless($count);

    # Now check the levels the user has selected against the available levels
    $args -> {"levels"} = {};
    foreach my $level (keys %avail_levels) {
        # Skip levels that are not enabled, or selected by the user
        next if(!$avail_levels{$level} || !$level_hash{$level});

        $args -> {"levels"} -> {$level}++
    }

    # If the user has not selected any levels, or the selected ones have been rejected, error out.
    return $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL_ERRNONE") if(!scalar(keys(%{$args -> {"levels"}})));

    # Go through the available feeds for the user, and if the user has enabled the feed
    # make sure thay they can post the selected levels to that feed
    $args -> {"feeds"}  = [];
    foreach my $user_feed (@{$user_feeds}) {

        # Has the user enabled this feed?
        if($feed_hash{$user_feed -> {"id"}}) {

            # Yes, store the feed ID. Note that this is safe at this point as the above code has already
            # checked that the user has permission to post to this feed at a selected level.
            push(@{$args -> {"feeds"}}, $user_feed -> {"id"});
        }
    }

    # No levels selected?
    return scalar(@{$args -> {"feeds"}}) ? undef : $self -> {"template"} -> replace_langvar("COMPOSE_FEED_ERRNONE");
}


## @method protected $ _validate_summary_text($args)
# Determine whether the summary and article texts are valid.
#
# @param args A reference to a hash to store validated data in.
# @return empty string on success, otherwise an error string.
sub _validate_summary_text {
    my $self = shift;
    my $args = shift;

    my $nohtml = $args -> {"article"} ? $self -> {"template"} -> html_strip($args -> {"article"}) : "";

    # Got both summary and article text? Nothing to do, then...
    if($args -> {"summary"} && $nohtml) {
        return undef;

    # If there's a summary, and no article text, copy the summary over
    } elsif($args -> {"summary"} && !$nohtml) {
        $args -> {"article"} = "<p>".$args -> {"summary"}."</p>";
        return undef;

    # If there's an article text, but no summary, what happens depends on the mode
    } elsif(!$args -> {"summary"} && $nohtml) {
        # In normal release, copy the first chunk of the article into the summary
        if($args -> {"relmode"} == 0) {
            $args -> {"summary"} = $self -> truncate_text($nohtml, 240);
            return undef;

        # In newsletter mode, just make sure the summary is empty
        } elsif($args -> {"relmode"} == 1) {
            $args -> {"summary"} = '';
            return undef;
        }
    }

    # Last possible case: no summary or article text - complain about it.
    return "{L_COMPOSE_ERR_NOSUMMARYARTICLE}";
}


## @method protected _validate_standard_release($args, $userid)
# Check whether the values specified for the standard release options are
# valid, and record them if they are.
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_standard_release {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;
    my ($errors, $error) = ("", "");

    # Get the list of feeds the user has selected and has access to
    $error = $self -> _validate_feeds_levels($args, $userid);
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"release_mode"}, $error) = $self -> validate_options("mode", {"required" => 1,
                                                                             "default"  => "visible",
                                                                             "source"   => $self -> {"relops"},
                                                                             "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELEASE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    if($args -> {"release_mode"} eq "timed") {
        ($args -> {"release_time"}, $error) = $self -> validate_numeric("rtimestamp", {"required" => $args -> {"release_mode"} eq "timed",
                                                                                       "default"  => 0,
                                                                                       "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELDATE")});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
    } elsif($args -> {"release_mode"} eq "preset") {
        ($args -> {"preset"}, $error) = $self -> validate_string("preset", {"required" => 1,
                                                                            "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_PRESETNAME"),
                                                                            "minlen"   => 8,
                                                                            "maxlen"   => 80});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
    }

    ($args -> {"sticky"}, $error) = $self -> validate_options("sticky", {"required" => 0,
                                                                         "source"   => $self -> {"stickyops"},
                                                                         "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_STICKY")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    $args -> {"full_summary"} = (defined($self -> {"cgi"} -> param("full_summary")) && $self -> {"cgi"} -> param("full_summary")) ? 1 : 0;

    return $errors;
}


## @method protected _validate_schedule_release($args, $userid)
# Check whether the values specified for the schedule release options are
# valid, and record them if they are.
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_schedule_release {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;
    my ($errors, $error) = ("", "");

    my $schedules = $self -> {"schedule"} -> get_user_schedule_sections($userid);
    return $self -> {"template"} -> replace_langvar("COMPOSE_SCHEDULE_NONE")
        if(!$schedules || !scalar(keys(%{$schedules})));

    # Schedule will be the schedule name
    ($args -> {"schedule"}, $error) = $self -> validate_options("schedule", {"required" => 1,
                                                                             "source"   => $schedules -> {"_schedules"},
                                                                             "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SCHEDULE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # Can only validate, or even check, the section if the schedule is valid
    if($args -> {"schedule"}) {
        my $schedule = $self -> {"schedule"} -> get_schedule_byname($args -> {"schedule"});
        if($schedule) {
            $args -> {"schedule_id"} = $schedule -> {"id"};
        } else {
            $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => "{L_COMPOSE_ERR_BADSCHEDULE}"});
        }

        # Section is the section ID number
        ($args -> {"section"}, $error) = $self -> validate_options("section", {"required" => 1,
                                                                               "source"   => $schedules -> {"id_".$args -> {"schedule_id"}} -> {"sections"},
                                                                               "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SECTION")});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
    }

    ($args -> {"release_mode"}, $error) = $self -> validate_options("schedule_mode", {"required" => 1,
                                                                                      "source"   => $self -> {"schedrelops"},
                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELEASE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    if($args -> {"release_mode"} eq "after") {
        ($args -> {"release_time"}, $error) = $self -> validate_numeric("stimestamp", {"required" => $args -> {"release_mode"} eq "after",
                                                                                       "default"  => 0,
                                                                                       "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELAFTER")});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
    }

    # Generally this will only be set during editing
    ($args -> {"sort_order"}, $error) = $self -> validate_numeric("sort_order", {"required" => 0,
                                                                                 "default"  => 0,
                                                                                 "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SORTORDER")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);


    return $errors;
}


## @method protected $ _validate_article_fields($args, $userid)
# Validate the contents of the fields in the article form. This will validate the
# fields, and perform any background file-wrangling operations necessary to deal
# with the submitted images (if any).
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_article_fields {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;
    my ($errors, $error) = ("", "");

    # Which release mode is the user using? 0 is default, 1 is batch
    ($args -> {"relmode"}, $error) = $self -> validate_numeric("relmode", {"required" => 1,
                                                                           "default"  => 0,
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELMODE"),
                                                                           "min"      => 0,
                                                                           "max"      => 1});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"title"}, $error) = $self -> validate_string("title", {"required" => 0,
                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_TITLE"),
                                                                      "maxlen"   => 100});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"summary"}, $error) = $self -> validate_string("summary", {"required" => 0,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SUMMARY"),
                                                                          "minlen"   => 8,
                                                                          "maxlen"   => 240});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    push(@{$self -> {"allow_tags"}}, "img")
        if($self -> check_permission("freeimg"));

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("article", {"required"   => 0,
                                                                            "minlen"     => 8,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_DESC"),
                                                                            "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                            "allow_tags" => $self -> {"allow_tags"},
                                                                            "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # sort out the summary/full text
    $error = $self -> _validate_summary_text($args);
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);


    $args -> {"minor_edit"} = $self -> {"cgi"} -> param("minor_edit") ? 1 : 0;

    my $sys_levels = $self -> {"article"} -> get_all_levels();

    # Release mode 0 is "standard" release - potentially with timed delay.
    if($args -> {"relmode"} == 0) {
        $errors .= $self -> _validate_standard_release($args, $userid);

    # Release mode 1 is "schedule/newsletter" release.
    } elsif($args -> {"relmode"} == 1) {
        $errors .= $self -> _validate_schedule_release($args, $userid);
    }

    # Handle confirmation suppression
    $args -> {"noconfirm"} = 1
        if($self -> {"cgi"} -> param('stopconfirm'));

    # Is this a clone?
    $args -> {"clone"} = 1
        if(defined($self -> {"cgi"} -> param("clone")) && $self -> {"cgi"} -> param("clone"));

    # Handle images
    $errors .= $self -> _validate_article_image($args, "a");
    $errors .= $self -> _validate_article_image($args, "b");

    # And files
    $errors .= $self -> _validate_article_files($args);

    return $errors;
}


## @method protected $ _validate_article($articleid)
# Validate the article data submitted by the user, and potentially add
# a new article to the system. Note that this will not return if the article
# fields validate; it will redirect the user to the new article and exit.
#
# @param articleid Optional article ID used when doing edits. Note that the
#                  caller must ensure this ID is valid and the user can edit it.
# @return An error message, and a reference to a hash containing
#         the fields that passed validation.
sub _validate_article {
    my $self      = shift;
    my $articleid = shift;
    my ($args, $errors, $error) = ({}, "", "", undef);
    my $userid = $self -> {"session"} -> get_session_userid();

    my $failmode = $articleid ? "{L_EDIT_FAILED}" : "{L_COMPOSE_FAILED}";

    $error = $self -> _validate_article_fields($args, $userid);
    $errors .= $error if($error);

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix", "queue" => $self -> {"queue"});

    # Only bother checking notification code if the release mode is "standard". "Batch" handles its
    # notification code separately.
    $errors .= $matrix -> validate_matrix($args, $userid)
        if($args -> {"relmode"} == 0);

    # Give up here if there are any errors
    return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                            "***errors***"  => $errors}), $args)
        if($errors);

    # If an articleid has been specified, this is an edit - update the status of the previous article if it's not a clone
    my $updateid;
    if($articleid) {
        # At this point, the articleid is not needed when cloning
        if($args -> {"clone"}) {
            $articleid = undef;
        } else {
            my $article = $self -> {"article"} -> get_article($articleid)
                or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                     {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                                     })
                                                                  }), $args);

            # Do not update the preset status, unless the new and old preset names match
            if($article -> {"release_mode"} ne "preset" ||
               ($article -> {"preset"} && $args -> {"preset"} && lc($article -> {"preset"}) eq lc($args -> {"preset"}))) {
                $self -> {"article"} -> set_article_status($articleid, "edited", $userid, $article -> {"release_mode"} eq "timed")
                    or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                               "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                         {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                                     })
                                                                      }), $args);
            }

            # Do not bother cancelling notifications for draft or preset
            if($article -> {"release_mode"} ne "draft" && $article -> {"release_mode"} ne "preset") {
            $self -> {"queue"} -> cancel_notifications($articleid)
                or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                     {"***error***" => $self -> {"queue"} -> errstr()
                                                                                                                                                     })
                                                                  }), $args);
            }

            if($args -> {"minor_edit"}) {
                $args -> {"release_time"} = $article -> {"release_time"};
            }

            # Move the old article to a new ID, so the edit can replace the old one.
            $updateid = $self -> {"article"} -> renumber_article($articleid)
                or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                     {"***error***" => $self -> {"queue"} -> errstr()
                                                                                                                                                     })
                                                              }), $args);
        }
    }

    my $aid = $self -> {"article"} -> add_article($args, $userid, $updateid, $args -> {"relmode"}, $articleid)
        or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                   "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                             {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                             })
                                                          }), $args);

    $self -> log("article", "Added article $aid");

    # Only bother checking notification code if the release mode is "standard". "Batch" handles its
    # notification code separately.
    if($args -> {"relmode"} == 0) {
        $errors = $matrix -> queue_notifications($aid, $args, $userid, $failmode);
        return $errors if($errors);
    }

    # If the user has stopped confirmations, set the flag here
    $self -> {"session"} -> {"auth"} -> {"app"} -> set_user_setting($userid, "disable_confirm", 1)
        if($args -> {"noconfirm"});

    # redirect to a success page
    # Doing this prevents page reloads adding multiple article copies!
    print $self -> {"cgi"} -> redirect($self -> build_url(pathinfo => ["success"]));
    exit;
}


# ============================================================================
#  Form generators

## @method protected $ _build_image_options($imgopt, $mode)
# Generate a string containing the options to provide for image selection.
#
# @param imgopt The image data to work on.
# @param mode   The image mode, should be one of 'icon' or 'media'
# @return A string containing the image mode options, and a string containing
#         the contents of the medialib button.
sub _build_image_options {
    my $self   = shift;
    my $imgopt = shift;
    my $mode   = shift;

    # Force a sane mode
    $imgopt -> {"mode"} = "none"
        unless($imgopt -> {"mode"} && ($imgopt -> {"mode"} eq "url" || $imgopt -> {"mode"} eq "img"));

    my $button = $self -> {"template"} -> replace_langvar("COMPOSE_MEDIALIB");
    if($imgopt -> {"mode"} eq "img") {
        my $imgdata = $self -> {"article"} -> {"images"} -> get_image_info($imgopt -> {"img"});
        $button = '<img src="'.$imgdata -> {"path"} -> {$mode}.'" />'
            if($imgdata && $imgdata -> {"id"});
    }

    return ($self -> {"template"} -> build_optionlist($self -> {"imgops"}, $imgopt -> {"mode"}), $button);
}


## @method protected $ _build_image_options($levels, $setlevels)
# Generate the level options available in the system.
#
# @param levels    A reference to a hash of available levels.
# @param setlevels A reference to a hash of levels selected.
# @return A string containing the level options
sub _build_level_options {
    my $self      = shift;
    my $levels    = shift || {};
    my $setlevels = shift || {};
    my $options   = "";

    foreach my $level (@{$levels}) {
        my $checked = $setlevels -> {$level -> {"value"}} ? " checked=\"checked\"": "";

        $options .= $self -> {"template"} -> load_template("article/compose/levelop.tem", {"***desc***"    => $level -> {"name"},
                                                                                           "***value***"   => $level -> {"value"},
                                                                                           "***checked***" => $checked,
                                                           });
    }

    return $options;
}


## @method protected $ _build_feedlist($feeds, $selected)
# Generate a series of checkboxes for each feed specified in the provided array
#
# @param feeds    A reference to an array of feed data hashrefs
# @param selected A reference to a hash of selected feeds
# @return A string containing the checkboxes for the available feeds.
sub _build_feedlist {
    my $self     = shift;
    my $feeds    = shift;
    my $selected = shift;
    my $realselect = [];

    # During the edit process the selected list may be a list of feed data hashes, this
    # can't be used directly and must be converted to a list of IDs
    if(ref($selected -> [0]) eq "HASH") {
        foreach my $sel (@{$selected}) {
            push(@{$realselect}, $sel -> {"id"});
        }

    # during compose, and edit validation, selected will be a list of feed ids.
    } else {
        $realselect = $selected;
    }

    return $self -> generate_multiselect("feed", "feed", "feed", $feeds, $realselect);
}


## @method protected $ _build_feed_levels($user_levels, $levels)
# Generate a block of javascript that can be used to control the levels available to
# users for each feed they have access to.
#
# @param user_levels A hash generated by get_user_levels() that controls which levels
#                    the user can post at for each feed.
# @param levels      A hash containing the currently selected levels for the current
#                    feed
# @return A string containing the javascript to embed in the page
sub _build_feed_levels {
    my $self        = shift;
    my $user_levels = shift;
    my $levels      = shift;
    my $incantation = "feed_levels = {\n";

    foreach my $feed (keys(%{$user_levels})) {
        $incantation .= "    \"$feed\": { ";
        foreach my $level (keys(%{$user_levels -> {$feed}})) {
            $incantation .= "\"$level\": ".$user_levels -> {$feed} -> {$level}.", ";
        }
        $incantation .= "},\n";
    }

    return $incantation."};\n";
}


## @method protected $ _build_levels_jsdata($levels)
# Given an array of level descriptions hashrefs, create an array of level names that
# the level autoselector javascript can use.
#
# @param levels A reference to an array of level hashrefs.
# @return A string to use in the page as the level array.
sub _build_levels_jsdata {
    my $self   = shift;
    my $levels = shift;
    my @names;

    foreach my $level (@{$levels}) {
        push(@names, '"'.$level -> {"value"}.'"');
    }

    my $array = "level_list = new Array(".join(",", @names).");";
}


## @method protected @ _build_files_block($files)
# Build the content to show in the file upload block in the compose and edit forms.
#
# @param $files A reference to an array of file hashes.
# @return A string to use as the file list, and a file upload/no upload block.
sub _build_files_block {
    my $self  = shift;
    my $files = shift;

    my $filelist = "";
    if($files && scalar(@{$files})) {
        foreach my $file (@{$files}) {
            my $url = $self -> {"article"} -> {"files"} -> get_file_url($file);

            $filelist .= $self -> {"template"} -> load_template("fileupload/file_row.tem", {"***id***"       => $file -> {"id"},
                                                                                            "***url***"      => $url,
                                                                                            "***filename***" => $file -> {"name"},
                                                                                            "***size***"     => $self -> {"template"} -> bytes_to_human($file -> {"size"})
                                                                });
        }
    }

    my $tem = $self -> check_permission("file.upload") ? "upload.tem" : "noupload.tem";
    my $upload = $self -> {"template"} -> load_template("fileupload/$tem");

    return ($filelist, $upload);
}

1;
