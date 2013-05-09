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
#  Form generators


## @method $ build_image_options($selected)
# Generate a string containing the options to provide for image selection.
#
# @param selected The selected image option, defaults to 'none', must be one of
#                 'none', 'url', 'file', or 'img'
# @return A string containing the image mode options
sub build_image_options {
    my $self     = shift;
    my $selected = shift;

    $selected = "none"
        unless($selected eq "url" || $selected eq "file" || $selected eq "img");

    return $self -> {"template"} -> build_optionlist($self -> {"imgops"}, $selected);
}


## @method @ generate_compose($args, $error)
# Generate the page content for a compose page.
#
# @param args  An optional reference to a hash containing defaults for the form fields.
# @param error An optional error message to display above the form if needed.
# @return Two strings, the first containing the page title, the second containing the
#         page content.
sub generate_compose {
    my $self  = shift;
    my $args  = shift || { };
    my $error = shift;

    my $userid = $self -> {"session"} -> get_session_userid();

    # Work out where the user can post from and the levels they can use
    my $levels = $self -> {"template"} -> build_optionlist($self -> {"article"} -> get_user_levels($userid), $args -> {"level"});
    my $sites  = $self -> {"template"} -> build_optionlist($self -> {"article"} -> get_user_sites($userid) , $args -> {"site"});

    # Release timing options
    my $relops = $self -> {"template"} -> build_optionlist($self -> {"relops"}, $args -> {"mode"});

    # Image options
    my $imagea_opts = $self -> build_image_options($args -> {"imagea_mode"});
    my $imageb_opts = $self -> build_image_options($args -> {"imageb_mode"});

    my $fileimages = $self -> {"article"} -> get_file_images();
    my $imagea_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"imagea_img"});
    my $imageb_img = $self -> {"template"} -> build_optionlist($fileimages, $args -> {"imageb_img"});

    my $format_release = $self -> {"template"} -> format_time($args -> {"rtimestamp"}, "%d/%m/%Y %H:%M")
        if($args -> {"rtimestamp"});

    # Wrap the error in an error box, if needed.
    $error = $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $error})
        if($error);

    # And generate the page title and content.
    return ($self -> {"template"} -> replace_langvar("COMPOSE_FORM_TITLE"),
            $self -> {"template"} -> load_template("compose/compose.tem", {"***errorbox***"         => $error,
                                                                           "***title***"            => $args -> {"title"},
                                                                           "***summary***"          => $args -> {"summary"},
                                                                           "***description***"      => $args -> {"description"},
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
        my ($title, $content, $extrahead);

        # Normal page operation.
        # ... handle operations here...

        ($title, $content) = $self -> generate_compose();

        $extrahead .= $self -> {"template"} -> load_template("compose/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead);
    }
}

1;
