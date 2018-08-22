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
use Webperl::Utils qw(path_join array_or_arrayref);
use File::Basename;
use Text::Sprintf::Named qw(named_sprintf);
use JSON;
use DateTime;
use v5.12;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the API,.
#
# @param args A hash of values to initialise the object with.
# @return A reference to a new Newsagent::API object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new( timefmt      => '%a, %d %b %Y %H:%M:%S %Z',
                                         gravatar_url => 'https://gravatar.com/avatar/%(hash)s?s=64&d=mm&r=g',
                                         @_)
        or return undef;

    return $self;
}


# ============================================================================
#  Support functions

## @method private $ _epoch_to_string($epoch)
# Convert a unix timestamp to a formatted string.
#
# @param epoch The unix timestamp to convert.
# @return A string containing the converted timestamp.
sub _epoch_to_string {
    my $self  = shift;
    my $epoch = shift;

    my $dt = DateTime -> from_epoch(epoch => $epoch,
                                    time_zone => $self -> {"settings"} -> {"config"} -> {"time_zone"} // "Europe/London");

    return $dt -> strftime($self -> {"timefmt"});
}


## @method private $ _iso8601_to_epoch($iso8601, $deftime)
# Convert a string in IS8601 format into a unix timestamp.
#
# @param iso8601 The iso8601 string to convert to a timestamp.
# @param deftime The default timestamp to use if the iso8601
#                string is empty or malformed.
# @return The unix timestamp.
sub _iso8601_to_epoch {
    my $self = shift;
    my $iso8601 = shift;
    my $deftime = shift;

    return $deftime unless($iso8601);

    my ($year, $month, $day, $hour, $minute, $second, $tz) = $iso8601 =~ /^(\d{4})-?(\d{2})-?(\d{2})(?:T| )(\d{2}):?(\d{2}):?(\d{2})([-+]\d\d:\d\d)?/;

    # If the timezone has been captured, remove the colon as DateTime::TimeZone assumes +hhmm
    $tz =~ s/://
        if($tz);

    # Use DateTime to convert to an epoch as it handles TZ spiders nicely
    my $date = eval { DateTime -> new(year      => $year,
                                      month     => $month,
                                      day       => $day,
                                      hour      => $hour,
                                      minute    => $minute,
                                      second    => $second,
                                      time_zone => $tz // $self -> {"settings"} -> {"config"} -> {"timezone"} // "Europe/London");
    };
    if($@) {
        $self -> log("iso8601 error: $@ from $iso8601");
        return $deftime;
    }

    return $date -> epoch();
}


## @method private $ _list_extract($list, $field)
# Given a reference to and array of hashrefs, extract the
# values stored in one of the fields of each hash.
#
# @param list  A reference to an array of hashrefs
# @param field The name of the field in each hash to extract
# @return A reference to an array of values extracted from
#         the hash. Note that the order of this is not
#         defined, and the array may contain undef elements
#         if the field has not been set in one or more hashes
#         in the source array.
sub _list_extract {
    my $self  = shift;
    my $list  = shift;
    my $field = shift;

    my @values;
    foreach my $hash (@{$list}) {
        push(@values, $hash -> {$field});
    }

    return \@values;
}


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

## @method private $ _make_image_args($identifier)
# Given an image identifier, construct the arguments to pass to the
# Newsagent::System::Image::get_file_images() function. Supported idenfiers
# are:
#
# - a number, will be treated as the image ID.
# - a hex string, will be treated as the image MD5 sum
# - a string of other characters, will be treated as the image name. Note
#   that '*' may be used for wildcard searches.
#
# @param identifier The identifier to search for images with.
# @return A reference to a hash containing the arguments on success,
#         an error message on error.
sub _make_image_args {
    my $self       = shift;
    my $identifier = shift;

    my $args = {};
    given($identifier) {
        when(/^\d+$/)        { $args -> {"id"}   = $identifier; }
        when(/^[a-f0-9]+$/i) { $args -> {"md5"}  = $identifier; }
        when(/^.+/)          { $identifier =~ s/\*/%/g;
                               $args -> {"name"} = $identifier;
        }
        default {
            return "Image identifier not specified or supported";
            $self -> log("error:api:parameter", "Request for image, identifier is: ".(defined($identifier) ? $identifier : "not set"));
        }
    }

    return $args;
}


## @method private $ _make_image_response($data)
# Given an image data hash, or reference to an array of image data hashes,
# produce an array of image data hashes that matches the API specification.
#
# @param data An image data hash, or a reference to an array of hashes.
# @return An array of image data response hashes.
sub _make_image_response {
    my $self = shift;
    my $data = array_or_arrayref(@_);

    my @result;
    foreach my $image (@{$data}) {
        my $gravatar = named_sprintf($self -> {"gravatar_url"}, { "hash" => $image -> {"gravatar_hash"} });

        push(@result, { "id"     => $image -> {"id"},
                        "md5sum" => $image -> {"md5"},
                        "name"   => $image -> {"name"},
                        "urls"   => {
                            "lead"      => $image -> {"path"} -> {"icon"},
                            "thumb"     => $image -> {"path"} -> {"thumb"},
                            "large"     => $image -> {"path"} -> {"large"},
                            "media"     => $image -> {"path"} -> {"media"},
                            "ppcompt"   => $image -> {"path"} -> {"ppcompat"},
                            "bigscreen" => $image -> {"path"} -> {"tactus"},
                        },
                        "uploader" => {
                            "user_id"  => $image -> {"uploader"},
                            "username" => $image -> {"username"},
                            "realname" => $image -> {"fullname"},
                            "email"    => $image -> {"email"},
                            "gravatar" => $gravatar,
                        },
                        "uploaded" => $self -> _epoch_to_string($image -> {"uploaded"})
             });
    }

    return \@result;
}


## @method @ _validate_image_file()
# Determine whether the image uploaded is valid. This will check the file
# upload, and store the image in the system's image library.
#
# @return A reference to an image data hash on sucess, otherwise an array
#         of two values: undef and an error message.
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


## @method $ _build_image_get_response($identifier)
# Generate the response for the /image/{identifier} REST endpoint.
#
# @param identifier The identifier to search for the image using.
# @return An array of image data response hashes.
sub _build_image_get_response {
    my $self       = shift;
    my $identifier = shift;

    $self -> log("api:image", "Lookup operation requested by user");

    my $args = $self -> _make_image_args($identifier);
    return $self -> api_errorhash("bad_request", $args)
        unless(ref($args) eq "HASH");

    # The client may have forced filtering by userid
    my ($userid, $error) = $self -> validate_numeric('userid', { required => 0,
                                                                 nicename => 'userid',
                                                                 min      => 1,
                                                                 intonly  => 1});
    return $self -> api_errorhash("bad_request", $error)
        if($error);

    $args -> {"userid"} = $userid
        if($userid);

    # Now do the search and response massaging
    my $imgdata = $self -> {"article"} -> {"images"} -> get_file_images($args);
    return $self -> _make_image_response($imgdata);
}


## @method $ _build_image_post_response()
# Generate the response for the /image post REST endpoint. This receives
# image data from the client, checks it, adds the image to the library
# if valid, and then returns an arrayref containing the response hash.
#
# @return An array of image data response hashes.
sub _build_image_post_response {
    my $self = shift;

    # General API permission check - will block anonymous users at a minimum
    return $self -> api_response($self -> api_errorhash('permission_error',
                                                        "You do not have permission to use the API"))
        unless($self -> check_permission('api.use'));

    $self -> log("api:image", "Upload operation requested by user");

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
    return $self -> _build_image_get_response($data -> {"id"});
}


# ============================================================================
#  Article handling functions

## @method private $ _make_article_timestamps($articles)
# Given a reference to an array of article hashrefs, convert all the unix
# timestamps in the articles into DateTime objects. Note that this modifies
# the article data in place, it does not copy anything!
#
# @param articles A reference to an array of article hashes
# @return A reference to an array of article hashes
sub _make_article_timestamps {
    my $self     = shift;
    my $articles = shift;

    foreach my $article (@{$articles}) {
        foreach my $field ("created", "updated", "release_time", "sticky_until") {
            $article -> {$field} = DateTime -> from_epoch(epoch     => $article -> {$field},
                                                          time_zone => $self -> {"settings"} -> {"config"} -> {"time_zone"} // "Europe/London")
                if(defined($article -> {$field}));
        }

        if($article -> {"images"} && scalar(@{$article -> {"images"}})) {
            foreach my $image (@{$article -> {"images"}}) {
                $image -> {"uploaded"} = DateTime -> from_epoch(epoch     => $image -> {"uploaded"},
                                                                time_zone => $self -> {"settings"} -> {"config"} -> {"time_zone"} // "Europe/London")
                    if(defined($image) && defined($image -> {"uploaded"}));
            }
        }
    }

    return $articles;
}


## @method private $ _build_article_get_response($identifier)
# Fetch the information for an article or article(s).
#
# @param identifier The identifier to search for articles with.
# @return A reference to an array of articles.
sub _build_article_get_response {
    my $self       = shift;
    my $identifier = shift;

    print STDERR "Identifier: $identifier\n";

    my $results = [];
    given($identifier) {
        # Identifier can be either an ID or a comma separated list of IDs
        when(/^\d+(,\d+)*$/) {
            my @ids = split(/,/, $identifier);

            foreach my $id (@ids) {
                my $article = $self -> {"article"} -> get_article($id)
                    or return $self -> api_errorhash("not_found", "No article with ID $identifier found");

                # Pull in the notifications for the article, includes ones that may have been sent
                my ($year, $used, $enabled, $notify, $methods) = $self -> {"queue"} -> get_notifications($article -> {"id"});
                if($year) {

                    # Convert the list of enabled notifications into a more usable format
                    my $notifications = {};
                    foreach my $recip (keys(%{$enabled})) {
                        foreach my $method (keys(%{$enabled -> {$recip}})) {
                            push(@{$notifications -> {$recip}}, $method);
                        }
                    }

                    # And build a more useful notifications structure
                    $article -> {"notifications"} = { "acyear" => $year,
                                                      "notify" => $notifications,
                                                      "send_mode1" => $notify -> [0] -> {"send_mode"},
                                                      "send_at1"   => $notify -> [0] -> {"send_at"},
                                                      "methods" => $methods,
                    };
                } else {
                    $article -> {"notifications"} = {};
                }

                push(@{$results}, $article);
            }
        }

        when(/^[fF]eed:/) {
            my ($feeds) = $identifier =~ /^feed:(.*)$/i;
            my @feedlist = split(/,/, $feeds);

            $results  = $self -> {"article"} -> get_feed_articles(
                {
                    "feed" => \@feedlist
                });


        }

        default {
            return $self -> api_errorhash("bad_request", "Unsupported argument to /article");
        }
    }

    return $self -> _make_article_timestamps($results);
}


## @method private void _import_json_image_data($image, $type)
# Given an image hash, extract the important information for the validator
# functions from the hash. If the hash is undef, safe defaults are used.
#
# @param image A reference to an image hash.
# @param type  The image type, should be "a" or "b" for Lead or Article
# @note This is making me really regret the mess that is image idenfication.
sub _import_json_image_data {
    my $self  = shift;
    my $image = shift // { "type"     => "none",
                           "location" => "https://",
                           "id"       => 0 };
    my $type  = shift;

    # Why did I have to go and give these different values in the database and UI?
    $image -> {"type"} = "img"
        if($image -> {"type"} eq "file");

    $self -> {"cgi"} -> param("image${type}_mode" , $image -> {"type"});
    $self -> {"cgi"} -> param("image${type}_url"  , $image -> {"location"});
    $self -> {"cgi"} -> param("image${type}_imgid", $image -> {"id"});
}


## @method private void _import_json_file_data($files)
# Given an array of file hashes, extract the list of file IDs needed
# for the validator code.
#
# @param files A reference to an array of file hashrefs.
sub _import_json_file_data {
    my $self  = shift;
    my $files = shift;
    my @filelist;

    # Nothing to do if the files reference is empty
    return unless($files && scalar(@{$files}));

    # slurp the file IDs into an array. Could probably map this, but speed
    # isn't critical here
    foreach my $file (@{$files}) {
        push(@filelist, $file -> {"id"});
    }

    $self -> {"cgi"} -> param("files", join(",", @filelist));
}


## @method private void _import_json_notifications($notify)
# Extract the information about notifications from the specified hash. This
# processes the notification selections specified in the provided hash
# into a form the validator can work with.
#
# @param notify A reference to a hash containing the notification settings.
sub _import_json_notifications {
    my $self   = shift;
    my $notify = shift;

    # Can't do anything if no notification values are provided
    return
        unless($notify && $notify -> {"notify"});

    # Build the notification matric out of the defined notifications
    my $matrix = [];
    foreach my $recip (keys %{$notify -> {"notify"}}) {
        foreach my $method (@{$notify -> {"notify"} -> {$recip}}) {
            push(@{$matrix}, "$recip-$method");
        }
    }

    # ==== Notifications, ignored if relmode = 1 ====
    $self -> {"cgi"} -> param("acyear"    , $notify -> {"acyear"});
    $self -> {"cgi"} -> param("send_mode1", $notify -> {"send_mode1"});
    $self -> {"cgi"} -> param("send_at1"  , $notify -> {"send_at1"});
    $self -> {"cgi"} -> param(-name   => "matrix",
                              -values => $matrix);

    # ==== Email extension, ignored if relmode = 1 ====
    $self -> {"cgi"} -> param("email-cc"      , $notify -> {"methods"} -> {"Email"} -> {"cc"});
    $self -> {"cgi"} -> param("email-bcc"     , $notify -> {"methods"} -> {"Email"} -> {"bcc"});
    $self -> {"cgi"} -> param("email-reply_to", $notify -> {"methods"} -> {"Email"} -> {"reply_to"});
    $self -> {"cgi"} -> param("email-prefix"  , $notify -> {"methods"} -> {"Email"} -> {"prefix_id"});
    $self -> {"cgi"} -> param("email-bccme"   , $notify -> {"methods"} -> {"Email"} -> {"bcc_sender"} ? "on" : "");

    # ==== Twitter extension, ignored if relmode = 1 ====
    $self -> {"cgi"} -> param("twitter-mode", $notify -> {"methods"} -> {"Twitter"} -> {"mode"});
    $self -> {"cgi"} -> param("twitter-text", $notify -> {"methods"} -> {"Twitter"} -> {"tweet"});
    $self -> {"cgi"} -> param("twitter-auto", $notify -> {"methods"} -> {"Twitter"} -> {"auto"});
}


## @method private $ _import_json_data($json)
# Given a string containing JSON data, import the data into the script
# parameter storage so that the article validator can check it and
# create/edit articles.
#
# @param json A string containing the article data in JSON format
# @return undef on success, an error message on error.
sub _import_json_data {
    my $self = shift;
    my $json = shift;

    my $data = eval { decode_json($json); };
    return "JSON decode failed: $@"
        if($@);

    # Push JSON data into parameters so that the same validation code can be used
    $self -> {"cgi"} -> param("relmode", $data -> {"relmode"});

    # ==== Common article fields
    $self -> {"cgi"} -> param("title"  , $data -> {"title"} // "");
    $self -> {"cgi"} -> param("summary", $data -> {"summary"} // "");
    $self -> {"cgi"} -> param("article", $data -> {"article"} // "");

    # ==== Normal article fields, ignored if relmode = 1
    $self -> {"cgi"} -> param("mode", $data -> {"release_mode"} // "visible");
    $self -> {"cgi"} -> param("rtimestamp", $self -> _iso8601_to_epoch($data -> {"release_time"},
                                                                       $data -> {"rtimestamp"} // 0));

    $self -> {"cgi"} -> param(-name => "level", -values => $self -> _list_extract($data -> {"levels"}, "level"));
    $self -> {"cgi"} -> param(-name => "feed" , -values => $self -> _list_extract($data -> {"feeds"} , "id"));

    my $sticky_time = $data -> {"sticky_until"} ? _iso8601_to_epoch($data -> {"sticky_until"}) : 0;
    if($sticky_time) {
        # sticky parameter is # of sticky days, so we need to convert the sticky until timestamp
        # into a number of days from now.
        $sticky_time = max(0, int(($sticky_time - time()) / 86400) + 1);
    }
    $self -> {"cgi"} -> param("sticky", $sticky_time);
    $self -> {"cgi"} -> param("full_summary", $data -> {"full_summary"} // "0");

    #  ==== Newsletter fields, ignored if relmode = 0
    $self -> {"cgi"} -> param("schedule"    , $data -> {"schedule"} // "");
    $self -> {"cgi"} -> param("section"     , $data -> {"section"}  // "0");
    $self -> {"cgi"} -> param("sort_order"  , "0");
    $self -> {"cgi"} -> param("schedule_mode", $data -> {"release_mode"} // "next");
    $self -> {"cgi"} -> param("stimestamp"  , $self -> _iso8601_to_epoch($data -> {"release_time"}, 0));

    # ==== Notifications, ignored if relmode = 1 ====
    # ==== Email extension, ignored if relmode = 1 ====
    # ==== Twitter extension, ignored if relmode = 1 ====
    $self -> _import_json_notifications($data -> {"notifications"});

    # ==== Media fields ====
    $self -> _import_json_image_data($data -> {"images"} -> [0], "a");
    $self -> _import_json_image_data($data -> {"images"} -> [1], "b");
    $self -> _import_json_file_data($data -> {"files"});

    return undef;
}


## @method private $ _build_article_post_response()
# Create an article in the system. Note that user permission checks are applied
# within the validation process.
#
# @return A reference to an array containing the article data on success.
sub _build_article_post_response {
    my $self = shift;

    # General API permission check - will block anonymous users at a minimum
    return $self -> api_response($self -> api_errorhash('permission_error',
                                                        "You do not have permission to use the API"))
        unless($self -> check_permission('api.use'));

    return $self -> api_errorhash('permission_error',
                                  "You do not have permission to create articles")
        unless($self -> check_permission('compose'));

    # Check whether json data has been specified, and import it if needed
    if($self -> {"cgi"} -> param("json")) {
        my $json = $self -> {"cgi"} -> param("json");

        my $error = $self -> _import_json_data($json);
        return $self -> api_errorhash('internal_error', $error)
            if($error);
    }

    # Let the standard article validator handle creation
    my ($error, $args) = $self -> _validate_article(undef, 1);
    return $self -> api_errorhash('internal_error', "Creation failed: $error")
        if($error);

    return $self -> _build_article_get_response($args -> {"id"});
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

    # General API permission check - will block anonymous users at a minimum
    return $self -> api_response($self -> api_errorhash('permission_error',
                                                        "You do not have permission to use the API"))
        unless($self -> check_permission('api.use'));

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
        my @pathinfo = $self -> {"cgi"} -> multi_param('api');

        return $self -> _build_image_get_response($pathinfo[2]);

    # /image
    } elsif($self -> {"cgi"} -> request_method() eq "POST") {
        return $self -> _build_image_post_response();

    }

    return $self -> api_errorhash("bad_request", $self -> {"template"} -> replace_langvar("API_BAD_REQUEST"));
}


## @method private $ _build_article_response()
# Perform operations related to articles through the API
#
# @api POST   /article
# @api GET    /article/{identifier}
# @api PUT    /article/{identifier}
# @api DELETE /article/{identifier}
#
# @return A reference to a hash containing the API response data.
sub _build_article_response {
    my $self = shift;

    # /article/{identifier}
    if($self -> {"cgi"} -> request_method() eq "GET") {
        my @pathinfo = $self -> {"cgi"} -> multi_param('api');

        return $self -> _build_article_get_response($pathinfo[2]);

    # POST /article
    } elsif($self -> {"cgi"} -> request_method() eq "POST") {
        return $self -> _build_article_post_response();

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

        my @pathinfo = $self -> {"cgi"} -> multi_param('api');

        # API call - dispatch to appropriate handler.
        given($apiop) {
            when("token")   { $self -> api_response($self -> _build_token_response()); }
            when("image")   { $self -> api_response($self -> _build_image_response()); }
            when("article") { $self -> api_response($self -> _build_article_response()); }

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