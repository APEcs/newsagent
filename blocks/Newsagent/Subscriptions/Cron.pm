## @file
# This file contains the implementation of the cron-triggered subscription
# dispatcher
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
package Newsagent::Subscriptions::Cron;

use strict;
use experimental qw(smartmatch);
use base qw(Newsagent::Subscriptions); # This class extends the Subscriptions block class
use v5.12;
use Webperl::Utils qw(path_join trimspace);
use Digest::MD5 qw(md5_hex);
use Data::Dumper;
use Newsagent::System::Schedule;
use Newsagent::System::Article;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the Cron facility, loads the System::Article model
# and other classes required to perform the cron job, in addition to the classes
# loaded by the Subscriptions module.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Subscriptions object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"digest_schedule"} = $self -> {"settings"} -> {"config"} -> {"Subscription:digest_schedule"} || 86400;

    $self -> {"schedule"} = Newsagent::System::Schedule -> new(dbh      => $self -> {"dbh"},
                                                               settings => $self -> {"settings"},
                                                               logger   => $self -> {"logger"},
                                                               roles    => $self -> {"system"} -> {"roles"},
                                                               metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"article"} = Newsagent::System::Article -> new(feed     => $self -> {"feed"},
                                                             schedule => $self -> {"schedule"},
                                                             dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    return $self;
}


# ============================================================================
#  Cron job implementation

## @method private $ _build_update($article)
# Build an individual email section based on the specified article.
#
# @param article The article to generate the email from.
# @return The html containing the article.
sub _build_update {
    my $self    = shift;
    my $article = shift;

    $article -> {"images"} -> [0] -> {"location"} = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"},
                                                              $self -> {"settings"} -> {"config"} -> {"HTML:default_image"})
        if(!$article -> {"images"} -> [0] -> {"location"} && $self -> {"settings"} -> {"config"} -> {"HTML:default_image"});

    my $image;
    $image = $self -> {"article"} -> {"images"} -> get_image_url($article -> {"images"} -> [1], 'large');

    $image = $self -> {"template"} -> load_template("Notification/Method/Email/image.tem", {"***class***"  => "article",
                                                                                            "***url***"    => $image,
                                                                                            "***alt***"    => "article image"})
        if($image);

    $article -> {"article"} = $self -> cleanup_entities($article -> {"article"});

    my $pubdate = $self -> {"template"} -> format_time($article -> {"release_time"}, "%a, %d %b %Y %H:%M:%S %z");
    my $subject = $article -> {"title"} || $pubdate;

    my @feeds = ();
    foreach my $feed (@{$article -> {"feeds"}}) {
        push(@feeds, $feed -> {"description"});
    }

    # build the files
    my $files = "";
    if($article -> {"files"} && scalar(@{$article -> {"files"}})) {
        foreach my $file (@{$article -> {"files"}}) {
            $files .= $self -> {"template"} -> load_template("subscriptions/file.tem", {"***name***" => $file -> {"name"},
                                                                                        "***size***" => $self -> {"template"} -> bytes_to_human($file -> {"size"}),
                                                                                        "***url***"  => $self -> {"article"} -> {"files"} -> get_file_url($file)});
        }

        $files = $self -> {"template"} -> load_template("subscriptions/files.tem", {"***files***" => $files})
            if($files);
    }

    return $self -> {"template"} -> load_template("subscriptions/email_update.tem", {"***body***"     => $article -> {"fulltext"},
                                                                                     "***files***"    => $files,
                                                                                     "***feeds***"    => join("; ", @feeds),
                                                                                     "***title***"    => $article -> {"title"} || $pubdate,
                                                                                     "***date***"     => $pubdate,
                                                                                     "***summary***"  => $article -> {"summary"},
                                                                                     "***img2***"     => $image,
                                                                                     "***logo_url***" => $self -> {"settings"} -> {"config"} -> {"Article:logo_img_url"},
                                                                                     "***name***"     => $article -> {"realname"} || $article -> {"username"},
                                                                                     "***gravhash***" => md5_hex(lc(trimspace($article -> {"email"} || ""))) });

}


## @method private $ _send_subscription_digest($subscription, $articles)
# Send the provided articles to the subscription specified.
#
# @param subscription The subscription to send the email to.
# @param articles     The articles to put into the email.
# @return A status message indicating the success or failure of the send.
sub _send_subscription_digest {
    my $self         = shift;
    my $subscription = shift;
    my $articles     = shift;

    my $updates = "";

    foreach my $article (@{$articles}) {
        $updates .= $self -> _build_update($article);
    }

    my $date = $self -> {"template"} -> format_time(time(), "%A, %d%o %b, %Y");

    my $title = $self -> {"template"} -> replace_langvar(scalar(@{$articles}) != 1  ? "SUBS_DIGEST_TITLES" : "SUBS_DIGEST_TITLE",
                                                         {"***new***"  => scalar(@{$articles}) || $self -> {"template"} -> replace_langvar("SUBS_DIGEST_NONE"),
                                                          "***date***" => $date
                                                         });

    my $recipient = $subscription -> {"email"} || $subscription -> {"user_id"};

    my $tem    = ($subscription -> {"email"} && !$subscription -> {"user_id"}) ? "emailauth.tem" : "noauth.tem";
    my $params = ($subscription -> {"email"} && !$subscription -> {"user_id"}) ? { authcode => $subscription -> {"authcode"} } : {};
    my $authblock = $self -> {"template"} -> load_template("subscriptions/$tem", {"***authcode***" => $subscription -> {"authcode"},
                                                                                  "***url***"      => $self -> build_url(block    => "subscribe",
                                                                                                                         pathinfo => [ 'manage' ],
                                                                                                                         params   => $params,
                                                                                                                         forcessl => 1,
                                                                                                                         fullurl  => 1) });

    # FIXME: This will not work unless message support HTML!
    my $status = $self -> {"messages"} -> queue_message(subject => $title,
                                                        message => $self -> {"template"} -> load_template("subscriptions/email.tem", {"***img1***"    => "",
                                                                                                                                      "***title***"   => $title,
                                                                                                                                      "***updates***" => $updates,
                                                                                                                                      "***auth***"    => $authblock }),
                                                        recipients       => [ $recipient ],
                                                        send_immediately => 1,
                                                        format           => 'html');

    return $status ? "<p>Sent digest message containing ".scalar(@{$articles})." update(s)s to $recipient</p>"
                   : "<p>Send to $recipient failed: ".$self -> {"messages"} -> errstr()."</p>";
}


## @method $ _run_cronjob()
# Perform the cron job process - this checks for subscriptions that need to be
# processed, and processes them, sending out digest messages to subscribers/
#
# @return A string containing the status information generated during processing.
#         Note that this is *not* a valid body - it needs wrapping in something
#         more sensible before returning to the user.
sub _run_cronjob {
    my $self = shift;
    my $now  = time();

    my $after = $now - $self -> {"digest_schedule"};

    # Get a list of all subscriptions that need to be sent digests
    my $subscriptions = $self -> {"subscription"} -> get_pending_subscriptions($after)
        or return $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $self -> {"subscription"} -> errstr()});

    my $status = "";
    if(scalar(@{$subscriptions})) {
        foreach my $subscription (@{$subscriptions}) {
            # do nothing if there are no feeds to check
            next unless($subscription -> {"feeds"} && scalar(@{$subscription -> {"feeds"}}));

            # Feeds are present, so pull in the list of articles published since either the last run
            # for this subscription, or the 'after' date, as appropriate. Note that it's fine
            # for get_feed_articles() to return a ref to an empty array, but not undef!
            my $articles = $self -> {"article"} -> get_feed_articles('feedids' => $subscription -> {"feeds"},
                                                                     'maxage'  => $subscription -> {"lastrun"} || $after,
                                                                     'fulltext_mode' => 1,
                                                                     'order' => 'asc.nosticky',
                                                                     'count' => 999)
                or return $status.$self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $self -> {"article"} -> errstr()});

            my $update = $self -> _send_subscription_digest($subscription, $articles)
                or return $status.$self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $self -> errstr()});

            $self -> {"subscription"} -> mark_run($subscription -> {"id"})
                or return $self -> {"template"} -> load_template("error/error_box.tem", {"***message***" => $self -> {"subscription"} -> errstr()});

            $status .= $update;
        }

        return $status;
    } else {
        return $self -> {"template"} -> replace_langvar("SUBS_CRON_NOSUBS");
    }

}


## @method $ _build_cronjob()
# A wrapper function around _run_cronjob() to enclose its output in appropriate markup.
#
# @return An array of two values: the page title string, and the cron status page body.
sub _build_cronjob {
    my $self = shift;

    return ($self -> {"template"} -> replace_langvar("SUBS_CRON_TITLE"),
            $self -> {"template"} -> load_template("subscriptions/cron.tem", {"***status***" => $self -> _run_cronjob() }));
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

        given($pathinfo[0]) {

            default {
                ($title, $content) = $self -> _build_cronjob();
            }
        }

        $extrahead .= $self -> {"template"} -> load_template("subscriptions/extrahead.tem");
        return $self -> generate_newsagent_page($title, $content, $extrahead, "subscriptions");
    }
}

1;