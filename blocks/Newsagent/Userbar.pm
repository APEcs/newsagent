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
use base qw(Newsagent);
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
        or return Webperl::SystemModule::set_error("Compose initialisation failed: ".$SystemModule::errstr);

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

## @method $ block_display($title, $current)
# Generate a user toolbar, populating it as needed to reflect the user's options
# at the current time.
#
# @param title   A string to show as the page title.
# @param current The current page name.
# @return A string containing the user toolbar html on success, undef on error.
sub block_display {
    my $self    = shift;
    my $title   = shift;
    my $current = shift;

    $self -> clear_error();

    # Initialise fragments to sane "logged out" defaults.
    my ($siteadmin, $msglist, $compose, $userprofile, $presets) =
        ($self -> {"template"} -> load_template("userbar/siteadmin_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/msglist_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/compose_disabled.tem"),
         $self -> {"template"} -> load_template("userbar/profile_loggedout.tem", {"***url-login***" => $self -> build_url(block => "login")}),
         $self -> {"template"} -> load_template("userbar/presets_disabled.tem"),
        );

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

        $presets = $self -> _build_preset_list($user -> {"user_id"});

        # User is logged in, so actually reflect their current options and state
        $userprofile = $self -> {"template"} -> load_template("userbar/profile_loggedin.tem", {"***realname***"    => $user -> {"fullname"},
                                                                                               "***username***"    => $user -> {"username"},
                                                                                               "***gravhash***"    => $user -> {"gravatar_hash"},
                                                                                               "***url-logout***"  => $self -> build_url(block => "login"  , pathinfo => ["logout"])});
    } # if(!$self -> {"session"} -> anonymous_session())

    return $self -> {"template"} -> load_template("userbar/userbar.tem", {"***pagename***"   => $title,
                                                                          "***site-admin***" => $siteadmin,
                                                                          "***presets***"    => $presets,
                                                                          "***compose***"    => $compose,
                                                                          "***msglist***"    => $msglist,
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
