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

    # Convert the levels and image data in the article into something easier to use
    $article -> {"levels"} = $self -> _fixup_levels($article -> {"levels"});
    $article -> {"images"} = $self -> _fixup_images($article -> {"images"});

    # copy the article into the args hash, skipping anything already set in the args.
    foreach my $key (keys %{$article}) {
        $args -> {$key} = $article -> {$key} unless($args -> {$key});
    }

    # Get a list of available posting levels in the system (which may be more than the
    # user has access to - we don't care about that at this point)
    my $sys_levels = $self -> {"article"} -> get_all_levels();
    my $levels     = $self -> _build_level_options($sys_levels, $args -> {"levels"});

    # Work out where the user is allowed to post from
    my $user_sites = $self -> {"article"} -> get_user_sites($userid);
    my $sites      = $self -> {"template"} -> build_optionlist($user_sites, $args -> {"sitename"});

    # Work out which levels the user has access to for each site. This generates a
    # chunk of javascript to stick into the page to hide/show options and default-tick
    # them as appropriate.
    my $user_levels = $self -> {"article"} -> get_user_levels($user_sites, $sys_levels, $userid);
    my $site_levels = $self -> _build_site_levels($user_levels, $args -> {"sitename"}, $args -> {"levels"});

    # Release timing options
    my $relops = $self -> {"template"} -> build_optionlist($self -> {"relops"}, $args -> {"release_mode"});
    my $format_release = $self -> {"template"} -> format_time($args -> {"rtimestamp"}, "%d/%m/%Y %H:%M")
        if($args -> {"rtimestamp"});

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

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar("EDIT_FORM_TITLE"),
            $self -> {"template"} -> load_template("edit/edit.tem", {"***errorbox***"         => $error,
                                                                     "***form_url***"         => $self -> build_url(block => "edit", pathinfo => ["update", $args -> {"id"}]),
                                                                     "***title***"            => $args -> {"title"},
                                                                     "***summary***"          => $args -> {"summary"},
                                                                     "***article***"          => $args -> {"article"},
                                                                     "***allowed_sites***"    => $sites,
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
                                                                     "***userlevels***"       => $site_levels,
                                                   }));
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
                when("success")  { ($title, $content, $extrahead) = $self -> _generate_success(); }
                default {
                    ($title, $content, $extrahead) = $self -> _generate_edit($pathinfo[0]);
                }
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("edit/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead);
    }
}

1;
