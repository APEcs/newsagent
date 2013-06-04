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
use base qw(Newsagent::Article); # This class extends the Newsagent block class
use v5.12;


# ============================================================================
#  Content generators

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

    my ($action, $actdate, $actuser) = ("{L_ALIST_CREATED}", $self -> {"template"} -> fancy_time($article -> {"updated"}), $article -> {"realname"} || $article -> {"username"});
    if($article -> {"updated"} != $article -> {"created"}) {
        $action = "{L_ALIST_UPDATED}";
        my $user = $self -> {"session"} -> get_user_byid($article -> {"updated_id"});
        $actuser = $user -> {"realname"} || $user -> {"username"}
            if($user);
    }

    return $self -> {"template"} -> load_template("articlelist/row.tem", {"***modeclass***" => $article -> {"release_mode"},
                                                                          "***modeinfo***"  => $self -> {"relmodes"} -> {$article -> {"release_mode"}},
                                                                          "***date***"      => $self -> {"template"} -> fancy_time($article -> {"release_time"}, 0, 1),
                                                                          "***site***"      => $article -> {"sitedesc"},
                                                                          "***title***"     => $article -> {"title"} || $self -> {"template"} -> format_time($article -> {"release_time"}),
                                                                          "***action***"    => $action,
                                                                          "***actdate***"   => $actdate,
                                                                          "***actuser***"   => $actuser,
                                                                          "***controls***"  => $self -> {"template"} -> load_template("articlelist/control_".$article -> {"release_mode"}.".tem"),
                                                                          "***id***"        => $article -> {"id"},
                                                                          "***editurl***"   => $self -> build_url(block => "edit", pathinfo => [$article -> {"id"}]),
                                                  });
}


## @method private @ _generate_articlelist()
# Generate the contents of a page listing the articles the user has permission to edit.
#
# @todo pagination control
#
# @return Two strings: the page title, and the contents of the page.
sub _generate_articlelist {
    my $self     = shift;
    my $userid   = $self -> {"session"} -> get_session_userid();
    my $settings = {"count"  => 20,
                    "offset" => 0,
                    "sortfield" => "",
                    "sortdir"   => ""};
    my $now  = time();

    my ($articles, $count) = $self -> {"article"} -> get_user_articles($userid, $settings);
    if($articles) {
        my $list = "";
        foreach my $article (@{$articles}) {
            $list .= $self -> _build_article_row($article, $now);
        }

        return ($self -> {"template"} -> replace_langvar("ALIST_TITLE"),
                $self -> {"template"} -> load_template("articlelist/content.tem", {"***articles***" => $list,
                                                                                   "***paginate***" => ""}));
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

    # handle special cases for deletion: edited and draft articles can not be deleted
    $newmode = $article -> {"release_mode"}
        if($newmode eq "deleted" && ($article -> {"release_mode"} eq "edited" || $article -> {"release_mode"} eq "draft"));

    # Handle the situation where updating the mode will make the item visible,
    # but its release time is in the future (ie: it needs to be timed)
    $newmode = "timed"
        if($newmode eq "visible" && $article -> {"release_time"} > time() && !$setdate);

    # Only attempt to change the status if needed
    if($article -> {"release_mode"} ne $newmode) {
        # Do the update, and spit out the row html if successful
        $article = $self -> {"article"} -> set_article_status($articleid, $userid, $newmode, $setdate)
            or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));
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
        $self -> log("error:compose:permission", "User does not have permission to list articles");

        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_LISTARTICLE_DESC}",
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
        ($title, $content) = $self -> _generate_articlelist();

        $extrahead .= $self -> {"template"} -> load_template("articlelist/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead);
    }
}

1;
