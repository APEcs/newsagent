# @file
# This file contains the implementation of the global API class
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

# Note that this API is distinct from Article::API - it provides many of
# the same features, but isn't constrained by old assumptions for the UI.
#
# IMPORTANT: this API module should make every effort to avoid any use of the
# Newsagent::api_html_response() function and make responses go through
# api_response() as much as possible.

## @class
package Newsagent::API;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Article);
use Webperl::Utils qw(path_join);
use File::Basename;
use JSON;
use DateTime;
use v5.12;


# ============================================================================
#  Support functions

## @method private $ _show_api_docs()
# Redirect the user to a Swagger-generated API documentation page.
# Note that this function will never return.
sub _show_api_docs {
    my $self = shift;

    $self -> log("api:docs", "Sending user to API docs");

    my ($host) = $self -> {"settings"} -> {"config"} -> {"httphost"} =~ m|^https?://([^/]+)|;
    return $self -> {"template"} -> load_template("api/docs.tem", { "%(host)s" => $host });
}


# ============================================================================
#  Image handling functions

## @method @ _validate_image_file()
# Determine whether the image uploaded is valid.
#

sub _validate_image_file {
    my $self = shift;

    my $filename = $self -> {"cgi"} -> param("image");
    return (undef, $self -> {"template"} -> replace_langvar("MEDIA_ERR_NOIMGDATA"))
        if(!$filename);

    my $tmpfile = $self -> {"cgi"} -> tmpFileName($filename)
        or return (undef, $self -> {"template"} -> replace_langvar("MEDIA_ERR_NOTMP"));

    my ($name, $path, $extension) = fileparse($filename, '\..*');
    $filename = $name.$extension;
    $filename =~ tr/ /_/;
    $filename =~ s/[^a-zA-Z0-9_.-]//g;

    # By the time this returns, either the file has been copied into the filestore and the
    # database updated with the file details, or an error has occurred.
    my $imgdata = $self -> {"article"} -> {"images"} -> store_image($tmpfile, $filename, $self -> {"session"} -> get_session_userid());
    return (undef, $self -> {"article"} -> {"images"} -> errstr())
        unless($imgdata  && $imgdata -> {"id"});

    return $imgdata;
}


sub _build_image_get_response {
    my $self = shift;

    my @apipath = $self -> {"cgi"} -> multi_param("api");

    my $identifier = $apipath[2];
    my $args = {};
    given($identifier) {
        when(/^\d+$/)        { $args -> {"id"}   = $identifier; }
        when(/^[a-f0-9]+$/i) { $args -> {"md5"}  = $identifier; }
        when(/^.+/)          { $args -> {"name"} = $identifier; }
        default {
            return $self -> api_errorhash("bad_request", "Image identifier not specified or supported");
        }
    }

    my $imgdata = $self -> {"article"} -> {"images"} -> get_file_images($args);
    return $imgdata;
}


sub _build_image_post_response {
    my $self = shift;

    if(!$self -> check_permission("upload")) {
        $self -> log("error:api:permission", "User does not have permission to upload");

        return $self -> api_errorhash("permission_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("MEDIA_PERMISSION_NOUPLOAD")}));
    }

    # User has permission, validate the submission and store it
    $self -> log("debug:api:upload", "Permission granted, attempting store of uploaded image");

    my ($data, $error) = $self -> _validate_image_file();
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $error}))
        if($error);

    $self -> log("debug:api:upload", "Store complete, image saved with id ".$data -> {"id"});
    return $data;
}


# ============================================================================
#  API functions

## @method private $ _build_token_response()
# Generate an API token for the currently logged-in user.
#
# @api GET /token
#
# @return A reference to a hash containing the API response data.
sub _build_token_response {
    my $self = shift;

    $self -> log("api:token", "Generating new API token for user");

    # permission check is done in page_display()

    if($self -> {"cgi"} -> request_method() eq "GET") {
        my $token = $self -> api_token_generate($self -> {"session"} -> get_session_userid())
            or return $self -> api_errorhash('internal_error', $self -> errstr());

        return { "token" => $token };
    }

    return $self -> api_errorhash("bad_request", $self -> {"template"} -> replace_langvar("API_BAD_REQUEST"))
}



## @method private $ _build_image_response()
# Perform operations related to images through the API
#
# @api POST /image
# @api GET  /image/{identifier}
#
# @return A reference to a hash containing the API response data.
sub _build_image_response {
    my $self = shift;

    # /image/{identifier}
    if($self -> {"cgi"} -> request_method() eq "GET") {
        return $self -> _build_image_get_response();

    # /image
    } elsif($self -> {"cgi"} -> request_method() eq "POST") {
        return $self -> _build_image_post_response();

    }

    return $self -> api_errorhash("bad_request", $self -> {"template"} -> replace_langvar("API_BAD_REQUEST"));
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Produce the string containing this block's full page content. This generates
# the compose page, including any errors or user feedback.
#
# @capabilities api.grade
#
# @return The string containing this block's page content.
sub page_display {
    my $self = shift;

    $self -> api_token_login();

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # Force JSON output unless overridden in query string
        $self -> {"settings"} -> {"config"} -> {"API:format"} = "json";

        # General API permission check - will block anonymous users at a minimum
        return $self -> api_response($self -> api_errorhash('permission_error',
                                                            "You do not have permission to use the API"))
            unless($self -> check_permission('api.use'));

        my @pathinfo = $self -> {"cgi"} -> multi_param('api');

        # API call - dispatch to appropriate handler.
        given($apiop) {
            when("token") { $self -> api_response($self -> _build_token_response()); }
            when("image") { $self -> api_response($self -> _build_image_response()); }

            when("") { return $self -> _show_api_docs(); }

            default {
                return $self -> api_response($self -> api_errorhash('bad_op',
                                                                    $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        return $self -> _show_api_docs();
    }
}

1;