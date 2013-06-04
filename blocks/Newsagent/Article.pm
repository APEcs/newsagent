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
package Newsagent::Article;

use strict;
use base qw(Newsagent); # This class extends the Article block class
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

    $self -> {"relops"} = [ {"value" => "visible",
                             "name"  => "{L_COMPOSE_RELNOW}" },
                            {"value" => "timed",
                             "name"  => "{L_COMPOSE_RELTIME}" },
                            {"value" => "draft",
                             "name"  => "{L_COMPOSE_RELNONE}" },
                          ];

    $self -> {"relmodes"} = { "hidden"   => "{L_ALIST_RELHIDDEN}",
                              "visible"  => "{L_ALIST_RELNOW}",
                              "timed"    => "{L_ALIST_RELTIME_WAIT}",
                              "released" => "{L_ALIST_RELTIME_PASSED}",
                              "draft"    => "{L_ALIST_RELNONE}",
                              "edited"   => "{L_ALIST_RELEDIT}",
                              "deleted"  => "{L_ALIST_RELDELETED}",
                            };

    $self -> {"imgops"} = [ {"value" => "none",
                             "name"  => "{L_COMPOSE_IMGNONE}" },
                            {"value" => "url",
                             "name"  => "{L_COMPOSE_IMGURL}" },
                            {"value" => "file",
                             "name"  => "{L_COMPOSE_IMGFILE}" },
                            {"value" => "img",
                             "name"  => "{L_COMPOSE_IMG}" },
                          ];

    $self -> {"allow_tags"} = [
        "a", "b", "blockquote", "br", "caption", "col", "colgroup", "comment",
        "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "ol", "p",
        "pre", "small", "span", "strong", "sub", "sup", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "tt", "ul"
        ];

    $self -> {"tag_rules"} = [
        a => {
            href   => qr{^(?:http|https)://}i,
            name   => 1,
            '*'    => 0,
        },
        table => {
            cellspacing => 1,
            cellpadding => 1,
            style       => 1,
            class       => 1,
            '*'         => 0,
        },
        td => {
            colspan => 1,
            rowspan => 1,
            style   => 1,
            '*'     => 0,
        },
        blockquote => {
            cite  => qr{^(?:http|https)://}i,
            style => 1,
            '*'   => 0,
        },
        span => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
        div => {
            class => 1,
            style => 1,
            title => 1,
            '*'   => 0,
        },
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
# of the possible images attached to an article.
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

    ($args -> {"images"} -> {$imgid} -> {"mode"}, $error) = $self -> validate_options($base."_mode", {"required" => 1,
                                                                                                      "source"   => $self -> {"imgops"},
                                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_".uc($base))});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    given($args -> {"images"} -> {$imgid} -> {"mode"}) {
        # No additional validation needed for the 'none' case, but enumate it for clarity.
        when("none") {
        }

        # URL validation involves checking that the string the user has provided actually looks like a URL
        when("url") { ($args -> {"images"} -> {$imgid} -> {"url"}, $error) = $self -> validate_string($base."_url", {"required"   => 1,
                                                                                                                     "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL"),
                                                                                                                     "formattest" => $self -> {"formats"} -> {"url"},
                                                                                                                     "formatdesc" => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL_DESC"),
                                                                                   });
                      $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }

        # Image validation ("us an existing image") is basically checking that an entry with the corresponding ID is in the database.
        when("img") { ($args -> {"images"} -> {$imgid} -> {"img"}, $error) = $self -> validate_options($base."_img", {"required"   => 1,
                                                                                                                      "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_IMGURL"),
                                                                                                                      "source"     => $self -> {"settings"} -> {"database"} -> {"images"},
                                                                                                                      "where"      => "WHERE `id` = ?"});
                      $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }

        # File upload is more complicated: if the file upload is successful, the image mode is switched to 'img', as
        # at that point the user is using an existing image; it just happens to be the one they uploaded!
        when("file") { ($args -> {"images"} -> {$imgid} -> {"img"}, $error) = $self -> _validate_article_file($base);
                       if($error) {
                           $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
                       } else {
                           $args -> {"images"} -> {$imgid} -> {"mode"} = "img";
                       }
        }
    }

    return $errors;
}


## @method private $ _validate_levels($args, $userid)
# Validate the posting levels submitted by the user.
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_levels {
    my $self    = shift;
    my $args    = shift;
    my $userid  = shift;
    my $userset = {};

    # Get the levels, sites, and which levels the user has access to on each site
    my $sys_levels  = $self -> {"article"} -> get_all_levels();
    my $user_sites  = $self -> {"article"} -> get_user_sites($userid);
    my $user_levels = $self -> {"article"} -> get_user_levels($user_sites, $sys_levels, $userid);

    my @selected = $self -> {"cgi"} -> param("level");

    # Convert the selected array to a hash for faster/easier lookup
    my $hashsel;
    $hashsel -> {$_}++ for(@selected);

    # Check whether the user can post at the selected levels for the selected site
    if($user_levels -> {$args -> {"site"}}) {
        # for each available level, check whether the user has selected it, and if so record that
        # this ensures that, provided $levels only contains levels the user has access to, they
        # can never select a level they can't use.
        foreach my $level (keys(%{$user_levels -> {$args -> {"site"}}})) {
            $userset -> {$level}++
                if($user_levels -> {$args -> {"site"}} -> {$level} && $hashsel -> {$level});
        }
    }
    $args -> {"levels"} = $userset;

    return scalar(keys(%{$userset})) ? undef : $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL_ERRNONE");
}


## @method private $ _validate_article_fields($args, $userid)
# Validate the contents of the fields in the article form. This will validate the
# fields, and perform any background file-wrangling operations necessary to deal
# with the submitted images (if any).
#
# @param args   A reference to a hash to store validated data in.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_article_fields {
    my $self   = shift;
    my $args   = shift;
    my $userid = shift;
    my ($errors, $error) = ("", "");

    ($args -> {"title"}, $error) = $self -> validate_string("title", {"required" => 0,
                                                                      "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_TITLE"),
                                                                      "maxlen"   => 100});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"summary"}, $error) = $self -> validate_string("summary", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SUMMARY"),
                                                                          "minlen"   => 8,
                                                                          "maxlen"   => 240});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("article", {"required"   => 1,
                                                                            "minlen"     => 8,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_DESC"),
                                                                            "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                            "allow_tags" => $self -> {"allow_tags"},
                                                                            "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"site"}, $error) = $self -> validate_options("site", {"required" => 1,
                                                                     "source"   => $self -> {"settings"} -> {"database"} -> {"sites"},
                                                                     "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SITE"),
                                                                     "where"    => "WHERE `name` LIKE ?" });
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # TODO: check user has permission to post from this site.

    # Which release mode is the user using? 0 is default, 1 is batch
    ($args -> {"relmode"}, $error) = $self -> validate_numeric("relmode", {"required" => 1,
                                                                           "default"  => 0,
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELMODE"),
                                                                           "min"      => 0,
                                                                           "max"      => 1});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # Release mode 0 is "standard" release - potentially with timed delay.
    if($args -> {"relmode"} == 0) {
        $error = $self -> _validate_levels($args, $userid);
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

        ($args -> {"mode"}, $error) = $self -> validate_options("mode", {"required" => 1,
                                                                         "default"  => "visible",
                                                                         "source"   => $self -> {"relops"},
                                                                         "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELEASE")});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

        if($args -> {"mode"} eq "timed") {
            ($args -> {"rtimestamp"}, $error) = $self -> validate_numeric("rtimestamp", {"required" => $args -> {"mode"} eq "timed",
                                                                                         "default"  => 0,
                                                                                         "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELDATE")});
            $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }

    # Release mode 1 is "batch" release.
    } elsif($args -> {"relmode"} == 1) {
        # FIXME: validate batch fields
    }

    # Handle images
    $errors .= $self -> _validate_article_image($args, "a");
    $errors .= $self -> _validate_article_image($args, "b");

    return $errors;
}


## @method private $ _validate_article()
# Validate the article data submitted by the user, and potentially add
# a new article to the system. Note that this will not return if the article
# fields validate; it will redirect the user to the new article and exit.
#
# @return An error message, and a reference to a hash containing
#         the fields that passed validation.
sub _validate_article {
    my $self = shift;
    my ($args, $errors, $error) = ({}, "", "");
    my $userid = $self -> {"session"} -> get_session_userid();

    $error = $self -> _validate_article_fields($args, $userid);
    $errors .= $error if($error);

    # Give up here if there are any errors
    return ($self -> {"template"} -> load_template("error/error_list.tem",
                                                   {"***message***" => "{L_COMPOSE_FAILED}",
                                                    "***errors***"  => $errors}), $args)
        if($errors);

    my $aid = $self -> {"article"} -> add_article($args, $self -> {"session"} -> get_session_userid())
        or return ($self -> {"template"} -> load_template("error/error_list.tem",
                                                          {"***message***" => "{L_COMPOSE_FAILED}",
                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                     {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                     })
                                                          }), $args);

    $self -> log("compose", "Added article $aid");

    # redirect to a success page
    # Doing this prevents page reloads adding multiple article copies!
    print $self -> {"cgi"} -> redirect($self -> build_url(block => "compose", pathinfo => ["success"]));
    exit;
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


## @method private $ _build_image_options($levels)
# Generate the level options available in the system.
#
# @param levels A reference to a hash of available levels.
# @return A string containing the level options
sub _build_level_options {
    my $self    = shift;
    my $levels  = shift || {};
    my $options = "";

    foreach my $level (@{$levels}) {
        $options .= $self -> {"template"} -> load_template("compose/levelop.tem", {"***desc***"    => $level -> {"name"},
                                                                                   "***value***"   => $level -> {"value"},
                                                                                   "***checked***" => ""
                                                           });
    }

    return $options;
}


## @method private $ _build_site_levels($user_levels, $levels)
# Generate a block of javascript that can be used to control the levels available to
# users for each site they have access to.
#
# @param user_levels A hash generated by get_user_levels() that controls which levels
#                    the user can post at for each site.
# @param levels      A hash containing the currently selected levels for the current
#                    site
# @return A string containing the javascript to embed in the page
sub _build_site_levels {
    my $self        = shift;
    my $user_levels = shift;
    my $levels      = shift;
    my $incantation = "site_levels = {\n";

    foreach my $site (keys(%{$user_levels})) {
        $incantation .= "    \"$site\": { ";
        foreach my $level (keys(%{$user_levels -> {$site}})) {
            $incantation .= "\"$level\": ".$user_levels -> {$site} -> {$level}.", ";
        }
        $incantation .= "},\n";
    }

    return $incantation."};\n";
}


1;
