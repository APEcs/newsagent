## @file
# This file contains the implementation of the article composition facility.
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
package Newsagent::Article::Compose;

use strict;
use base qw(Newsagent::Article); # This class extends the Article block class
use v5.12;

use Newsagent::System::Matrix;
use Data::Dumper;

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

    my $userid = $self -> {"session"} -> get_session_userid();

    # Get a list of available posting levels in the system (which may be more than the
    # user has access to - we don't care about that at this point)
    my $sys_levels = $self -> {"article"} -> get_all_levels();
    my $levels     = $self -> _build_level_options($sys_levels, $args -> {"levels"});

    # Work out where the user is allowed to post from
    my $user_feeds = $self -> {"article"} -> get_user_feeds($userid, $sys_levels);
    my $feeds      = $self -> {"template"} -> build_optionlist($user_feeds, $args -> {"feed"});

    # Work out which levels the user has access to for each feed. This generates a
    # chunk of javascript to stick into the page to hide/show options and default-tick
    # them as appropriate.
    my $user_levels = $self -> {"article"} -> get_user_levels($user_feeds, $sys_levels, $userid);
    my $feed_levels = $self -> _build_feed_levels($user_levels, $args -> {"feed"}, $args -> {"levels"});

    # Release timing options
    my $relops = $self -> {"template"} -> build_optionlist($self -> {"relops"}, $args -> {"mode"});
    my $format_release = $self -> {"template"} -> format_time($args -> {"rtimestamp"}, "%d/%m/%Y %H:%M")
        if($args -> {"rtimestamp"});


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
    my $notifyblock = $matrix -> build_matrix($userid, $args -> {"notify_matrix"} -> {"enabled"}, $args -> {"notify_year"});

    my $notify_settings = "";
    my $userdata = $self -> {"session"} -> get_user_byid($userid);

    foreach my $method (keys(%{$self -> {"notify_methods"}})) {
        $notify_settings .= $self -> {"notify_methods"} -> {$method} -> generate_compose($args, $userdata);
    }

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar("COMPOSE_FORM_TITLE"),
            $self -> {"template"} -> load_template("compose/compose.tem", {"***errorbox***"         => $error,
                                                                           "***form_url***"         => $self -> build_url(block => "compose", pathinfo => ["add"]),
                                                                           "***title***"            => $args -> {"title"},
                                                                           "***summary***"          => $args -> {"summary"},
                                                                           "***article***"          => $args -> {"article"},
                                                                           "***allowed_feeds***"    => $feeds,
                                                                           "***levels***"           => $levels,
                                                                           "***release_mode***"     => $relops,
                                                                           "***release_date_fmt***" => $format_release,
                                                                           "***rtimestamp***"       => $args -> {"rtimestamp"},
                                                                           "***imageaopts***"       => $imagea_opts,
                                                                           "***imagebopts***"       => $imageb_opts,
                                                                           "***imagea_url***"       => $args -> {"images"} -> {"a"} -> {"url"} || "https://",
                                                                           "***imageb_url***"       => $args -> {"images"} -> {"b"} -> {"url"} || "https://",
                                                                           "***imageaimgs***"       => $imagea_img,
                                                                           "***imagebimgs***"       => $imageb_img,
                                                                           "***relmode***"          => $args -> {"relmode"} || 0,
                                                                           "***userlevels***"       => $feed_levels,
                                                                           "***batchstuff***"       => $schedblock,
                                                                           "***notifystuff***"      => $notifyblock,
                                                                           "***notifysettings***"   => $notify_settings,
                                                                          }));
}


## @method private @ _generate_success()
# Generate a success page to send to the user. This creates a message box telling the
# user that their article has been added - this is needed to ensure that users get a
# confirmation, but it isn't generated inside _add_article() or _validate_article() so
# that page refreshes don't submit multiple copies.
#
# @return The page title, content, and meta refresh strings.
sub _generate_success {
    my $self = shift;

    return ("{L_COMPOSE_ADDED_TITLE}",
            $self -> {"template"} -> message_box("{L_COMPOSE_ADDED_TITLE}",
                                                 "articleok",
                                                 "{L_COMPOSE_ADDED_SUMMARY}",
                                                 "{L_COMPOSE_ADDED_DESC}",
                                                 undef,
                                                 "messagecore",
                                                 [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                    "colour"  => "blue",
                                                    "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]),
            $self -> {"template"} -> load_template("refreshmeta.tem", {"***url***" => $self -> build_url(block => "compose", pathinfo => []) } )
        );
}


# ============================================================================
#  Addition functions

## @method private @ _add_article()
# Add an article to the system. This validates and processes the values submitted by
# the user in the compose form, and stores the result in the database.
#
# @return Three values: the page title, the content to show in the page, and the extra
#         css and javascript directives to place in the header.
sub _add_article {
    my $self  = shift;
    my $error = "";
    my $args  = {};

    if($self -> {"cgi"} -> param("newarticle")) {
        ($error, $args) = $self -> _validate_article();
    }

    return $self -> _generate_compose($args, $error);
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

    # Exit with a permission error unless the user has permission to compose
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
        # Normal page operation.
        # ... handle operations here...

        if(!scalar(@pathinfo)) {
            ($title, $content, $extrahead) = $self -> _generate_compose();
        } else {
            given($pathinfo[0]) {
                when("add")      { ($title, $content, $extrahead) = $self -> _add_article(); }
                when("success")  { ($title, $content, $extrahead) = $self -> _generate_success(); }
                default {
                    ($title, $content, $extrahead) = $self -> _generate_compose();
                }
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("compose/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead);
    }
}

1;
