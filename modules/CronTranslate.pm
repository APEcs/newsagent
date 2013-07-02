## @file
# A module based on the "showcrontab" code created by William R. Ward
# found here: http://backpan.perl.org/authors/id/W/WR/WRW/showcrontab
#
# This version has been modified to encapsulate the string conversion,
# allow for templating of strings, and correct the handling of months.
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
# along with this program.  If not, see http://www.gnu.org/licenses/.
package CronTranslate;

use strict;
use base qw(Webperl::SystemModule);


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Construct a new CronTranslate object.
#
# @param args A hash of values to initialise the object with.
# @return A reference to a new CronTranslate object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"weekdays"} = [ "{L_CRON_SUNDAY}",
                              "{L_CRON_MONDAY}",
                              "{L_CRON_TUESDAY}",
                              "{L_CRON_WEDNESDAY}",
                              "{L_CRON_THURSDAY}",
                              "{L_CRON_FRIDAY}",
                              "{L_CRON_SATURDDAY}",
                            ];
    $self -> {"months"}   = [ "{L_CRON_JAN}",
                              "{L_CRON_FEB}",
                              "{L_CRON_MAR}",
                              "{L_CRON_APR}",
                              "{L_CRON_MAY}",
                              "{L_CRON_JUN}",
                              "{L_CRON_JUL}",
                              "{L_CRON_AUG}",
                              "{L_CRON_SEP}",
                              "{L_CRON_OCT}",
                              "{L_CRON_NOV}",
                              "{L_CRON_DEC}",
                            ];

    return SystemModule::set_error("No template module available.") if(!$self -> {"template"});

    return $self;
}


# ============================================================================
#  Interface

## @method $ humanise_cron($cron)
# Convert the specified cron expression into a string readable by normal humans.
#
# @param cron The cron expression to convert.
# @return A string containing the human-readable version of the expression.
sub humanise_cron {
    my $self   = shift;
    my $cron   = shift;
    my $result = "";

    # The original version of this code appears to be based around an erroneous
    # definition of the crontab format: it specified that the 4th field should
    # be "day of year", when in fact it should be the month according to both
    # `man 5 crontab` and other sources like https://en.wikipedia.org/wiki/Cron

    my ($min, $hour, $mday, $month, $wday) = split(/\s+/, $cron, 5);

    # Display the time.  If the hour is given...
    if ($hour ne '*') {

        # ...and the minute is given...
        if ($min ne '*') {

            # Split the hours and minutes into lists of times using
            # _str2list() and display a list of times such as '09:00, 17:30'
            my @hours = $self -> _str2list($hour);
            my @mins  = $self -> _str2list($min);
            my ($i, $j, @times);
            foreach $i (@hours) {
                foreach $j (@mins) {
                    push (@times, sprintf('%02d:%02d', $i, $j));
                }
            }
            $result .= $self -> {"template"} -> replace_langvar("CRON_ATEACHDAY", {"***times***" => $self -> list2str(@times)});

        # Hour given but minute not given.
        } else {
            $result .= $self -> {"template"} -> replace_langvar("CRON_EACHMINUNTE", {"***hour***" => $self -> _convertnum($hour)});
        }

    # Hour is not given but minute is...
    } elsif ($min ne '*') {
        $result .= $self -> {"template"} -> replace_langvar("CRON_MINUNTEPAST", {"***minutes***" => $self -> _convertnum($min)});
    }

    # Display day of month info if given.
    $result .= $self -> {"template"} -> replace_langvar("CRON_DAYMONTH", {"***day***" => $self -> _convertnum($mday)})
        if($mday ne '*');

    # Display day of week info if given.  Converts the number into the
    # name of the day(s) given.
    if ($wday ne '*') {
        my $days = $self -> _convertnum($wday);
        $days =~ s/(\d)(st|nd|rd|th)/$self->{weekdays}->[$1]/g;

        $result .= $self -> {"template"} -> replace_langvar($mday eq "*" ? "CRON_DAYMONTH" : "CRON_ORDAYWEEK",
                                                            {"***days***" => $days});
    }

    # Display month info if given.
    if($month ne "*") {
        my $months = $self -> _convertnum($month);
        $days =~ s/(\d)(st|nd|rd|th)/$self->{months}->[$1]/g;
        $result .= $self -> {"template"} -> replace_langvar("CRON_MONTHS", {"***months***" => $months});
    }

    return $result;
}


# ============================================================================
#  Private functions

## @method private $ _str2list($num, ...)
# Convert a single item or a comma-separated list of items (where 'item' is
# either a number or a hyphen-separated range of numbers) into an array of
# numbers.
#
# @param
sub _str2list {
    my $self = shift;
    my ($nums) = @_;
    my @numbers;

    my @list = split(/,/, $nums);
    foreach my $number (@list) {
        if($number =~ /(\d+)-(\d+)/) {
            push (@numbers, $1 .. $2);
        } else {
            push (@numbers, $number);
        }
    }

    return @numbers;
}


# Subroutine _convertnum converts entry such as '1,12,23-25' into a
# string such as '1st, 12th, and 23rd through 25th'.  Input and output
# are both scalars.
sub _convertnum {
    my $self = shift;
    my ($str) = @_;
    my @numbers = split(/,/, $str);

    my ($num, @retval);
    foreach $num (@numbers) {
        if ($num =~ /(\d+)-(\d+)/) {
            push (@retval, $self -> {"template"} -> replace_langvar("CRON_RANGE", {"***start***" => num2word($1),
                                                                                   "***end***"   => num2word($2)}));
        } else {
            push (@retval, num2word($num));
        }
    }
    return list2str(@retval);
}

# Subroutine num2word converts a number into a word by adding 'st',
# 'nd', 'rd', or 'th' as appropriate.  Input and output are both
# scalars.
sub num2word {
    my $self = shift;
    my ($num) = @_;
    $num += 0;                  # ensure value is numeric.
    my $lastdigit = substr($num, length($num)-1, 1);
    if    ($lastdigit == 1) { $num .= 'st'; }
    elsif ($lastdigit == 2) { $num .= 'nd'; }
    elsif ($lastdigit == 3) { $num .= 'rd'; }
    else                    { $num .= 'th'; }
    return $num;
}


# Converts an array into a string by adding commas and 'ands' where
# appropriate.  Uses the 'terminal comma' syntax, e.g. 'foo, bar, and
# baz' as opposed to 'foo, bar and baz'.  For two elements, no comma
# is used.  Input is array, output is scalar.
sub list2str
{
    my $self = shift;
    my (@list) = @_;
    if(scalar(@list) == 1) {
        return $list[0];
    } elsif(scalar(@list) == 2) {
        return join($self -> {"template"} -> replace_langvar("CRON_AND", {"***last***" => ""}), @list);
    } else  {
        my $last = pop @list;
        return join(', ', @list).$self -> {"template"} -> replace_langvar("CRON_AND", {"***last***" => $last});
    }
}

1;
