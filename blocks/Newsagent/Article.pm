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
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::Article;
use File::Basename;
use Lingua::EN::Sentence qw(get_sentences);
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
        or return Webperl::SystemModule::set_error("Compose initialisation failed: ".$SystemModule::errstr);

    # Load the notification method modules, as they may be needed for content generation,
    # validation, and miscellaneous other tasks of dubious import.
    $self -> _load_notification_method_modules()
        or return Webperl::SystemModule::set_error($self -> errstr());

    $self -> {"schedrelops"} = [ {"value" => "next",
                                  "name"  => "{L_COMPOSE_RELNEXT}" },
                                 {"value" => "after",
                                  "name"  => "{L_COMPOSE_RELAFTER}" },
                                 {"value" => "draft",
                                  "name"  => "{L_COMPOSE_RELNONE}" },
                               ];

    $self -> {"relops"} = [ {"value" => "visible",
                             "name"  => "{L_COMPOSE_RELNOW}" },
                            {"value" => "timed",
                             "name"  => "{L_COMPOSE_RELTIME}" },
                            {"value" => "draft",
                             "name"  => "{L_COMPOSE_RELNONE}" },
                            {"value" => "preset",
                             "name"  => "{L_COMPOSE_RELPRESET}" },
        ];

    $self -> {"stickyops"} = [ {"value" => "0",
                                "name"  => "{L_COMPOSE_NOTSTICKY}" },
                               {"value" => "1",
                                "name"  => "{L_COMPOSE_STICKYDAYS1}" },
                               {"value" => "2",
                                "name"  => "{L_COMPOSE_STICKYDAYS2}" },
                               {"value" => "3",
                                "name"  => "{L_COMPOSE_STICKYDAYS3}" },
                               {"value" => "4",
                                "name"  => "{L_COMPOSE_STICKYDAYS4}" },
                               {"value" => "5",
                                "name"  => "{L_COMPOSE_STICKYDAYS5}" },
                               {"value" => "6",
                                "name"  => "{L_COMPOSE_STICKYDAYS6}" },
                               {"value" => "7",
                                "name"  => "{L_COMPOSE_STICKYDAYS7}" },
                          ];

    $self -> {"relmodes"} = { "hidden"   => "{L_ALIST_RELHIDDEN}",
                              "visible"  => "{L_ALIST_RELNOW}",
                              "timed"    => "{L_ALIST_RELTIME_WAIT}",
                              "released" => "{L_ALIST_RELTIME_PASSED}",
                              "draft"    => "{L_ALIST_RELNONE}",
                              "edited"   => "{L_ALIST_RELEDIT}",
                              "deleted"  => "{L_ALIST_RELDELETED}",
                              "preset"   => "{L_ALIST_RELTEMPLATE}",
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


## @method private $ _validate_feeds_levels($args, $userid)
# Validate the selected feeds and posting levels submitted by the user.
#
# @param args   A reference to a hash to store validated data in. This will populate two
#               entries in the hash: `levels` is a reference to a hash, one element per
#               selected level, with the value set to the number of times the level was
#               selected; `feeds` contains a reference to a list of feed IDs selected.
# @param userid The ID of the user submitting the form.
# @return empty string on success, otherwise an error string.
sub _validate_feeds_levels {
    my $self    = shift;
    my $args    = shift;
    my $userid  = shift;
    my $userset = {};

    # Get the levels, feeds, and which levels the user has access to on each feed
    my $sys_levels  = $self -> {"article"} -> get_all_levels();
    my $user_feeds  = $self -> {"article"} -> get_user_feeds($userid, $sys_levels);
    my $user_levels = $self -> {"article"} -> get_user_levels($user_feeds, $sys_levels, $userid);

    # Fetch the list of selected feeds and levels
    my @set_feeds  = $self -> {"cgi"} -> param("feed");  # A list of selected feed IDs
    my @set_levels = $self -> {"cgi"} -> param("level"); # A list of selected level names ("home", "leader", etc)

    # Convert the arrays to a hash for faster/easier lookup
    my %feed_hash  = map { $_ => $_ } @set_feeds;
    my %level_hash = map { $_ => $_ } @set_levels;

    # First go through the feeds the user has turned on, and build a hash of levels
    # that represent the *minimum* available set of permissions
    my %avail_levels = map { $_ -> {"value"} => 1 } @{$sys_levels};
    foreach my $user_feed (@{$user_feeds}) {

        # Has the user enabled this feed?
        if($feed_hash{$user_feed -> {"id"}}) {

            # Yes, deactivate any levels the user does not have access to for this feed
            foreach my $level (keys(%avail_levels)) {
                $avail_levels{$level} = 0
                    unless($user_levels -> {$user_feed -> {"id"}} -> {$level});
            }
        }
    }

    # At this point $avail_levels contains 0 or 1 for each level defined in the system:
    # - if the user can post to ALL selected feed at a given level, $avail_levels contains 1 for that level
    # - if the user has selected ANY feed that they can not post to at a given level, $avail_levels contains 0 for that level.
    # Essentially, $avail_levels is the intersection of available levels for the user for the selected feeds.

    # How many levels are left? Is the user able to post the article at all?
    my $count = 0;
    foreach my $level (keys %avail_levels) {
        $count += $avail_levels{$level};
    }
    # If there are no levels left, exit with an error
    return $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL_ERRNOCOMMON") unless($count);

    # Now check the levels the user has selected against the available levels
    $args -> {"levels"} = {};
    foreach my $level (keys %avail_levels) {
        # Skip levels that are not enabled, or selected by the user
        next if(!$avail_levels{$level} || !$level_hash{$level});

        $args -> {"levels"} -> {$level}++
    }

    # If the user has not selected any levels, or the selected ones have been rejected, error out.
    return $self -> {"template"} -> replace_langvar("COMPOSE_LEVEL_ERRNONE") if(!scalar(keys(%{$args -> {"levels"}})));

    # Go through the available feeds for the user, and if the user has enabled the feed
    # make sure thay they can post the selected levels to that feed
    $args -> {"feeds"}  = [];
    foreach my $user_feed (@{$user_feeds}) {

        # Has the user enabled this feed?
        if($feed_hash{$user_feed -> {"id"}}) {

            # Yes, store the feed ID. Note that this is safe at this point as the above code has already
            # checked that the user has permission to post to this feed at a selected level.
            push(@{$args -> {"feeds"}}, $user_feed -> {"id"});
        }
    }

    # No levels selected?
    return scalar(@{$args -> {"feeds"}}) ? undef : $self -> {"template"} -> replace_langvar("COMPOSE_FEED_ERRNONE");
}


## @method private $ _validate_summary_text($args)
# Determine whether the summary and article texts are valid.
#
# @param args A reference to a hash to store validated data in.
# @return empty string on success, otherwise an error string.
sub _validate_summary_text {
    my $self = shift;
    my $args = shift;

    my $nohtml = $args -> {"article"} ? $self -> {"template"} -> html_strip($args -> {"article"}) : "";

    # Got both summary and article text? Nothing to do, then...
    if($args -> {"summary"} && $nohtml) {
        return undef;

    # If there's a summary, and no article text, copy the summary over
    } elsif($args -> {"summary"} && !$nohtml) {
        $args -> {"article"} = "<p>".$args -> {"summary"}."</p>";
        return undef;

    # If there's an article text, but no summary, copy over the first <240 chars
    } elsif(!$args -> {"summary"} && $nohtml) {
        $args -> {"summary"} = $self -> _truncate_article($nohtml, 240);
        return undef;
    }

    # Last possible case: no summary or article text - complain about it.
    return "{L_COMPOSE_ERR_NOSUMMARYARTICLE}";
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

    ($args -> {"summary"}, $error) = $self -> validate_string("summary", {"required" => 0,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_SUMMARY"),
                                                                          "minlen"   => 8,
                                                                          "maxlen"   => 240});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("article", {"required"   => 0,
                                                                            "minlen"     => 8,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("COMPOSE_DESC"),
                                                                            "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                            "allow_tags" => $self -> {"allow_tags"},
                                                                            "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # sort out the summary/full text
    $error = $self -> _validate_summary_text($args);
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);


    $args -> {"minor_edit"} = $self -> {"cgi"} -> param("minor_edit") ? 1 : 0;

    my $sys_levels = $self -> {"article"} -> get_all_levels();

    # Which release mode is the user using? 0 is default, 1 is batch
    ($args -> {"relmode"}, $error) = $self -> validate_numeric("relmode", {"required" => 1,
                                                                           "default"  => 0,
                                                                           "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_RELMODE"),
                                                                           "min"      => 0,
                                                                           "max"      => 1});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # Release mode 0 is "standard" release - potentially with timed delay.
    if($args -> {"relmode"} == 0) {

        # Get the list of feeds the user has selected and has access to
        $error = $self -> _validate_feeds_levels($args, $userid);
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
        } elsif($args -> {"mode"} eq "preset") {
            ($args -> {"preset"}, $error) = $self -> validate_string("preset", {"required" => 1,
                                                                                "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_PRESETNAME"),
                                                                                "minlen"   => 8,
                                                                                "maxlen"   => 80});
            $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }

        ($args -> {"sticky"}, $error) = $self -> validate_options("sticky", {"required" => 0,
                                                                             "source"   => $self -> {"stickyops"},
                                                                             "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_STICKY")});
        $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    # Release mode 1 is "batch" release.
    } elsif($args -> {"relmode"} == 1) {
        # FIXME: validate batch fields
    }

    # Handle confirmation suppression
    $args -> {"noconfirm"} = 1
        if($self -> {"cgi"} -> param('stopconfirm'));

    # Handle images
    $errors .= $self -> _validate_article_image($args, "a");
    $errors .= $self -> _validate_article_image($args, "b");

    return $errors;
}


## @method private $ _validate_article($articleid)
# Validate the article data submitted by the user, and potentially add
# a new article to the system. Note that this will not return if the article
# fields validate; it will redirect the user to the new article and exit.
#
# @param articleid Optional article ID used when doing edits. Note that the
#                  caller must ensure this ID is valid and the user can edit it.
# @return An error message, and a reference to a hash containing
#         the fields that passed validation.
sub _validate_article {
    my $self      = shift;
    my $articleid = shift;
    my ($args, $errors, $error) = ({}, "", "", undef);
    my $userid = $self -> {"session"} -> get_session_userid();

    my $failmode = $articleid ? "{L_EDIT_FAILED}" : "{L_COMPOSE_FAILED}";

    $error = $self -> _validate_article_fields($args, $userid);
    $errors .= $error if($error);

    my $matrix = $self -> {"module"} -> load_module("Newsagent::Notification::Matrix");

    # Only bother checking notification code if the release mode is "standard". "Batch" handles its
    # notification code separately.
    if($args -> {"relmode"} == 0) {
         $args -> {"notify_matrix"} = $matrix -> get_used_methods($userid)
            or $errors .= $self -> {"template"} -> load_template("error/error_item.tem", { "***error***" => $matrix -> errstr()});

        if($args -> {"notify_matrix"} && $args -> {"notify_matrix"} -> {"used_methods"} && scalar(keys(%{$args -> {"notify_matrix"} -> {"used_methods"}}))) {
            # Call each notifocation method to let it validate and add its data to the args hash
            foreach my $method (keys(%{$self -> {"notify_methods"}})) {
                next unless($args -> {"notify_matrix"} -> {"used_methods"} -> {$method} &&
                            scalar(@{$args -> {"notify_matrix"} -> {"used_methods"} -> {$method}}));

                my $meth_errs = $self -> {"notify_methods"} -> {$method} -> validate_article($args, $userid);

                # If the validator returned any errors, add them to the list.
                foreach $error (@{$meth_errs}) {
                    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", { "***error***" => $error });
                }
            }

            # Get the year here, too - technically it's part of the notificiation matrix, but
            # shoving this in get_used_methods() is a bit manky
            my $years = $self -> {"system"} -> {"userdata"} -> get_valid_years(1);
            ($args -> {"notify_matrix"} -> {"year"}, $error) = $self -> validate_options("acyear", {"required" => 1,
                                                                                                    "source"   => $years,
                                                                                                    "nicename" => $self -> {"template"} -> replace_langvar("COMPOSE_ACYEAR")});
            $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);
        }
    }

    # Give up here if there are any errors
    return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                            "***errors***"  => $errors}), $args)
        if($errors);

    # If an articleid has been specified, this is an edit - update the status of the previous article
    if($articleid) {
        my $article = $self -> {"article"} -> get_article($articleid)
            or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                       "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                 {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                                 })
                                                              }), $args);

        # Do not update the preset status, unless the new and old preset names match
        if($article -> {"release_mode"} ne "preset" ||
           ($article -> {"preset"} && $args -> {"preset"} && lc($article -> {"preset"}) eq lc($args -> {"preset"}))) {
            $self -> {"article"} -> set_article_status($articleid, $userid, "edited", $article -> {"release_mode"} eq "timed")
                or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                     {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                                     })
                                                                  }), $args);
        }

        # Do not bother cancelling notifications for draft or preset
        if($article -> {"release_mode"} ne "draft" && $article -> {"release_mode"} ne "preset") {
            foreach my $method (keys(%{$self -> {"notify_methods"}})) {
                $self -> {"notify_methods"} -> {$method} -> cancel_notifications($articleid)
                    or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                               "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                         {"***error***" => $self -> {"notify_methods"} -> {$method} -> errstr()
                                                                                                                                                         })
                                                                      }), $args);
            }
        }

        if($args -> {"minor_edit"}) {
            $args -> {"rtimestamp"} = $article -> {"release_time"};
        }
    }

    my $aid = $self -> {"article"} -> add_article($args, $userid, $articleid)
        or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                   "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                             {"***error***" => $self -> {"article"} -> errstr()
                                                                                                                                             })
                                                          }), $args);

    $self -> log("article", "Added article $aid");

    # Let notification modules store any data they need
    if($args -> {"relmode"} == 0) {
        my $isdraft = ($args -> {"mode"} eq "draft" || $args -> {"mode"} eq "preset");

        foreach my $method (keys(%{$args -> {"notify_matrix"} -> {"used_methods"}})) {
            $self -> {"notify_methods"} -> {$method} -> store_article($args, $userid, $aid, $isdraft, $args -> {"notify_matrix"} -> {"used_methods"} -> {$method})
                or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => $failmode,
                                                                                           "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                                     {"***error***" => $self -> {"notify_methods"} -> {$method} -> errstr()
                                                                                                                                                     })
                                                                  }), $args);

        }
    }

    # If the user has stopped confirmations, set the flag here
    $self -> {"session"} -> {"auth"} -> {"app"} -> set_user_setting($userid, "disable_confirm", 1)
        if($args -> {"noconfirm"});

    # redirect to a success page
    # Doing this prevents page reloads adding multiple article copies!
    print $self -> {"cgi"} -> redirect($self -> build_url(pathinfo => ["success"]));
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


## @method private $ _build_image_options($levels, $setlevels)
# Generate the level options available in the system.
#
# @param levels    A reference to a hash of available levels.
# @param setlevels A reference to a hash of levels selected.
# @return A string containing the level options
sub _build_level_options {
    my $self      = shift;
    my $levels    = shift || {};
    my $setlevels = shift || {};
    my $options   = "";

    foreach my $level (@{$levels}) {
        my $checked = $setlevels -> {$level -> {"value"}} ? " checked=\"checked\"": "";

        $options .= $self -> {"template"} -> load_template("compose/levelop.tem", {"***desc***"    => $level -> {"name"},
                                                                                   "***value***"   => $level -> {"value"},
                                                                                   "***checked***" => $checked,
                                                           });
    }

    return $options;
}


## @method private $ _build_feedlist($feeds, $selected)
# Generate a series of checkboxes for each feed specified in the provided array
#
# @param feeds    A reference to an array of feed data hashrefs
# @param selected A reference to a hash pf selected feeds
# @return A string containing the checkboxes for the available feeds.
sub _build_feedlist {
    my $self     = shift;
    my $feeds    = shift;
    my $selected = shift;
    my $result   = "";

    my %active_feeds = map { $_ => $_} @{$selected};

    foreach my $feed (@{$feeds}) {
        $result .= $self -> {"template"} -> load_template("compose/feed-item.tem", {"***name***"    => $feed -> {"value"},
                                                                                    "***id***"      => $feed -> {"id"},
                                                                                    "***desc***"    => $feed -> {"name"},
                                                                                    "***checked***" => $active_feeds{$feed -> {"id"}} ? 'checked="checked"' : ''});
    }

    return $result;
}


## @method private $ _build_feed_levels($user_levels, $levels)
# Generate a block of javascript that can be used to control the levels available to
# users for each feed they have access to.
#
# @param user_levels A hash generated by get_user_levels() that controls which levels
#                    the user can post at for each feed.
# @param levels      A hash containing the currently selected levels for the current
#                    feed
# @return A string containing the javascript to embed in the page
sub _build_feed_levels {
    my $self        = shift;
    my $user_levels = shift;
    my $levels      = shift;
    my $incantation = "feed_levels = {\n";

    foreach my $feed (keys(%{$user_levels})) {
        $incantation .= "    \"$feed\": { ";
        foreach my $level (keys(%{$user_levels -> {$feed}})) {
            $incantation .= "\"$level\": ".$user_levels -> {$feed} -> {$level}.", ";
        }
        $incantation .= "},\n";
    }

    return $incantation."};\n";
}


## @method private $ _build_levels_jsdata($levels)
# Given an array of level descriptions hashrefs, create an array of level names that
# the level autoselector javascript can use.
#
# @param levels A reference to an array of level hashrefs.
# @return A string to use in the page as the level array.
sub _build_levels_jsdata {
    my $self   = shift;
    my $levels = shift;
    my @names;

    foreach my $level (@{$levels}) {
        push(@names, '"'.$level -> {"value"}.'"');
    }

    my $array = "level_list = new Array(".join(",", @names).");";
}



# ============================================================================
#  Things of which Man was Not Meant To Know (also support code)


## @method private $ _load_notification_method_modules()
# Attempt to load all defined notification method modules and store them
# in the $self -> {"notify_methods"} hash reference.
#
# @return true on succes, undef on error
sub _load_notification_method_modules {
    my $self = shift;

    $self -> clear_error();

    my $modlisth = $self -> {"dbh"} -> prepare("SELECT meths.id, meths.name, mods.perl_module
                                                FROM `".$self -> {"settings"} -> {"database"} -> {"modules"}."` AS mods,
                                                     `".$self -> {"settings"} -> {"database"} -> {"notify_methods"}."` AS meths
                                                WHERE mods.module_id = meths.module_id
                                                AND mods.active = 1");
    $modlisth -> execute()
        or return $self -> self_error("Unable to execute notification module lookup: ".$self -> {"dbh"} -> errstr);

    while(my $modrow = $modlisth -> fetchrow_hashref()) {
        my $module = $self -> {"module"} -> load_module($modrow -> {"perl_module"}, "method_id" => $modrow -> {"id"},
                                                                                    "method_name" => $modrow -> {"name"})
            or return $self -> self_error("Unable to load notification module '".$modrow -> {"name"}."': ".$self -> {"module"} -> errstr());

        $self -> {"notify_methods"} -> {$modrow -> {"name"}} = $module;
    }

    return 1;
}


## @method private $ _truncate_article($text, $limit)
# Given an article string containing plain text (NOT HTML!), produce a string
# that can be used as a summary. This truncates the specified text to the
# nearest sentence boundary less than the specified limit.
#
# @param text The text to truncate to a sentence boundary less than the limit.
# @param limit The number of characters the output may contain
# @return A string containing the truncated text
sub _truncate_article {
    my $self  = shift;
    my $text  = shift;
    my $limit = shift;

    # If the text fits in the limit, just return it
    return $text
        if(length($text) <= $limit);

    # Otherwise, split into sentences and stick sentences together until the limit
    my $sentences = get_sentences($text);
    my $trunc = "";
    for(my $i = 0; $i < scalar(@{$sentences}) && (length($trunc) + length($sentences -> [$i])) <= $limit; ++$i) {
        $trunc .= $sentences -> [$i];
    }

    # If the first sentence was too long (trunc is empty), truncate to word boundaries instead
    $trunc = $self -> {"template"} -> truncate_words($text, $limit)
        if(!$trunc);

    return $trunc;
}

1;
