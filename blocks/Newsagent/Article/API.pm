# @file
# This file contains the implementation of the API class
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
package Newsagent::Article::API;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Article); # This class extends the Newsagent article class
use Webperl::Utils qw(is_defined_numeric);
use File::Basename;
use v5.12;

# ============================================================================
#  Support functions

## @method private $ _explode_matrix($matrix)
# Given a string describing the enabled options in the recipient matrix of the
# form "recipientid-methodid,recipientid-methodid,...", produce an array of
# valid enabled options.
#
# @param matrix The string describing the enabled matrix options.
# @return A reference to an array of hashrefs, each element contains
#         {"recipient_id" => id, "method_id" => id} for a valid option.
sub _explode_matrix {
    my $self   = shift;
    my $matrix = shift;

    my @elements = split(/,/, $matrix);
    my @enabled = ();

    foreach my $element (@elements) {
        my ($recipid, $methid) = $element =~ /^(\d+)-(\d+)$/;

        # Only store the data from the matrix if it is valid
        push(@enabled, {"recipient_id" => $recipid, "method_id" => $methid})
            if($recipid && $methid);
    }

    return \@enabled;
}


# ============================================================================
#  Validation code

## @method @ _validate_image_file($mode)
# Determine whether the file uploaded is valid.
#
# @param mode The image mode to return the path for.
# @return Three values: the image id and media image path on success, undef on error, and an error message
#         if needed.
sub _validate_article_file {
    my $self = shift;
    my $mode = shift;

    my $filename = $self -> {"cgi"} -> param("upload");
    return (undef, undef, $self -> {"template"} -> replace_langvar("MEDIA_ERR_NOIMGDATA"))
        if(!$filename);

    my $tmpfile = $self -> {"cgi"} -> tmpFileName($filename)
        or return (undef, undef, $self -> {"template"} -> replace_langvar("MEDIA_ERR_NOTMP"));

    my ($name, $path, $extension) = fileparse($filename, '\..*');
    $filename = $name.$extension;
    $filename =~ tr/ /_/;
    $filename =~ s/[^a-zA-Z0-9_.-]//g;

    # By the time this returns, either the file has been copied into the filestore and the
    # database updated with the file details, or an error has occurred.
    my $imgdata = $self -> {"article"} -> {"images"} -> store_image($tmpfile, $filename, $self -> {"session"} -> get_session_userid())
        or return (undef, undef, $self -> {"article"} -> {"images"} -> errstr());

    # All that _validate_article_image() needs is the new ID
    return ($imgdata -> {"id"}, $imgdata -> {"path"} -> {$mode}, undef);
}


# ============================================================================
#  API functions


## @method private $ _build_rcount_response()
# Generate an API response to a recipient count query. This attempts to determine
# how many individual addresses will be contacted for each recipient speicified
# in the query.
#
# @return A hash containing the API response.
sub _build_rcount_response {
    my $self = shift;

    my $yearid = is_defined_numeric($self -> {"cgi"}, "yearid")
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("API_ERROR_NOYID")}));

    my $setmatrix = $self -> {"cgi"} -> param("matrix")
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("API_ERROR_NOMATRIX")}));

    # Split the matrix into recipient/method hashes. If nothing comes out of this,
    # the data in $matrix is bad
    my $enabled = $self -> _explode_matrix($setmatrix);
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("API_ERROR_EMPTYMATRIX")}))
        if(!scalar(@{$enabled}));

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    # Now fetch the settings data for each recipient/method pair
    my $recipmeth = $matrix -> matrix_to_recipients($enabled, $yearid);

    my $output = { 'response' => { 'status' => 'ok' }};

    my $methods = $self -> {"queue"} -> get_methods();

    # At this point, recipmeth contains the list of selected recipients, organised by the
    # method that will be used to contact them, and the settings that will be used by the
    # notification method to contact them. Now we need to go through these lists fetching
    # the counts for each
    foreach my $method (keys(%{$recipmeth -> {"methods"}})) {
        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("API_ERROR_BADMETHOD")}))
            if(!$methods -> {$method});

        foreach my $recip (@{$recipmeth -> {"methods"} -> {$method}}) {
            $recip -> {"recipient_count"} = $methods -> {$method} -> get_recipient_count($recip -> {"settings"});
            return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $methods -> {$method} -> errstr()}))
                if(!defined($recip -> {"recipient_count"}));

            push(@{$output -> {"response"} -> {"recipient"}}, { id           => $recip -> {"recipient_id"}."-".$recip -> {"method_id"},
                                                                method_id    => $recip -> {"method_id"},
                                                                recipient_id => $recip -> {"recipient_id"},
                                                                name         => $recip -> {"recipient_name"},
                                                                shortname    => $recip -> {"recipient_short"},
                                                                count        => $recip -> {"recipient_count"}});
        }
    }

    return $output;
}


# ============================================================================
#  Media library API functions

## @method private $ _build_media_selector($mode, $userid, $sortfield, $offset, $count)
# Generate a string containing media selector boxes.
#
# @param mode   Which form of image to use. Should be one of 'icon', 'thumb', 'media' or 'full'.
# @param userid The ID of the user to filter the images by. If zero or undef,
#               images by all users are included.
# @param sortfield The field to sort the images on. Valid values are 'uploaded' and 'name'
# @param offset    The offset to start fetching images from.
# @param count     The number of images to fetch.
# @return A string containing the selector HTML.
sub _build_media_selector {
    my $self      = shift;
    my $mode      = shift;
    my $userid    = shift;
    my $sortfield = shift;
    my $offset    = shift;
    my $count     = shift;

    my $images = $self -> {"article"} -> {"images"} -> get_file_images($userid, $sortfield, $offset, $count);
    my $selector = "";

    foreach my $image (@{$images}) {
        $selector .= $self -> {"template"} -> load_template("medialibrary/image.tem",
                                                            { "***mode***"     => $mode,
                                                              "***id***"       => $image -> {"id"},
                                                              "***url***"      => $image -> {"path"} -> {$mode},
                                                              "***name***"     => $image -> {"name"},
                                                              "***user***"     => $image -> {"fullname"},
                                                              "***gravhash***" => $image -> {"gravatar_hash"},
                                                              "***uploaded***" => $self -> {"template"} -> fancy_time($image -> {"uploaded"}, 0, 1)
                                                            });
    }

    return $selector;
}


## @method private $ _build_mediaopen_response(void)
# Generate the HTML to send back in response to a mediaopen API request.
#
# @return The HTML to send back to the client.
sub _build_mediaopen_response {
    my $self = shift;

    my ($mode, $moderr) = $self -> validate_options('mode', { "required" => 0,
                                                              "default"  => "media",
                                                              "source"   => ["icon", "media"]});
    my ($count, $cnterr) = $self -> validate_numeric('count', { required => 0,
                                                                default  => $self -> {"settings"} -> {"config"} -> {"Media:initial_count"},
                                                                intonly  => 1,
                                                                min      => 1,
                                                                nicename => "Count"});

    return $self -> {"template"} -> load_template("medialibrary/content.tem",
                                                  { "***initial***" => $self -> _build_media_selector($mode, undef, 'uploaded', 0, $count)
                                                  }
                                                 );
}


sub _build_mediastream_response {
    my $self = shift;

    # First fetch all the supported parameters
    my ($mode, $moderr) = $self -> validate_options('mode', { "required" => 0,
                                                              "default"  => "media",
                                                              "source"   => ["icon", "media"]});

    my ($offset, $offerr) = $self -> validate_numeric('offset', { required => 0,
                                                                  default  => 0,
                                                                  intonly  => 1,
                                                                  min      => 0,
                                                                  nicename => "Offset"});
    my ($count, $cnterr) = $self -> validate_numeric('count', { required => 0,
                                                                default  => $self -> {"settings"} -> {"config"} -> {"Media:fetch_count"},
                                                                intonly  => 1,
                                                                min      => 0,
                                                                nicename => "Count"});

    my ($show, $moderr) = $self -> validate_options('show', { "required" => 0,
                                                              "default"  => "all",
                                                              "source"   => ["all", "me"]});

    my ($order, $moderr) = $self -> validate_options('order', { "required" => 0,
                                                                "default"  => "age",
                                                                "source"   => ["age", "name"]});

    # Now convert the parameters as needed
    given($show) {
        when('me')  { $show = $self -> {"session"} -> get_session_userid(); } # 'me' mode requires the userid
        default {
            $show = undef;
        }
    }

    given($order) {
        when('name') { $order = "name"; }
        default {
            $order = 'uploaded';
        }
    }


    return $self -> _build_media_selector($mode, $show, $order, $offset, $count);
}


## @method private $ _build_mediaupload_response(void)
# Generate the respose to send back for a mediaupload API request.
#
# @return A hash containing the API response.
sub _build_mediaupload_response {
    my $self = shift;

    if(!$self -> check_permission("upload")) {
        $self -> log("error:medialibrary:permission", "User does not have permission to upload");

        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("MEDIA_PERMISSION_NOUPLOAD")}));
    }

    # User has permission, validate the submission and store it
    $self -> log("debug:medialibrary:upload", "Permission granted, attempting store of uploaded image");

    my ($mode, $moderr) = $self -> validate_options('mode', { "required" => 0,
                                                              "default"  => "media",
                                                              "source"   => ["icon", "media", "thumb", "large"]});

    my ($id, $path, $error) = $self -> _validate_article_file($mode);
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $error}))
        if($error);

    $self -> log("debug:medialibrary:upload", "Store complete, image saved with id $id");
    return { "result" => { "status"  => "saved",
                           "imageid" => $id,
                           "path"    => $path
                         }
           };
}


# ============================================================================
#  Autosave operation API functions

## @method private $ _build_autosave_response()
# Save the contents of the subject, summary, and article text to the current
# user's autosave record. This will replace any autosave data set for the user,
# and return a success response as appropriate.
#
# @return A refrence to a hash containing the API response.
sub _build_autosave_response {
    my $self = shift;
    my $args = {};
    my ($error, $errors);
    my $userid = $self -> {"session"} -> get_session_userid();

    # This should never happen in normal use: the user shouldn't even have been able to get to the compose
    # or edit forms if they don't have compose permission. However, if the API is accessed directly, the
    # permission needs to be checked to be sure.
    if(!$self -> check_permission("compose")) {
        $self -> log("error:autosave:permission", "User does not have permission to autosave (no compose)");

        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_PERM")}));
    }

    # Fetch the parameters.
    ($args -> {"title"}, $error) = $self -> validate_string("comp-title", {"required" => 0,
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_TITLE"),
                                                                           "maxlen"   => 100});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"summary"}, $error) = $self -> validate_string("comp-summ", {"required" => 0,
                                                                            "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SUMMARY"),
                                                                            "minlen"   => 8,
                                                                            "maxlen"   => 240});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("comp-desc", {"required"   => 0,
                                                                              "minlen"     => 8,
                                                                              "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_DESC"),
                                                                              "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                              "allow_tags" => $self -> {"allow_tags"},
                                                                              "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # Give up if there have been any errors
    return $self -> api_errorhash("internal_error", $self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => "{L_COMPOSE_AUTOSAVE_FAIL}",
                                                                                                                    "***errors***"  => $errors}))
        if($errors);

    $self -> {"article"} -> set_autosave($userid, $args -> {"title"}, $args -> {"summary"}, $args -> {"article"})
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));

    return { "result" => {"autosave"  => "available",
                          "timestamp" => time(),
                          "desc"      => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_SAVED", {"***time***" => $self -> {"template"} -> format_time(time())})
                         }
           };
}


## @method private $ _build_autoload_response()
# Load any previously autosaved subject, summary, and article text for the user.
# If the user has no autosave, this will return empty values.
#
# @return A refrence to a hash containing the API response.
sub _build_autoload_response {
    my $self = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    # This should never happen in normal use: the user shouldn't even have been able to get to the compose
    # or edit forms if they don't have compose permission. However, if the API is accessed directly, the
    # permission needs to be checked to be sure.
    if(!$self -> check_permission("compose")) {
        $self -> log("error:autosave:permission", "User does not have permission to autosave (no compose)");

        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_PERM")}));
    }

    my $save = $self -> {"article"} -> get_autosave($userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));

    if($save -> {"id"}) {
        return { "result" => {"autosave"   => "available",
                              "timestamp"  => $save -> {"saved"},
                              "desc"       => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_SAVED", {"***time***" => $self -> {"template"} -> format_time($save -> {"saved"})}),
                              "fields"     => [ {"id" => "comp-title", "content" => $save -> {"subject"} },
                                                {"id" => "comp-summ", "content" => $save -> {"summary"} },
                                                {"id" => "comp-desc", "content" => '<![CDATA['.$save -> {"article"}.']]>' },
                                              ],
                             }
               };
    } else {
        return { "result" => {"autosave" => "none",
                              "desc"     => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_NONE"),
                             }
               };
    }
}


## @method private $ _build_autocheck_response()
# Determine whether the user has a previously saved subject, summary, and article
# text. This will return the timestamp of the last autosave if one has been
# set for the user.
#
# @return A refrence to a hash containing the API response.
sub _build_autocheck_response {
    my $self = shift;
    my $userid = $self -> {"session"} -> get_session_userid();

    # This should never happen in normal use: the user shouldn't even have been able to get to the compose
    # or edit forms if they don't have compose permission. However, if the API is accessed directly, the
    # permission needs to be checked to be sure.
    if(!$self -> check_permission("compose")) {
        $self -> log("error:autosave:permission", "User does not have permission to autosave (no compose)");

        return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_PERM")}));
    }

    my $save = $self -> {"article"} -> get_autosave($userid)
        or return $self -> api_errorhash("internal_error", $self -> {"template"} -> replace_langvar("API_ERROR", {"***error***" => $self -> {"article"} -> errstr()}));

    if($save -> {"id"}) {
        return { "result" => {"autosave"  => "available",
                              "timestamp" => $save -> {"saved"},
                              "desc"      => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_SAVED", {"***time***" => $self -> {"template"} -> format_time($save -> {"saved"})})
                             }
               };
    } else {
        return { "result" => {"autosave"  => "none",
                              "desc"      => $self -> {"template"} -> replace_langvar("COMPOSE_AUTOSAVE_NONE"),
                             }
               };
    }
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

    # Is this an API call, or a normal page operation?
    my $apiop = $self -> is_api_operation();
    if(defined($apiop)) {
        # API call - dispatch to appropriate handler.
        given($apiop) {
            # API operation rcount, requires query string parameters yearid=<id> and matrix=<rid>-<mid>,<rid>-<mid>,...
            when("rcount")     { return $self -> api_response($self -> _build_rcount_response()); }

            # API operations related to autosave
            when("auto.save")  { return $self -> api_response($self -> _build_autosave_response());  }
            when("auto.load")  { return $self -> api_response($self -> _build_autoload_response());  }
            when("auto.check") { return $self -> api_response($self -> _build_autocheck_response()); }

            # API operations related to media handling
            when("media.open")   { return $self -> api_html_response($self -> _build_mediaopen_response()); }
            when("media.upload") { return $self -> api_response($self -> _build_mediaupload_response()); }
            when("media.stream") { return $self -> api_html_response($self -> _build_mediastream_response()); }

            default {
                return $self -> api_response($self -> api_errorhash('bad_op',
                                                                    $self -> {"template"} -> replace_langvar("API_BAD_OP")))
            }
        }
    } else {
        my $userbar = $self -> {"module"} -> load_module("Newsagent::Userbar");
        my $message = $self -> {"template"} -> message_box("{L_APIDIRECT_FAILED_TITLE}",
                                                           "error",
                                                           "{L_APIDIRECT_FAILED_SUMMARY}",
                                                           "{L_APIDIRECT_FAILED_DESC}",
                                                           undef,
                                                           "errorcore",
                                                           [ {"message" => $self -> {"template"} -> replace_langvar("SITE_CONTINUE"),
                                                              "colour"  => "blue",
                                                              "action"  => "location.href='".$self -> build_url(block => "compose", pathinfo => [])."'"} ]);

        return $self -> {"template"} -> load_template("error/general.tem",
                                                      {"***title***"     => "{L_APIDIRECT_FAILED_TITLE}",
                                                       "***message***"   => $message,
                                                       "***extrahead***" => "",
                                                       "***userbar***"   => $userbar -> block_display("{L_APIDIRECT_FAILED_TITLE}"),
                                                      })
    }
}

1;
