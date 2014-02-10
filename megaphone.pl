#!/usr/bin/perl

use v5.12;
use Proc::Daemon;
use FindBin;
use List::Util qw(min);
use DateTime;
use Scalar::Util qw(blessed);

use lib qw(/var/www/webperl);
use Webperl::ConfigMicro;
use Webperl::Daemon;
use Webperl::Logger;
use Webperl::Utils qw(path_join);

# Work out where the script is, so module and config loading can work.
my $scriptpath;
BEGIN {
    if($FindBin::Bin =~ /(.*)/) {
        $scriptpath = $1;
    }
}

use lib "$scriptpath/modules";
use Newsagent::System::Megaphone;


## @fn void handle_daemon($daemon)
# Handle the daemonisation or management of the daemon process.
#
# @param daemon A reference to a Webperl::Daemon object
sub handle_daemon {
    my $daemon = shift;

    given($ARGV[0]) {
        when("start") {
            my $result = $daemon -> run('start');
            exit 0 if($result == Webperl::Daemon::STATE_ALREADY_RUNNING);
        }

        when("stop") {
            exit $daemon -> run('stop');
        }

        when("restart") {
            my $result = $daemon -> run('restart');
            exit $result unless($result == Webperl::Daemon::STATE_OK);
        }

        when("status") {
            my $status = $daemon -> run('status');
            given($status) {
                when(Webperl::Daemon::STATE_OK) {
                    print "Status: started.\n";
                }
                when(Webperl::Daemon::STATE_NOT_RUNNING) {
                    print "Status: stopped.\n";
                }
                default {
                    print "Status: unknown\n"
                }
            }
            exit $status;
        }

        when("wake") {
            exit $daemon -> signal(14);
        }

        when("debug") { # do nothing
        }

        default {
            die "Usage: $0 start|stop|restart|wake|debug\n";
        }
    }
}

# Note that the : at the end of the ident is required, otherwise the PID is not
# written to syslog with the name. Buggered if I know *why*, but it isn't.
my $logger = Webperl::Logger -> new(syslog => 'Megaphone:')
    or die "FATAL: Unable to create logger object\n";

my $settings = Webperl::ConfigMicro -> new(path_join($scriptpath, "config", "site.cfg"))
    or $logger -> die_log("FATAL: Unable to load config: ".$Webperl::SystemModule::errstr);

my $daemon = Webperl::Daemon -> new(pidfile => $settings -> {"megaphone"} -> {"pidfile"});
handle_daemon($daemon);

$logger -> print(Webperl::Logger::NOTICE, "Started background message dispatcher");

my $dbh = DBI->connect($settings -> {"database"} -> {"database"},
                       $settings -> {"database"} -> {"username"},
                       $settings -> {"database"} -> {"password"},
                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or $logger -> die_log("Unable to connect to database: ".$DBI::errstr);

# Pull configuration data out of the database into the settings hash
$settings -> load_db_config($dbh, $settings -> {"database"} -> {"settings"});

# Start database logging if available
$logger -> init_database_log($dbh, $settings -> {"database"} -> {"logging"})
    if($settings -> {"database"} -> {"logging"});

my $megaphone = Newsagent::System::Megaphone -> new(dbh      => $dbh,
                                                    logger   => $logger,
                                                    settings => $settings)
    or $logger -> die_log("FATAL: Unable to start megaphone: ".$Webperl::SystemModule::errstr);

# Make the default alarm handler ignore the signal. This should still make sleep() wake, though.
$SIG{"ALRM"} = sub { $logger -> print(Webperl::Logger::NOTICE, "Received alarm signal") };

$megaphone -> run();
