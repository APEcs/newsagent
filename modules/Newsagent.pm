## @file
# This file contains the implementation of the Newsagent block base class.
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
#
package Newsagent;

use strict;
use base qw(Webperl::Block); # Features are just a specific form of Block
use CGI::Util qw(escape);
use Webperl::Utils qw(join_complex path_join);
use XML::Simple;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for Newsagent block modules. This will ensure that a valid
# item id has been stored in the block object data.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    return $self;
}


# ============================================================================
#  Page generation support


## @method $ generate_newsagent_page($title, $content, $extrahead)
# A convenience function to wrap page content in the standard page template. This
# function allows blocks to embed their content in a page without having to build
# the whole page including "common" items themselves. It should be called to wrap
# the content when the block's page_display is returning.
#
# @param title     The page title.
# @param content   The content to show in the page.
# @param extrahead Any extra directives to place in the header.
# @return A string containing the page.
sub generate_newsagent_page {
    my $self      = shift;
    my $title     = shift;
    my $content   = shift;
    my $extrahead = shift || "";

    my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");

    return $self -> {"template"} -> load_template("page.tem", {"***extrahead***" => $extrahead,
                                                               "***title***"     => $title,
                                                               "***userbar***"   => ($userbar ? $userbar -> block_display($title, $self -> {"block"}) : "<!-- Userbar load failed: ".$self -> {"module"} -> errstr()." -->"),
                                                               "***content***"   => $content});
}


# ============================================================================
#  Permissions/Roles related.

## @method $ check_permission($action, $contextid, $userid)
# Determine whether the user has permission to peform the requested action. This
# should be overridden in subclasses to provide actual checks.
#
# @param action    The action the user is attempting to perform.
# @param contextid The ID of the metadata context the user is trying to perform
#                  an action in. If this is not given, the root context is used.
# @param userid    The ID of the user to check the permissions for. If not
#                  specified, the current session user is used.
# @return true if the user has permission, false if they do not, undef on error.
sub check_permission {
    my $self      = shift;
    my $action    = shift;
    my $contextid = shift || $self -> {"system"} -> {"roles"} -> {"root_context"};
    my $userid    = shift || $self -> {"session"} -> get_session_userid();

    return $self -> {"system"} -> {"roles"} -> user_has_capability($contextid, $userid, $action);
}


## @method $ check_login()
# Determine whether the current user is logged in, and if not force them to
# the login form.
#
# @return undef if the user is logged in and has access, otherwise a page to
#         send back with a permission error. If the user is not logged in, this
#         will 'silently' redirect the user to the login form.
sub check_login {
    my $self = shift;

    # Anonymous users need to get punted over to the login form
    if($self -> {"session"} -> anonymous_session()) {
        print $self -> {"cgi"} -> redirect($self -> build_login_url());
        exit;

    # Otherwise, permissions need to be checked
    } elsif(!$self -> check_permission("view")) {
        $self -> log("error:permission", "User does not have perission 'view'");

        # Logged in, but permission failed
        my $message = $self -> {"template"} -> message_box("{L_PERMISSION_FAILED_TITLE}",
                                                           "error",
                                                           "{L_PERMISSION_FAILED_SUMMARY}",
                                                           "{L_PERMISSION_VIEW_DESC}",
                                                           undef,
                                                           "errorcore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='{V_[scriptpath]}'"} ]);
        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");

        # Build the error page...
        return $self -> {"template"} -> load_template("error/general.tem",
                                                      {"***title***"     => "{L_PERMISSION_FAILED_TITLE}",
                                                       "***message***"   => $message,
                                                       "***extrahead***" => "",
                                                       "***userbar***"   => ($userbar ? $userbar -> block_display("{L_PERMISSION_FAILED_TITLE}") : "<!-- Userbar load failed: ".$self -> {"module"} -> errstr()." -->"),
                                                      });
    }

    return undef;
}


# ============================================================================
#  API support

## @method $ is_api_operation()
# Determine whether the feature is being called in API mode, and if so what operation
# is being requested.
#
# @return A string containing the API operation name if the script is being invoked
#         in API mode, undef otherwise. Note that, if the script is invoked in API mode,
#         but no operation has been specified, this returns an empty string.
sub is_api_operation {
    my $self = shift;

    my @api = $self -> {"cgi"} -> param('api');

    # No api means no API mode.
    return undef unless(scalar(@api));

    # API mode is set by placing 'api' in the first api entry. The second api
    # entry is the operation.
    return $api[1] || "" if($api[0] eq 'api');

    return undef;
}


## @method $ api_errorhash($code, $message)
# Generate a hash that can be passed to api_response() to indicate that an error was encountered.
#
# @param code    A 'code' to identify the error. Does not need to be numeric, but it
#                should be short, and as unique as possible to the error.
# @param message The human-readable error message.
# @return A reference to a hash to pass to api_response()
sub api_errorhash {
    my $self    = shift;
    my $code    = shift;
    my $message = shift;

    return { 'error' => {
                          'info' => $message,
                          'code' => $code
                        }
           };
}


## @method $ api_html_response($data)
# Generate a HTML response containing the specified data.
#
# @param data The data to send back to the client. If this is a hash, it is
#             assumed to be the result of a call to api_errorhash() and it is
#             converted to an appropriate error box. Otherwise, the data is
#             wrapped in a minimal html wrapper for return to the client.
# @return The html response to send back to the client.
sub api_html_response {
    my $self = shift;
    my $data = shift;

    # Fix up error hash returns
    $data = $self -> {"template"} -> load_template("api/html_error.tem", {"***code***" => $data -> {"error"} -> {"code"},
                                                                          "***info***" => $data -> {"error"} -> {"info"}})
        if(ref($data) eq "HASH" && $data -> {"error"});

    return $self -> {"template"} -> load_template("api/html_wrapper.tem", {"***data***" => $data});
}


## @method $ api_response($data, %xmlopts)
# Generate an XML response containing the specified data. This function will not return
# if it is successful - it will return an XML response and exit.
#
# @param data    A reference to a hash containing the data to send back to the client as an
#                XML response.
# @param xmlopts Options passed to XML::Simple::XMLout. Note that the following defaults are
#                set for you:
#                - XMLDecl is set to '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
#                - KeepRoot is set to 0
#                - RootName is set to 'api'
# @return Does not return if successful, otherwise returns undef.
sub api_response {
    my $self    = shift;
    my $data    = shift;
    my %xmlopts = @_;
    my $xmldata;

    $xmlopts{"XMLDecl"} = '<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>'
        unless(defined($xmlopts{"XMLDecl"}));

    $xmlopts{"KeepRoot"} = 0
        unless(defined($xmlopts{"KeepRoot"}));

    $xmlopts{"RootName"} = 'api'
        unless(defined($xmlopts{"RootName"}));

    eval { $xmldata = XMLout($data, %xmlopts); };
    $xmldata = $self -> {"template"} -> load_template("xml/error_response.tem", { "***code***"  => "encoding_failed",
                                                                                  "***error***" => "Error encoding XML response: $@"})
        if($@);

    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($xmldata);

    $self -> {"template"} -> set_module_obj(undef);
    $self -> {"messages"} -> set_module_obj(undef);
    $self -> {"system"} -> clear() if($self -> {"system"});
    $self -> {"session"} -> {"auth"} -> {"app"} -> set_system(undef) if($self -> {"session"} -> {"auth"} -> {"app"});

    $self -> {"dbh"} -> disconnect();
    $self -> {"logger"} -> end_log();

    exit;
}


# ============================================================================
#  General utility

## @method void log($type, $message)
# Log the current user's actions in the system. This is a convenience wrapper around the
# Logger::log function.
#
# @param type     The type of log entry to make, may be up to 64 characters long.
# @param message  The message to attach to the log entry, avoid messages over 128 characters.
sub log {
    my $self     = shift;
    my $type     = shift;
    my $message  = shift;

    $message = "[Item:".($self -> {"itemid"} ? $self -> {"itemid"} : "none")."] $message";
    $self -> {"logger"} -> log($type, $self -> {"session"} -> get_session_userid(), $self -> {"cgi"} -> remote_host(), $message);
}


## @method $ set_saved_state()
# Store the current status of the script, including block, api, pathinfo, and querystring
# to session variables for later restoration.
#
# @return true on success, undef on error.
sub set_saved_state {
    my $self = shift;

    $self -> clear_error();

    my $res = $self -> {"session"} -> set_variable("saved_block", $self -> {"cgi"} -> param("block"));
    return undef unless(defined($res));

    my @pathinfo = $self -> {"cgi"} -> param("pathinfo");
    $res = $self -> {"session"} -> set_variable("saved_pathinfo", join("/", @pathinfo));
    return undef unless(defined($res));

    my @api = $self -> {"cgi"} -> param("api");
    $res = $self -> {"session"} -> set_variable("saved_api", join("/", @api));
    return undef unless(defined($res));

    # Convert the query parameters to a string, skipping the block, pathinfo, and api
    my @names = $self -> {"cgi"} -> param;
    my @qstring = ();
    foreach my $name (@names) {
        next if($name eq "block" || $name eq "pathinfo" || $name eq "api");

        my @vals = $self -> {"cgi"} -> param($name);
        foreach my $val (@vals) {
            push(@qstring, escape($name)."=".escape($val));
        }
    }
    $res = $self -> {"session"} -> set_variable("saved_qstring", join("&amp;", @qstring));
    return undef unless(defined($res));

    return 1;
}


## @method @ get_saved_state()
# A convenience wrapper around Session::get_variable() for fetching the state saved in
# build_login_url().
#
# @return An array of strings, containing the block, pathinfo, api, and query string.
sub get_saved_state {
    my $self = shift;

    return ($self -> {"session"} -> get_variable("saved_block"),
            $self -> {"session"} -> get_variable("saved_pathinfo"),
            $self -> {"session"} -> get_variable("saved_api"),
            $self -> {"session"} -> get_variable("saved_qstring"));
}


# ============================================================================
#  URL building

## @method $ build_login_url()
# Attempt to generate a URL that can be used to redirect the user to a login form.
# The user's current query state (course, block, etc) is stored in a session variable
# that can later be used to bring them back to the location this was called from.
#
# @return A relative login form redirection URL.
sub build_login_url {
    my $self = shift;

    # Note: CGI::query_string() produces a properly escaped, joined query string based on the
    #       **current parameters**, even ones added by the program (hence the pathinfo, api and block
    #       parameters added by the BlockSelector will be included!)
    $self -> {"session"} -> set_variable("savestate", $self -> {"cgi"} -> query_string());

    return $self -> build_url(block => "login");
}


## @method $ build_return_url($fullurl)
# Pulls the data out of the session saved state, checks it for safety,
# and returns the URL the user should be redirected/linked to to return to the
# location they were attempting to access before login.
#
# @param fullurl If set to true, the generated url will contain the protocol and
#                host. Otherwise the URL will be absolute from the server root.
# @return A relative return URL.
sub build_return_url {
    my $self    = shift;
    my $fullurl = shift;
    my ($block, $pathinfo, $api, $qstring) = $self -> get_saved_state();

    # Return url block should never be "login"
    $block = $self -> {"settings"} -> {"config"} -> {"default_block"} if($block eq "login");

    # Build the URL from them
    return $self -> build_url("block"    => $block,
                              "pathinfo" => $pathinfo,
                              "api"      => $api,
                              "params"   => $qstring,
                              "fullurl"  => $fullurl);
}


## @method $ build_url(%args)
# Build a url suitable for use at any point in the system. This takes the args
# and attempts to build a url from them. Supported arguments are:
#
# * fullurl  - if set, the resulting URL will include the protocol and host. Defaults to
#              false (URL is absolute from the host root).
# * block    - the name of the block to include in the url. If not set, the current block
#              is used if possible, otherwise the system-wide default block is used.
# * pathinfo - Either a string containing the pathinfo, or a reference to an array
#              containing pathinfo fragments. If not set, the current pathinfo is used.
# * api      - api fragments. If the first element is not "api", it is added.
# * params   - Either a string containing additional query string parameters to add to
#              the URL, or a reference to a hash of additional query string arguments.
#              Values in the hash may be references to arrays, in which case multiple
#              copies of the parameter are added to the query string, one for each
#              value in the array.
#
# @param args A hash of arguments to use when building the URL.
# @return A string containing the URL.
sub build_url {
    my $self = shift;
    my %args = @_;
    my $base = "";

    # Default the block, item, and API fragments if needed and possible
    $args{"block"} = ($self -> {"cgi"} -> param("block") || $self -> {"settings"} -> {"config"} -> {"default_block"})
        if(!defined($args{"block"}));

    if(!defined($args{"pathinfo"})) {
        my @cgipath = $self -> {"cgi"} -> param("pathinfo");
        $args{"pathinfo"} = \@cgipath if(scalar(@cgipath));
    }

    if(!defined($args{"api"})) {
        my @cgiapi = $self -> {"cgi"} -> param("api");
        $args{"api"} = \@cgiapi if(scalar(@cgiapi));
    }

    # Convert the pathinfo and api to slash-delimited strings
    my $pathinfo = join_complex($args{"pathinfo"}, joinstr => "/");
    my $api      = join_complex($args{"api"}, joinstr => "/");

    # Force the API call to start 'api' if it doesn't
    $api = "api/$api" if($api && $api !~ m|^/?api|);

    # build the query string parameters.
    my $querystring = join_complex($args{"params"}, joinstr => ($args{"joinstr"} || "&amp;"), pairstr => "=", escape => 1);

    # building the URL involves shoving the bits together. path_join is intelligent enough to ignore
    # anything that is undef or "" here, so explicit checks beforehand should not be needed.
    my $url = path_join($self -> {"settings"} -> {"config"} -> {"scriptpath"}, $args{"block"}, $pathinfo, $api);
    $url = path_join($self -> {"cgi"} -> url(-base => 1), $url)
        if($args{"fullurl"});

    # Strip block, pathinfo, and api from the query string if they've somehow made it in there.
    # Note this can't simply be made 'eg' as the progressive match can leave a trailing &
    if($querystring) {
        while($querystring =~ s{((?:&(?:amp;))?)(?:api|block|pathinfo)=[^&]+(&?)}{$1 && $2 ? "&" : ""}e) {}
        $url .= "?$querystring";
    }

    return $url;
}


1;
