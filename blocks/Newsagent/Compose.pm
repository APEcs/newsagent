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
package Newsagent::Compose;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use File::Basename;
use v5.12;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Compose facility, loads the System::Article model
# and other classes required to generate the compose pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Compose object on success, undef on error.
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
        or return SystemModule::set_error("Compose initialisation failed: ".$SystemModule::errstr);

    $self -> {"relops"} = [ {"value" => "now",
                             "name"  => "{L_COMPOSE_RELNOW}" },
                            {"value" => "timed",
                             "name"  => "{L_COMPOSE_RELTIME}" },
                            {"value" => "draft",
                             "name"  => "{L_COMPOSE_RELNONE}" },
                          ];

    $self -> {"imgops"} = [ {"value" => "none",
                             "name"  => "{L_COMPOSE_IMGNONE}" },
                            {"value" => "url",
                             "name"  => "{L_COMPOSE_IMGURL}" },
                            {"value" => "file",
                             "name"  => "{L_COMPOSE_IMGFILE}" },
                            {"value" => "img",
                             "name"  => "{L_COMPOSE_IMG}" },
                          ];
    return $self;
}


# ============================================================================
#  Validation code

## @method @ _validate_article_file($base)
# Determine whether the file submitted for the specified image submission field is
# valid, and copy it into the image filestore if needed.
#
# @param base The base name of the image submission field.
# @return Two values: the image id on success, undef on error, and an error message
#         if needed.
sub _validate_article_file {
    my $self = shift;
    my $base = shift;

    my $filename = $self -> {"cgi"} -> param($base."_file");
    return (undef, $self -> {"template"} -> replace_langvar("COMPOSE_IMGFILE_ERRNOFILE", {"***field***" => "{L_COMPOSE_".uc($base)."}"}))
        if(!$filename);

    my $tmpfile = $self -> {"cgi"} -> tmpFileName($filename)
        or return (undef, $self -> {"template"} -> replace_langvar("COMPOSE_IMGFILE_ERRNOTMP", {"***field***" => "{L_COMPOSE_".uc($base)."}"}));

    my ($name, $path, $extension) = fileparse($filename, '\..*');
    $filename = $name.$extension;
    $filename =~ tr/ /_/;
    $filename =~ s/[^a-zA-Z0-9_.-]//g;

    # By the time this returns, either the file has been copied into the filestore and the
    # database updated with the file details, or an error has occurred.
    my $imgdata = $self -> {"article"} -> store_image($tmpfile, $filename, $self -> {"session"} -> get_session_userid())
        or return (undef, $self -> {"article"} -> errstr());

    # All that _validate_article_image() needs is the new ID
    return ($imgdata -> {"id"}, undef);
}


## @method private $ _validate_article_image($args, $imgid)
# Validate the image field for an article. This checks the values set for one
# of th epossible images attached to an article.
#
# @param args  A reference to a hash to store validated data in.
# @param imgid The id of the image fields to check, should be 'a' or 'b'
# @return empty string on succss, otherwise an error string.
sub _validate_article_image {
    my $self  = shift;
    my $args  = shift;
    my $imgid = shift;
    my ($errors, $error) = ("", "");

    my $base = "image$imgid";

    ($args -> {$base."_mode"}, $error) = $self -> validate_options($base."_mode", {"required" => 1,
                                                                                   "source"   => $self -> {"imgops"},
                                                                                   "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_".uc($base))});
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    given($args -> {$base."_mode"}) {
        # No additional validation needed for the 'none' case, but enumate it for clarity.
        when("none") {
        }

        # URL validation involves checking that the string the user has provided actually looks like a URL
        when("url") { ($args -> {$base."_url"}, $error) = $self -> validate_string($base."_url", {"required"   => 1,
                                                                                                  "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL"),
                                                                                                  "formattest" => $self -> {"formats"} -> {"url"},
                                                                                                  "formatdesc" => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL_DESC"),
                                                                                   });
                      $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);
        }

        # Image validation ("us an existing image") is basically checking that an entry with the corresponding ID is in the database.
        when("img") { ($args -> {$base."_img"}, $error) = $self -> validate_options($base."_img", {"required"   => 1,
                                                                                                   "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL"),
                                                                                                   "source"     => $self -> {"settings"} -> {"database"} -> {"images"},
                                                                                                   "where"      => "WHERE `id` = ?"});
                      $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);
        }

        # File upload is more complicated: if the file upload is successful, the image mode is switched to 'img', as
        # at that point the user is using an existing image; it just happens to be the one they uploaded!
        when("file") { ($args -> {$base."_img"}, $error) = $self -> _validate_article_file($base);
                       if($error) {
                           $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);
                       } else {
                           $args -> {$base."_mode"} = "img";
                       }
        }
    }

    return $errors;
}


## @method private $ _validate_article_fields($args)
# Validate the contents of the fields in the article form. This will validate the
# fields, and perform any background file-wrangling operations necessary to deal
# with the submitted images (if any).
#
# @param args  A reference to a hash to store validated data in.
# @return empty string on success, otherwise an error string.
sub _validate_article_fields {
    my $self        = shift;
    my $args        = shift;
    my ($errors, $error) = ("", "");

    ($args -> {"title"}, $error) = $self -> validate_string("title", {"required" => 0,
                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_TITLE"),
                                                                      "maxlen"   => 100});
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"summary"}, $error) = $self -> validate_string("summary", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SUMMARY"),
                                                                          "minlen"   => 8,
                                                                          "maxlen"   => 100});
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("article", {"required" => 1,
                                                                            "minlen"   => 8,
                                                                            "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_DESC"),
                                                                            "validate" => $self -> {"config"} -> {"Core:validate_htmlarea"}});
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"site"}, $error) = $self -> validate_options("site", {"required" => 1,
                                                                     "source"   => $self -> {"settings"} -> {"database"} -> {"sites"},
                                                                     "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SITE"),
                                                                     "where"    => "WHERE `name` LIKE ?" });
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    # Which release mode is the user using? 0 is default, 1 is batch
    ($args -> {"relmode"}, $error) = $self -> validate_numeric("relmode", {"required" => 1,
                                                                           "default"  => 0,
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELMODE"),
                                                                           "min"      => 0,
                                                                           "max"      => 1});
    $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    # Release mode 0 is "standard" release - potentially with timed delay.
    if($args -> {"relmode"} == 0) {
        ($args -> {"level"}, $error) = $self -> validate_options("level", {"required" => 1,
                                                                           "source"   => $self -> {"settings"} -> {"database"} -> {"levels"},
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL"),
                                                                           "where"    => "WHERE `level` LIKE ?" });
        $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

        ($args -> {"mode"}, $error) = $self -> validate_options("mode", {"required" => 1,
                                                                         "source"   => $self -> {"relops"},
                                                                         "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELEASE")});
        $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

        ($args -> {"rtimestamp"}, $error) = $self -> validate_numeric("rtimestamp", {"required" => $args -> {"mode"} eq "timed",
                                                                                     "default"  => 0,
                                                                                     "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELDATE")});
        $errors .= $self -> {"template"} -> load_template("error_item.tem", {"***error***" => $error}) if($error);

    # Release mode 1 is "batch" release.
    } elsif($args -> {"relmode"} == 1) {
        # FIXME: validate batch fields
    }

    # Handle images
    $errors .= $self -> _validate_article_image($args, "a");
    $errors .= $self -> _validate_article_image($args, "b");

    return $errors;
}


# ============================================================================
#  Form generators

## @method private $ _build_image_options($selected)
# Generate a string containing the options to provide for image selection.
#
# @param selected The selected image option, defaults to 'none', must be one of
#                 'none', 'url', 'file', or 'img'
# @return A string containing the image mode options
sub _build_image_options {
    my $self     = shift;
    my $selected = shift;

    $selected = "none"
        unless($selected && ($selected eq "url" || $selected eq "file" || $selected eq "img"));

    return $self -> {"template"} -> build_optionlist($self -> {"imgops"}, $selected);
}


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

    # Work out where the user can post from and the levels they can use
    my $levels = $self -> {"template"} -> build_optionlist($self -> {"article"} -> get_user_levels($userid), $args -> {"level"});
    my $sites  = $self -> {"template"} -> build_optionlist($self -> {"article"} -> get_user_sites($userid) , $args -> {"site"});

    # Release timing options
    my $relops = $self -> {"template"} -> build_optionlist($self -> {"relops"}, $args -> {"mode"});
    my $format_release = $self -> {"template"} -> format_time($args -> {"rtimestamp"}, "%d/%m/%Y %H:%M")
        if($args -> {"rtimestamp"});

    # Image options
    my $imagea_opts = $self -> _build_image_options($args -> {"imagea_mode"});
    my $imageb_opts = $self -> _build_image_options($args -> {"imageb_mode"});

    # Pre-existing image options
    my $fileimages = $self -> {"article"} -> get_file_images();
    my $imagea_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"imagea_img"});
    my $imageb_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"imageb_img"});

    # Wrap the error in an error box, if needed.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar("COMPOSE_FORM_TITLE"),
            $self -> {"template"} -> load_template("compose/compose.tem", {"***errorbox***"         => $error,
                                                                           "***form_url***"         => $self -> build_url(block => "article", pathinfo => ["add"]),
                                                                           "***title***"            => $args -> {"title"},
                                                                           "***summary***"          => $args -> {"summary"},
                                                                           "***article***"          => $args -> {"article"},
                                                                           "***allowed_sites***"    => $sites,
                                                                           "***allowed_levels***"   => $levels,
                                                                           "***release_mode***"     => $relops,
                                                                           "***release_date_fmt***" => $format_release,
                                                                           "***rtimestamp***"       => $args -> {"rtimestamp"},
                                                                           "***imageaopts***"       => $imagea_opts,
                                                                           "***imagebopts***"       => $imageb_opts,
                                                                           "***imagea_url***"       => $args -> {"imagea_url"} || "https://",
                                                                           "***imageb_url***"       => $args -> {"imageb_url"} || "https://",
                                                                           "***imageaimgs***"       => $imagea_img,
                                                                           "***imagebimgs***"       => $imageb_img,
                                                                           "***relmode***"          => $args -> {"relmode"} || 0,
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
                when("add")  { ($title, $content, $extrahead) = $self -> _add_article(); }
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
