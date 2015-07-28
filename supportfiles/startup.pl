use strict;

use lib "/var/www/localhost/newsagent/newsagent/blocks";
use lib "/var/www/localhost/newsagent/newsagent/modules";
use lib "/var/www/webperl";

# Make sure we are in a sane environment.
$ENV{MOD_PERL} or die "not running under mod_perl!";

# Preload core stuff
use Apache2::RequestRec;
use ModPerl::Util;

# Preload frequently used modules to speed up client spawning.
use CGI ();
CGI->compile(':cgi');
use CGI::Carp ();

use Apache::DBI;
use DBD::mysql ();

# And load the Newsagent core modules
use Newsagent;
use Newsagent::AppUser;
use Newsagent::Article;
use Newsagent::BlockSelector;
use Newsagent::Feed;
use Newsagent::Importer;
use Newsagent::Newsletter;
use Newsagent::Notification::Method;
use Newsagent::System;
use Newsagent::System::Article;
use Newsagent::System::Feed;
use Newsagent::System::Files;
use Newsagent::System::Images;
use Newsagent::System::Matrix;
use Newsagent::System::Megaphone;
use Newsagent::System::Metadata;
use Newsagent::System::NotificationQueue;
use Newsagent::System::Roles;
use Newsagent::System::Schedule;
use Newsagent::System::Subscriptions;
use Newsagent::System::Tags;
use Newsagent::System::TellUs;
use Newsagent::System::UserDataBridge;
use Newsagent::TellUs;

1;