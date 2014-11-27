## @file
# This file contains the implementation of the Newsagent user toolbar.
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

## @class Newsagent::Userbar
# The Userbar class encapsulates the code required to generate and
# manage the user toolbar.
package Newsagent::Userbar;

use strict;
use experimental qw(smartmatch);
use base qw(Newsagent);
use Newsagent::System::Article;
use Newsagent::System::TellUs;
use v5.12;

sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"article"} = Newsagent::System::Article -> new(dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$SystemModule::errstr);

    $self -> {"tellus"} = Newsagent::System::TellUs -> new(dbh      => $self -> {"dbh"},
                                                           settings => $self -> {"settings"},
                                                           logger   => $self -> {"logger"},
                                                           roles    => $self -> {"system"} -> {"roles"},
                                                           metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("TellUs initialisation failed: ".$SystemModule::errstr);

    return $self;
}


# ==============================================================================
#  Preset listing

## @method private $ _build_preset_list($userid)
# Geneerate a list of presets the user has access to use as article templates.
#
# @param userid The ID of the user generating the userbar.
# @return A string containing the preset list
sub _build_preset_list {
    my $self   = shift;
    my $userid = shift;

    my $presets = $self -> {"article"} -> get_user_presets($userid)
        or return "<!-- ".$self -> {"article"} -> errstr()." -->";

    my $temlist = "";
    foreach my $tem (@{$presets}) {
        $temlist .= $self -> {"template"} -> load_template("userbar/presets_item.tem", {"***url***"  => $self -> build_url(block => "edit", pathinfo => [$tem -> {"id"}], params => { usetem => 1 }),
                                                                                        "***name***" => $tem -> {"preset"}
                                                           });
    }

    if($temlist) {
        return $self -> {"template"} -> load_template("userbar/presets_enabled.tem", {"***templates***" => $temlist});
    }

    return $self -> {"template"} -> load_template("userbar/presets_disabled.tem");
}


# ==============================================================================
#  Bar generation

## @method $ block_display($title, $current, $doclink)
# Generate a user toolbar, populating it as needed to reflect the user's options
# at the current time.
#
# @param title   A string to show as the page title.
# @param current The current page name.
# @param doclink The name of a document link to include in the userbar. If not
#                supplied, no link is shown.
# @return A string containing the user toolbar html on success, undef on error.
sub block_display {
    my $self    = shift;
    my $title   = shift;
    my $current = shift;
    my $doclink = shift;

    $self -> clear_error();

    my $loginurl = $self -> build_url(block => "login",
                                      fullurl  => 1,
                                      pathinfo => [],
                                      params   => {},
                                      forcessl => 1);

    my $fronturl = $self -> build_url(block    => $self -> {"settings"} -> {"config"} -> {"default_block"},
                                      fullurl  => 1,
                                      pathinfo => [],
                                      params   => {});

    my $feedsurl = $self -> build_url(block    => "feeds",
                                      fullurl  => 1,
                                      pathinfo => [],
                                      params   => {});

    # Initialise fragments to sane "logged out" defaults.
    my ($siteadmin, $msglist, $compose, $userprofile, $presets, $docs, $tellus, $tuqueues, $newslist) =
        ($self -> {"template"} -> load_template("userbar/siteadmin_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/msglist_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/compose_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/profile_loggedout_http".($ENV{"HTTPS"} eq "on" ? "s" : "").".tem", {"***url-login***" => $loginurl}),
         $self -> {"template"} -> load_template("userbar/presets_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/doclink_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/tellus_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/tuqueues_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/newsletters_disabled.tem"),
        );

    # Is documentation available?
    my $url = $self -> get_documentation_url($doclink);
    $docs = $self -> {"template"} -> load_template("userbar/doclink_enabled.tem", {"***url-doclink***" => $url})
        if($url);

    # Is the user logged in?
    if(!$self -> {"session"} -> anonymous_session()) {
        my $user = $self -> {"session"} -> get_user_byid()
            or return $self -> self_error("Unable to obtain user data for logged in user. This should not happen!");

        $compose   = $self -> {"template"} -> load_template("userbar/compose_enabled.tem"  , {"***url-compose***" => $self -> build_url(block => "compose", pathinfo => [])})
            if($self -> check_permission("compose") && $current ne "compose");

        $msglist   = $self -> {"template"} -> load_template("userbar/msglist_enabled.tem"  , {"***url-msglist***" => $self -> build_url(block => "articles", pathinfo => [])})
            if($self -> check_permission("listarticles") && $current ne "articles");

        $siteadmin = $self -> {"template"} -> load_template("userbar/siteadmin_enabled.tem", {"***url-admin***"   => $self -> build_url(block => "admin"   , pathinfo => [])})
            if($self -> check_permission("siteadmin"));

        $tellus = $self -> {"template"} -> load_template("userbar/tellus_enabled.tem"      , {"***url-tellus***"  => $self -> build_url(block => "tellus"  , pathinfo => [])})
            if($self -> check_permission("tellus"));

        $newslist = $self -> {"template"} -> load_template("userbar/newsletters_enabled.tem", {"***url-newslist***"  => $self -> build_url(block => "newsletters"  , pathinfo => [])})
            if($self -> check_permission("newsletter.showlist"));

        $presets = $self -> _build_preset_list($user -> {"user_id"});

        # Determine whether the user has any TellUs queues they can manage
        my $queues = $self -> {"tellus"} -> get_queues($user -> {"user_id"}, "manage");
        if($queues && scalar(@{$queues})) {
            # User has queues, do any have new messages?
            my $hasnew = 0;
            foreach my $queue (@{$queues}) {
                my $stats = $self -> {"tellus"} -> get_queue_stats($queue -> {"value"});
                if($stats -> {"new"}) {
                    $hasnew = 1;
                    last;
                }
            }

            $tuqueues = $self -> {"template"} -> load_template("userbar/tuqueues_enabled.tem", {"***url-tuqueue***" => $self -> build_url(block => "queues", pathinfo => []),
                                                                                                "***mode***"        => ($hasnew ? "tuqueues_new" : "tuqueues")});
        }

        # User is logged in, so actually reflect their current options and state
        $userprofile = $self -> {"template"} -> load_template("userbar/profile_loggedin.tem", {"***realname***"    => $user -> {"fullname"},
                                                                                               "***username***"    => $user -> {"username"},
                                                                                               "***gravhash***"    => $user -> {"gravatar_hash"},
                                                                                               "***url-logout***"  => $self -> build_url(block => "login"  , pathinfo => ["logout"])});
    } # if(!$self -> {"session"} -> anonymous_session())

    return $self -> {"template"} -> load_template("userbar/userbar.tem", {"***pagename***"   => $title,
                                                                          "***mainurl***"    => $self -> build_url(),
                                                                          "***front_url***"  => $fronturl,
                                                                          "***feeds_url***"  => $feedsurl,
                                                                          "***tellus***"     => $tellus,
                                                                          "***site-admin***" => $siteadmin,
                                                                          "***presets***"    => $presets,
                                                                          "***compose***"    => $compose,
                                                                          "***msglist***"    => $msglist,
                                                                          "***tuqueues***"   => $tuqueues,
                                                                          "***newslist***"   => $newslist,
                                                                          "***doclink***"    => $docs,
                                                                          "***profile***"    => $userprofile});
}


## @method $ page_display()
# Produce the string containing this block's full page content. This is primarily provided for
# API operations that allow the user to change their profile and settings.
#
# @return The string containing this block's page content.
sub page_display {
    my $self = shift;
    my ($content, $extrahead, $title);

    if(!$self -> {"session"} -> anonymous_session()) {
        my $user = $self -> {"session"} -> get_user_byid()
            or return '';

        my $apiop = $self -> is_api_operation();
        if(defined($apiop)) {
            given($apiop) {
                default {
                    return $self -> api_html_response($self -> api_errorhash('bad_op',
                                                                             $self -> {"template"} -> replace_langvar("API_BAD_OP")))
                }
            }
        }
    }

    return "<p class=\"error\">".$self -> {"template"} -> replace_langvar("BLOCK_PAGE_DISPLAY")."</p>";
}

1;
