## @file
# This file contains the implementation of the article editing facility.
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
package Newsagent::Article::Edit;

use strict;
use base qw(Newsagent::Article); # This class extends the Newsagent block class
use v5.12;
use Data::Dumper;
# ============================================================================
#  Support functions

## @method private $ _fixup_levels($setlevels)
# Convert an array of set importance levels to a hash suitable for passing to
# _build_level_options(). This convers an array of level record hashrefs into
# something that the _build_level_options() function can understand in order
# to prepopulate the edit form correctly.
#
# @param setlevels A reference to an array of hashrefs of selected posting levels.
# @return A reference to a hash describing the selected levels.
sub _fixup_levels {
    my $self      = shift;
    my $setlevels = shift;
    my $levels = {};

    foreach my $level (@{$setlevels}) {
        $levels -> {$level -> {"level"}}++;
    }

    return $levels;
}


## @method private $ _fixup_images($setimages)
# Convert an array of set selected images to a hash suitable for passing to
# use in _generate_edit(). This converts an array of image hashrefs into
# something that the _generate_edit() function can understand in order
# to prepopulate the edit form correctly.
#
# @param setimages A reference to an array of image hashrefs.
# @return A reference to a hash describing the selected images.
sub _fixup_images {
    my $self      = shift;
    my $setimages = shift;
    my $images = {};
    my $imgids = ["a", "b"];

    foreach my $image (@{$setimages}) {
        given($image -> {"type"}) {
            when("url" ) {  $images -> {$imgids -> [$image -> {"order"}]} -> {"mode"} = "url";
                            $images -> {$imgids -> [$image -> {"order"}]} -> {"url"} = $image -> {"location"};
            }
            when("file") {  $images -> {$imgids -> [$image -> {"order"}]} -> {"mode"} = "img";
                            $images -> {$imgids -> [$image -> {"order"}]} -> {"img"} = $image -> {"id"};
            }
        }
    }

    return $images;
}


## @method private void _fixup_sticky($article)
# Convert the "is_sticky" and "sticky_until" fields in the article into a
# single 'sticky' field that can be used to control the stickiness. Note
# that the time the article will remain sticky for is based on the amount of
# time the article has remaining as sticky, rather than the time it was
# set on originally.
#
# @param article A reference to a hash containing the article data
sub _fixup_sticky {
    my $self    = shift;
    my $article = shift;

    # Default is not to be sticky...
    $article -> {"sticky"} = 0;

    if($article -> {"is_sticky"}) {
        my $now    = time();
        my $remain = 0;

        # if the article is visible, the sticky time remaining is based on
        # the current time
        if($article -> {"release_mode"} eq "visible" ||
           ($article -> {"release_mode"} eq "timed" && $article -> {"release_time"} <= $now)) {

            # Work out how many days of stickiness remain for the article. Note the + 1 here
            # is needed because the integer conversion will round down.
            $article -> {"sticky"} = int(($article -> {"sticky_until"} - $now) / 86400) + 1;;
        } else {
            # Article hasn't been released yet, so use its original sticky time
            $article -> {"sticky"} = int(($article -> {"sticky_until"} - $article -> {"release_time"}) / 86400);
        }
    }
}


## @method private $ _check_articleid($articleid)
# Determine whether the specified article ID is valid, and whether the user
# has access to edit it. If both are true, this returns a reference to the
# article.
#
# @note The data returned by this function does not include the notification
#       information. That must be fetched separately by calling the
#       Newsagent::Notification::Matrix::get_article_settings() function.
#
# @param articleid The ID of the article to fetch the data for
# @return A reference to a hash containing the article data.
sub _check_articleid {
    my $self      = shift;
    my $articleid = shift;

    # Check that the article ID is valid
    unless($articleid && $articleid =~ /^\d+$/) {
        return ("{L_EDIT_ERROR_TITLE}", $self -> {"template"} -> message_box("{L_EDIT_ERROR_TITLE}",
                                                                             "error",
                                                                             "{L_EDIT_ERROR_NOID_SUMMARY}",
                                                                             "{L_EDIT_ERROR_NOID_DESC}",
                                                                             undef,
                                                                             "messagecore",
                                                                             [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                                                "colour"  => "blue",
                                                                                "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]));
    }

    my $article = $self -> {"article"} -> get_article($articleid)
        or return ("{L_EDIT_ERROR_TITLE}", $self -> {"template"} -> message_box("{L_EDIT_ERROR_TITLE}",
                                                                                "error",
                                                                                "{L_EDIT_ERROR_BADID_SUMMARY}",
                                                                                $self -> {"article"} -> errstr(),
                                                                                undef,
                                                                                "messagecore",
                                                                                [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                                                   "colour"  => "blue",
                                                                                   "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]));

    # Does the user have edit permission?
    unless($self -> check_permission("edit", $article -> {"metadata_id"})) {
        return("{L_PERMISSION_FAILED_TITLE}", $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                                                   "error",
                                                                                   "{L_PERMISSION_FAILED_SUMMARY}",
                                                                                   "{L_PERMISSION_EDIT_DESC}",
                                                                                   undef,
                                                                                   "messagecore",
                                                                                   [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                                                      "colour"  => "blue",
                                                                                      "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]));
    }

    return $article;
}


# ============================================================================
#  Content generators

## @method private @ _generate_edit($articleid, $args, $error)
# Generate the page content for an edit page.
#
# @param articleid The ID of the article to edit.
# @param args      An optional reference to a hash containing defaults for the form fields.
# @param error     An optional error message to display above the form if needed.
# @return Two strings, the first containing the page title, the second containing the
#         page content.
sub _generate_edit {
    my $self      = shift;
    my $articleid = shift;
    my $args      = shift || { };
    my $error     = shift;

    my $userid = $self -> {"session"} -> get_session_userid();

    my ($article, $message) = $self -> _check_articleid($articleid);
    return ($article, $message) unless(ref($article) eq "HASH");

    # Convert the levels and image data in the article into something easier to use
    $article -> {"levels"} = $self -> _fixup_levels($article -> {"levels"});
    $article -> {"images"} = $self -> _fixup_images($article -> {"images"});

    # Convert the sticky data into something the dropdown can use
    $self -> _fixup_sticky($article);

    # If the article is a preset, and the 'usetem' flag is set, change the release mode to immediate
    if($article -> {"preset"} && defined($self -> {"cgi"} -> param('usetem'))) {
        $article -> {"preset"} = '';
        $article -> {"release_mode"} = 'visible';
        $args -> {"template"} = 1;

    # having clone set when creating from a template makes no sense, so only allow it when usetem is not set.
    } else {
        # Is this a clone?
        $args -> {"clone"} = 1
            if(defined($self -> {"cgi"} -> param("clone")) && $self -> {"cgi"} -> param("clone"));
    }


    # copy the article into the args hash, skipping anything already set in the args.
    foreach my $key (keys %{$article}) {
        $args -> {$key} = $article -> {$key} unless($args -> {$key});
    }

    # Get a list of available posting levels in the system (which may be more than the
    # user has access to - we don't care about that at this point)
    my $sys_levels = $self -> {"article"} -> get_all_levels();
    my $jslevels   = $self -> _build_levels_jsdata($sys_levels);
    my $levels     = $self -> _build_level_options($sys_levels, $args -> {"levels"});

    # Work out where the user is allowed to post from
    my $user_feeds = $self -> {"feed"} -> get_user_feeds($userid, $sys_levels);
    my $feeds      = $self -> _build_feedlist($user_feeds, $args -> {"feeds"});

    # Work out which levels the user has access to for each feed. This generates a
    # chunk of javascript to stick into the page to hide/show options and default-tick
    # them as appropriate.
    my $user_levels = $self -> {"article"} -> get_user_levels($user_feeds, $sys_levels, $userid);
    my $feed_levels = $self -> _build_feed_levels($user_levels, $args -> {"levels"});

    # Release timing options
    my $relops = $self -> {"template"} -> build_optionlist($self -> {"relops"}, $args -> {"release_mode"});
    my $format_release = $self -> {"template"} -> format_time($args -> {"release_time"}, "%d/%m/%Y %H:%M")
        if($args -> {"release_time"});

    # Which schedules and sections can the user post to?
    my $schedules  = $self -> {"article"} -> get_user_schedule_sections($userid);
    my $schedblock = $self -> {"template"} -> load_template("compose/schedule_noaccess.tem"); # default to 'none of them'
    if($schedules && scalar(keys(%{$schedules}))) {
        my $schedlist    = $self -> {"template"} -> build_optionlist($schedules -> {"_schedules"}, $args -> {"schedule"});
        my $schedmode    = $self -> {"template"} -> build_optionlist($self -> {"schedrelops"}, $args -> {"schedule_mode"});
        my $schedrelease = $self -> {"template"} -> format_time($args -> {"stimestamp"}, "%d/%m/%Y %H:%M")
            if($args -> {"stimestamp"});

        my $scheddata = "";
        $args -> {"section"} = "" if(!$args -> {"section"});
        foreach my $id (sort(keys(%{$schedules}))) {
            next unless($id =~ /^id_/);

            $scheddata .= '"'.$id.'": { next: ['.join(",", map { '"'.$self -> {"template"} -> format_time($_).'"' } @{$schedules -> {$id} -> {"next_run"}}).'],';
            $scheddata .= '"sections": ['.join(",",
                                               map {
                                                   '{ "value": "'. $_ -> {"value"}.'", "name": "'.$_ -> {"name"}.'", "selected": '.($_ -> {"value"} eq $args -> {"section"} && $id eq $args -> {"schedule"} ? 'true' : 'false').'}'
                                               } @{$schedules -> {$id} -> {"sections"}}).']},';
        }

        $schedblock = $self -> {"template"} -> load_template("compose/schedule.tem", {"***schedule***"          => $schedlist,
                                                                                      "***schedule_mode***"     => $schedmode,
                                                                                      "***schedule_date_fmt***" => $schedrelease,
                                                                                      "***stimestamp***"        => $args -> {"stimestamp"} || 0,
                                                                                      "***priority***"          => $args -> {"priority"} || 2,
                                                                                      "***scheduledata***"      => $scheddata,
                                                             });
    }

    # Image options
    my $imagea_opts = $self -> _build_image_options($args -> {"images"} -> {"a"} -> {"mode"});
    my $imageb_opts = $self -> _build_image_options($args -> {"images"} -> {"b"} -> {"mode"});

    # Pre-existing image options
    my $fileimages = $self -> {"article"} -> get_file_images();
    my $imagea_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"images"} -> {"a"} -> {"img"});
    my $imageb_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"images"} -> {"b"} -> {"img"});

    # Wrap the error in an error box, if needed.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    my $exclude_sent = 1;
    $exclude_sent = 0 if($args -> {"clone"});

    # Suck in all the draft/unsent notification settings so they can be shown
    ($args -> {"notify_matrix"} -> {"year"},
     $args -> {"notify_matrix"} -> {"used_methods"},
     $args -> {"notify_matrix"} -> {"enabled"},
     $args -> {"methods"}                           ) = $self -> {"queue"} -> get_notifications($articleid, $exclude_sent);
    my $notifyblock = $matrix -> build_matrix($userid, $args -> {"notify_matrix"} -> {"enabled"}, $args -> {"notify_matrix"} -> {"year"});

    my $notify_settings = "";
    my $userdata = $self -> {"session"} -> get_user_byid($userid);

    my $methods = $self -> {"queue"} -> get_methods();
    foreach my $method (keys(%{$methods})) {
        $notify_settings .= $methods -> {$method} -> generate_compose($args, $userdata);
    }

    # Determine whether the user expects to be prompted for confirmation
    my $noconfirm = $self -> {"session"} -> {"auth"} -> {"app"} -> get_user_setting($userid, "disable_confirm");
    $noconfirm = $noconfirm -> {"value"} || "0";

    # Work out the button name and title
    my ($submitmsg, $titlemsg) = ("{L_EDIT_SUBMIT}", "EDIT_FORM_TITLE");

    ($submitmsg, $titlemsg) = ("{L_CLONE_SUBMIT}", "CLONE_FORM_TITLE")
        if($args -> {"clone"});

    ($submitmsg, $titlemsg) = ("{L_TEMPLATE_SUBMIT}", "TEMPLATE_FORM_TITLE")
        if($args -> {"template"});

    # Handle the minor edit: it's disabled if this is a template instance or clone
    my $disable_minor = ($args -> {"template"} || $args -> {"clone"});
    my $minoredit = $self -> {"template"} -> load_template("edit/minoredit-".($disable_minor ? "disabled.tem" : "enabled.tem"), { "***isminor***" => $args -> {"minor_edit"} ? 'checked="checked"' : "" });

    # Default the summary inclusion
    $args -> {"full_summary"} = 1 if(!defined($args -> {"full_summary"}));

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar($titlemsg),
            $self -> {"template"} -> load_template("edit/edit.tem", {"***errorbox***"         => $error,
                                                                     "***form_url***"         => $self -> build_url(block => "edit", pathinfo => ["update", $args -> {"id"}]),
                                                                     "***title***"            => $args -> {"title"},
                                                                     "***summary***"          => $args -> {"summary"},
                                                                     "***article***"          => $args -> {"article"},
                                                                     "***allowed_feeds***"    => $feeds,
                                                                     "***levels***"           => $levels,
                                                                     "***release_mode***"     => $relops,
                                                                     "***release_date_fmt***" => $format_release,
                                                                     "***rtimestamp***"       => $args -> {"release_time"},
                                                                     "***imageaopts***"       => $imagea_opts,
                                                                     "***imagebopts***"       => $imageb_opts,
                                                                     "***imagea_url***"       => $args -> {"images"} -> {"a"} -> {"url"} || "https://",
                                                                     "***imageb_url***"       => $args -> {"images"} -> {"b"} -> {"url"} || "https://",
                                                                     "***imageaimgs***"       => $imagea_img,
                                                                     "***imagebimgs***"       => $imageb_img,
                                                                     "***relmode***"          => $args -> {"relmode"} || 0,
                                                                     "***userlevels***"       => $feed_levels,
                                                                     "***levellist***"        => $jslevels,
                                                                     "***sticky_mode***"      => $self -> {"template"} -> build_optionlist($self -> {"stickyops"}, $args -> {"sticky"}),
                                                                     "***batchstuff***"       => $schedblock,
                                                                     "***notifystuff***"      => $notifyblock,
                                                                     "***notifysettings***"   => $notify_settings,
                                                                     "***disable_confirm***"  => $noconfirm,
                                                                     "***preset***"           => $args -> {"preset"},
                                                                     "***clone***"            => $args -> {"clone"} || "0",
                                                                     "***submitmsg***"        => $submitmsg,
                                                                     "***titlemsg***"         => "{L_".$titlemsg."}",
                                                                     "***minoredit***"        => $minoredit,
                                                                     "***fullsummary***"      => $args -> {"full_summary"} ? 'checked="checked"' : '',
                                                   }));
}


# ============================================================================
#  Update functions

## @method private @ _edit_article($articleid)
# Update an article in the system. This validates and processes the values submitted by
# the user in the edit form, and stores the result in the database. The edited article
# is marked as edited, and a new one added with the new settings.
#
# @return Three values: the page title, the content to show in the page, and the extra
#         css and javascript directives to place in the header.
sub _edit_article {
    my $self      = shift;
    my $articleid = shift;
    my $error = "";
    my $args  = {};

    my ($article, $message) = $self -> _check_articleid($articleid);
    return ($article, $message) unless(ref($article) eq "HASH");

    ($error, $args) = $self -> _validate_article($articleid);

    return $self -> _generate_edit($articleid, $args, $error);
}


## @method private @ _generate_success()
# Generate a success page to send to the user. This creates a message box telling the
# user that their article has been edited - this is needed to ensure that users get a
# confirmation, but it isn't generated inside _edit_article() or _validate_article() so
# that page refreshes don't submit multiple copies.
#
# @return The page title, content, and meta refresh strings.
sub _generate_success {
    my $self = shift;

    return ("{L_EDIT_EDITED_TITLE}",
            $self -> {"template"} -> message_box("{L_EDIT_EDITED_TITLE}",
                                                 "articleok",
                                                 "{L_EDIT_EDITED_SUMMARY}",
                                                 "{L_EDIT_EDITED_DESC}",
                                                 undef,
                                                 "messagecore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='".$self -> build_url(block => "articles", pathinfo => [])."'"} ]),
            ""
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

    # Exit with a permission error unless the user has permission to compose. Can't check for
    # edit permission at this point (don't know the article ID yet!), but compose is required
    # for edit, so.
    if(!$self -> check_permission("compose")) {
        $self -> log("error:compose:permission", "User does not have permission to compose articles");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_COMPOSE_DESC}",
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

        if(!scalar(@pathinfo)) {
            $title   = "{L_EDIT_ERROR_TITLE}";
            $content = $self -> {"template"} -> message_box("{L_EDIT_ERROR_TITLE}",
                                                            "error",
                                                            "{L_EDIT_ERROR_NOID_SUMMARY}",
                                                            "{L_EDIT_ERROR_NOID_DESC}",
                                                            undef,
                                                            "messagecore",
                                                            [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                               "colour"  => "blue",
                                                               "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]);
        } else {
            given($pathinfo[0]) {
                when("update")   { ($title, $content, $extrahead) = $self -> _edit_article($pathinfo[1]); }
                when("success")  { ($title, $content, $extrahead) = $self -> _generate_success(); }
                default {
                    ($title, $content, $extrahead) = $self -> _generate_edit($pathinfo[0]);
                }
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("edit/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "edit");
    }
}

1;
