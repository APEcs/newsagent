# @file
# This file contains the implementation of the RSS/API facility.
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
package Newsagent::Feed::RSS;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent::Feed); # This class extends the Newsagent Feed class
use Newsagent::System::Article;
use Encode;
use Digest::MD5 qw(md5_hex);
use CGI::Util qw(escape);
use Webperl::Utils qw(trimspace path_join);
use HTML::FormatText;
use HTML::Entities;
use v5.12;
use Data::Dumper;
# ============================================================================
#  Content generators

## @method $ embed_fulltext_image($article)
# Generate a div-wrapped version of the article to include in the fulltext that
# includes the article image.
#
# @param article The article to generate the fulltext with embedded image for
# @return A string containing the full text with embedded image
sub embed_fulltext_image {
    my $self    = shift;
    my $article = shift;
    my $image   = "";

    if($article -> {"images"} -> [1]) {
        my $url = $self -> {"article"} -> {"images"} -> get_image_url($article -> {"images"} -> [1], 'large');
        $image = $self -> {"template"} -> load_template("feeds/rss/fulltext-image-img.tem", {"***class***" => "article",
                                                                                             "***url***"   => $url,
                                                                                             "***title***" => $article -> {"title"}});
    }

    return $self -> {"template"} -> load_template("feeds/rss/fulltext-image.tem", {"***image***" => $image,
                                                                                   "***text***"  => $article -> {"fulltext"}});
}


## @method private $ _build_rss_image($image, $type)
# Generate an image entry for the RSS feed.
#
# @param image A reference to a hash containing the image date.
# @param type  The image type - should be 'lead', 'thumb', or 'article'
# @return A string containing the image entry.
sub _build_rss_image {
    my $self  = shift;
    my $image = shift;
    my $type  = shift;

    # Convenience hash to map image modes to internal sizes.
    my $modes = { "lead"    => "icon",
                  "thumb"   => "thumb",
                  "article" => "large",
                  "tactus"  => "tactus" };

    # Do nothing if there is no image data available.
    return "" if(!$image);

    my $url = $self -> {"article"} -> {"images"} -> get_image_url($image, $modes -> {$type})
        or return "";

    return $self -> {"template"} -> load_template("feeds/rss/image.tem", {"***url***"  => $url,
                                                                          "***name***" => $image -> {"name"},
                                                                          "***type***" => $type});
}


## @method void generate_feed()
# Generate an RSS feed of articles based on the filters specified by the user on
# the query string. Note that this does not return, and errors that occur inside
# are consumed silently - this is a design decision based on the fact that the
# feeds are going to be automatically aggregated, and errors getting through
# to the aggregators is likely to be an undesirable state of affairs.
sub generate_feed {
    my $self     = shift;

    my $settings = $self -> _validate_settings();

    # Potentially tweak the levels based on pathinfo
    my @pathinfo = $self -> {"cgi"} -> param("pathinfo");

    # Only update the level settings if no parameters have been set, and the
    # pathinfo contains a valid level
    if($pathinfo[0] && $pathinfo[0] =~ /^\w+$/ && (!$settings -> {"levels"} || !scalar(@{$settings -> {"levels"}}))) {
        my $levelid = $self -> {"article"} -> _get_level_byname($pathinfo[0]);

        push(@{$settings -> {"levels"}}, $pathinfo[0])
            if($levelid);
    }

    my $results  = $self -> {"article"} -> get_feed_articles($settings);
    my $now      = time();

    my $items   = "";
    my $maxdate = 0;
    foreach my $result (@{$results}) {
        my ($images, $levels, $files, $extra) = ("", "", "", "");

        # Keep track of the latest date (should be the first result, really)
        $maxdate = $result -> {"release_time"}
            if($result -> {"release_time"} > $maxdate);

        # Build the image list
        $images .= $self -> _build_rss_image($result -> {"images"} -> [0], 'lead')
            if($result -> {"images"} -> [0]);

        if($result -> {"images"} -> [1]) {
            $images .= $self -> _build_rss_image($result -> {"images"} -> [1], 'thumb');
            $images .= $self -> _build_rss_image($result -> {"images"} -> [1], 'article');
            $images .= $self -> _build_rss_image($result -> {"images"} -> [1], 'tactus');
        }

        $images = $self -> {"template"} -> load_template("feeds/rss/images.tem", {"***images***" => $images})
            if($images);

        # Build the files list
        if($result -> {"files"} && scalar(@{$result -> {"files"}})) {
            foreach my $file (@{$result -> {"files"}}) {
                $files .= $self -> {"template"} -> load_template("feeds/rss/file.tem", {"***name***" => $file -> {"name"},
                                                                                        "***size***" => $file -> {"size"},
                                                                                        "***url***"  => $self -> {"article"} -> {"files"} -> get_file_url($file)});
            }

            $files = $self -> {"template"} -> load_template("feeds/rss/files.tem", {"***files***" => $files})
                if($files);
        }

        # Build the level list
        foreach my $level (@{$result -> {"levels"}}) {
            $levels .= $self -> {"template"} -> load_template("feeds/rss/level.tem", {"***level***" => $level -> {"level"}});
        }

        # Handle fulltext transform
        my $showsum = $result -> {"full_summary"} ? "summary.tem" : "nosummary.tem";
        $result -> {"fulltext"} = $self -> {"template"} -> load_template("feeds/rss/fulltext-$showsum", {"***summary***" => $result -> {"summary"},
                                                                                                         "***text***"    => $self -> cleanup_entities($result -> {"fulltext"})})
            if($result -> {"fulltext"});

        given($result -> {"fulltext_mode"}) {
            when("markdown") { $result -> {"fulltext"} = $self -> make_markdown_body($result -> {"fulltext"}); }
            when("plain")    { $result -> {"fulltext"} = $self -> html_strip($result -> {"fulltext"}); }
            when("embedimg") { $result -> {"fulltext"} = $self -> embed_fulltext_image($result); }
        }

        # If fulltext is activated, and it isn't used in the description already, include the text in the item
        $extra .= $self -> {"template"} -> load_template("feeds/rss/newsagent.tem", {"***elem***"    => "fulltext",
                                                                                     "***attrs***"   => "",
                                                                                     "***content***" => "<![CDATA[\n".$result -> {"fulltext"}."\n]]>" })
            if($result -> {"fulltext_mode"} && !$result -> {"use_fulltext_desc"});

        # If fulltext is activated, and it is being used as the description, but including the summary in the
        # fulltext is not enabled, create a separate summary element
        $extra .= $self -> {"template"} -> load_template("feeds/rss/newsagent.tem", {"***elem***"    => "summary",
                                                                                     "***attrs***"   => "",
                                                                                     "***content***" => "<![CDATA[".$result -> {"summary"}."]]>" })
            if($result -> {"fulltext_mode"} && $result -> {"use_fulltext_desc"} && !$result -> {"full_summary"});


        # The date can be needed in both the title and date fields.
        my $pubdate = $self -> {"template"} -> format_time($result -> {"release_time"}, $self -> {"timefmt"});

        # Work out the feeds
        my $feeds = "";
        foreach my $feed (@{$result -> {"feeds"}}) {

            $feeds .= $self -> {"template"} -> load_template("feeds/rss/feed.tem", {"***description***" => $feed -> {"description"},
                                                                                    "***name***"        => $feed -> {"name"}});
        }

        # work out the URL
        my $feedurl = $self -> feed_url($settings -> {"viewer"}, $settings -> {"feeds"}, $result -> {"feeds"}, $result -> {"id"});

        # Is the item sticky? If so, until when?
        if($result -> {"is_sticky"} && $result -> {"sticky_until"} > $now) {
            $extra .= $self -> {"template"} -> load_template("feeds/rss/newsagent.tem", {"***elem***"    => "sticky",
                                                                                         "***attrs***"   => "epoch=\"".$result -> {"sticky_until"}."\"",
                                                                                         "***content***" => $self -> {"template"} -> format_time($result -> {"sticky_until"}, $self -> {"timefmt"})
                                                             });
        }

        # Put the item together!
        $items .= $self -> {"template"} -> load_template("feeds/rss/item.tem", {"***title***"       => $result -> {"title"} || $pubdate,
                                                                                "***description***" => $result -> {"use_fulltext_desc"} ? $result -> {"fulltext"} : $result -> {"summary"},
                                                                                "***images***"      => $images,
                                                                                "***files***"       => $files,
                                                                                "***feeds***"       => $feeds,
                                                                                "***levels***"      => $levels,
                                                                                "***extra***"       => $extra,
                                                                                "***date***"        => $pubdate,
                                                                                "***acyear***"      => $result -> {"acyear"} ? $result -> {"acyear"} -> {"start_year"} : "",
                                                                                "***guid***"        => $self -> build_url(fullurl  => 1,
                                                                                                                          block    => "view",
                                                                                                                          pathinfo => [ "article", $result -> {"id"}]),
                                                                                "***link***"        => $feedurl,
                                                                                "***email***"       => $result -> {"email"},
                                                                                "***name***"        => $result -> {"realname"} || $result -> {"username"},
                                                                                "***gravhash***"    => md5_hex(lc(trimspace($result -> {"email"} || ""))),
                                                         });
    }

    # Construct a nice feed url
    my $rssurl = path_join($self -> {"cgi"} -> url(-base => 1), $self -> {"settings"} -> {"config"} -> {"scriptpath"}, "rss/");
    my $query  = "";

    # Can't use join/bap trickery here, as don't want to include "unset" elements
    foreach my $key (keys %{$settings}) {
        # skip settings not specified in the original query
        next unless($settings -> {$key} && defined($self -> {"cgi"} -> param($key)));

        $query .= "&amp;" if($query);
        $query .= $key."=".escape($settings -> {$key});
    }
    $rssurl .= "?$query" if($query);

    # Put everything together in a channel to send back to the user.
    my $feed = $self -> {"template"} -> load_template("feeds/rss/channel.tem", {"***generator***"   => "Newsagent",
                                                                                "***editor***"      => $self -> {"settings"} -> {"config"} -> {"RSS:editor"},
                                                                                "***webmaster***"   => $self -> {"settings"} -> {"config"} -> {"RSS:webmaster"},
                                                                                "***title***"       => $self -> {"settings"} -> {"config"} -> {"RSS:title"},
                                                                                "***description***" => $self -> {"settings"} -> {"config"} -> {"RSS:description"},
                                                                                "***link***"        => $rssurl,
                                                                                "***lang***"        => "en",
                                                                                "***now***"         => $self -> {"template"} -> format_time(time(), $self -> {"timefmt"}),
                                                                                "***changed***"     => $self -> {"template"} -> format_time($maxdate, $self -> {"timefmt"}),
                                                                                "***items***"       => $items,
                                                                                "***extra***"       => ""});

    # Do not use the normal page generation process to send back the feed - that sends back
    # html, not xml. This sends the feed to the user, and then cleans up and shuts down the
    # script.
    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($feed);

    $self -> {"template"} -> set_module_obj(undef);
    $self -> {"messages"} -> set_module_obj(undef);
    $self -> {"system"} -> clear() if($self -> {"system"});
    $self -> {"session"} -> {"auth"} -> {"app"} -> set_system(undef) if($self -> {"session"} -> {"auth"} -> {"app"});

    $self -> {"dbh"} -> disconnect();
    $self -> {"logger"} -> end_log();

    exit;
}


## @method $ html_strip($text)
# Remove HTML from the specified text. This converts the specified text from
# HTML to plain text, with various fixes for images and horizontal rules.
#
# @param text The text to convert to HTML
sub html_strip {
    my $self = shift;
    my $text = shift;

    # FIXME: Convert to latin-1. This is horrible and annoying, and should not be needed
    #        but not converting it produces borken output. Find out WTF and fix it.
    $text = Encode::encode("iso-8859-1", $text);

    # pre-convert images to avoid losing them during conversion.
    $text =~ s|<img(.*?)/?>|_convert_img($1)|iseg;
    my $tree = HTML::TreeBuilder -> new_from_content($text);

    my $formatter = HTML::FormatText -> new(leftmargin => 0, rightmargin => 50000);
    $text = $formatter -> format($tree);

    # clean up images.
    $text =~ s/(img: [^\s]+?) /$1\n/g;

    my $bar = "-" x 80;
    $text =~ s/-{80,}/$bar/g;

    return $text;
}

## @fn private $ _convert_img($attrs);
# Given the guts of an image tag, discard everything but the src URL.
# This takes the contents of an image tag, looks for the src attribute,
# and returns the URL it contains - everything else is ignored.
#
# @param attrs A string containing the image tag attributes.
# @return A string containing the image URL.
sub _convert_img {
    my $attrs = shift;

    my ($src) = $attrs =~ /src=["'](.*?)["']/;
    return "img: $src\n" || "";
}

1;
