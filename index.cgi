#!/usr/bin/perl -wT
# Note: above -w flag should be removed in production, as it will cause warnings in
# 3rd party modules to appear in the server error log
# When running through mod_perl, remove the -T flag and use 'PerlSwitches -T'
# in the apache configuration.

use utf8;
use v5.12;
use lib qw(/var/www/webperl);
use FindBin;

# Work out where the script is, so module and config loading can work.
our $scriptpath;
BEGIN {
    # Autodetect will fail under mod_perl, so use a hard-coded location.
    if($ENV{MOD_PERL}) {
        $scriptpath = "/path/to/newsagent";
    } elsif($FindBin::Bin =~ /(.*)/) {
        $scriptpath = $1;
    }
}

use CGI::Carp qw(fatalsToBrowser set_message); # Catch as many fatals as possible and send them to the user as well as stderr

use lib "$scriptpath/modules";

our $contact = 'contact@email.address'; # global contact address, for error messages

# System modules
use CGI::Carp qw(fatalsToBrowser set_message); # Catch as many fatals as possible and send them to the user as well as stderr

# Webperl modules
use Webperl::Application;

# Webapp modules
use Newsagent::AppUser;
use Newsagent::BlockSelector;
use Newsagent::System;

delete @ENV{qw(PATH IFS CDPATH ENV BASH_ENV)}; # Clean up ENV

# install more useful error handling
sub handle_errors {
    my $msg = shift;
    print "<h1>Software error</h1>\n";
    print '<p>Server time: ',scalar(localtime()),'<br/>Error was:</p><pre>',$msg,'</pre>';
    print '<p>Please report this error to ',$contact,' giving the text of this error and the time and date at which it occured</p>';
}
set_message(\&handle_errors);

my $app = Webperl::Application -> new(appuser        => Newsagent::AppUser -> new(),
                                      system         => Newsagent::System -> new(),
                                      block_selector => Newsagent::BlockSelector -> new(),
                                      config         => "$scriptpath/config/site.cfg")
    or die "Unable to create application";
$app -> run();
