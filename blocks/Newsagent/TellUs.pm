## @file
# This file contains the implementation of the Tell Us base class.
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
package Newsagent::TellUs;

use strict;
use base qw(Newsagent); # This class extends the Newsagent block class
use Newsagent::System::TellUs;
use v5.12;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Article, loads the System::Article model
# and other classes required to generate article pages.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Article object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"tellus"} = Newsagent::System::TellUs -> new(dbh      => $self -> {"dbh"},
                                                           settings => $self -> {"settings"},
                                                           logger   => $self -> {"logger"},
                                                           roles    => $self -> {"system"} -> {"roles"},
                                                           metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("TellUs initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"state"} = [ {"value" => "new",
                            "name"  => "{L_TELLUS_NEW}" },
                           {"value" => "viewed",
                            "name"  => "{L_TELLUS_VIEWED}" },
                           {"value" => "rejected",
                            "name"  => "{L_TELLUS_REJECTED}" },
        ];

    $self -> {"allow_tags"} = [
        "a", "b", "blockquote", "br", "caption", "col", "colgroup", "comment",
        "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "li", "ol", "p",
        "pre", "small", "span", "strong", "sub", "sup", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "tt", "ul",
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
        img => {
            src    => 1,
            class  => 1,
            alt    => 1,
            width  => 1,
            height => 1,
            style  => 1,
            title  => 1,
            '*'    => 0,
        },
        ];

    return $self;
}


# ============================================================================
#  Validation code


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

    my $queues = $self -> {"tellus"} -> get_queues($userid, "additem");
    my $types  = $self -> {"tellus"} -> get_types();

    ($args -> {"article"}, $error) = $self -> validate_htmlarea("article", {"required"   => 1,
                                                                            "minlen"     => 8,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("TELLUS_DESC"),
                                                                            "validate"   => $self -> {"config"} -> {"Core:validate_htmlarea"},
                                                                            "allow_tags" => $self -> {"allow_tags"},
                                                                            "tag_rules"  => $self -> {"tag_rules"}});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"type"}, $error) = $self -> validate_options("type", {"required" => 1,
                                                                     "default"  => "1",
                                                                     "source"   => $types,
                                                                     "nicename" => $self -> {"template"} -> replace_langvar("TELLUS_TYPE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

    ($args -> {"queue"}, $error) = $self -> validate_options("queue", {"required" => 1,
                                                                       "default"  => "1",
                                                                       "source"   => $queues,
                                                                       "nicename" => $self -> {"template"} -> replace_langvar("TELLUS_QUEUE")});
    $errors .= $self -> {"template"} -> load_template("error/error_item.tem", {"***error***" => $error}) if($error);

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

    $error = $self -> _validate_article_fields($args, $userid);
    $errors .= $error if($error);

    # Give up here if there are any errors
    return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => "{L_TELLUS_FAILED}",
                                                                            "***errors***"  => $errors}), $args)
        if($errors);

    my $aid = $self -> {"tellus"} -> add_article($args, $userid)
        or return ($self -> {"template"} -> load_template("error/error_list.tem", {"***message***" => "{L_TELLUS_FAILED}",
                                                                                   "***errors***"  => $self -> {"template"} -> load_template("error/error_item.tem",
                                                                                                                                             {"***error***" => $self -> {"tellus"} -> errstr()
                                                                                                                                             })
                                                          }), $args);


    $self -> log("article", "Added tellus article $aid");

    # Send notifications to queue notification targets

    # redirect to a success page
    # Doing this prevents page reloads adding multiple article copies!
    print $self -> {"cgi"} -> redirect($self -> build_url(pathinfo => ["success"]));
    exit;
}

1;
