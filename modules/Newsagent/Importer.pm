# @file
# This file contains the implementation of the base Importer class
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
# The importer class serves as the base of other source-specific importer
# classes capable of taking content from other services and adding it
# to Newsagent as standard newsagent articles.
package Newsagent::Importer;

use strict;
use experimental 'smartmatch';
use base qw(Newsagent); # This class extends the Newsagent block class
use List::Flatten;
use Newsagent::System::Feed;
use Newsagent::System::Article;
use v5.12;
use Data::Dumper;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Overloaded constructor for the importer facility, loads the System::Article model
# and other classes required to generate the importers.
#
# @param args A hash of values to initialise the object with. See the Block docs
#             for more information.
# @return A reference to a new Newsagent::Importer object on success, undef on error.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    $self -> {"feed"} = Newsagent::System::Feed -> new(dbh      => $self -> {"dbh"},
                                                       settings => $self -> {"settings"},
                                                       logger   => $self -> {"logger"},
                                                       roles    => $self -> {"system"} -> {"roles"},
                                                       metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Feed initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"article"} = Newsagent::System::Article -> new(feed     => $self -> {"feed"},
                                                             dbh      => $self -> {"dbh"},
                                                             settings => $self -> {"settings"},
                                                             logger   => $self -> {"logger"},
                                                             roles    => $self -> {"system"} -> {"roles"},
                                                             metadata => $self -> {"system"} -> {"metadata"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    $self -> {"queue"} = Newsagent::System::NotificationQueue -> new(dbh      => $self -> {"dbh"},
                                                                     settings => $self -> {"settings"},
                                                                     logger   => $self -> {"logger"},
                                                                     article  => $self -> {"article"},
                                                                     module   => $self -> {"module"})
        or return Webperl::SystemModule::set_error("Article initialisation failed: ".$Webperl::SystemModule::errstr);

    # If importer args have been provided, split them
    if($self -> {"importer_args"}) {
        my %args = $self -> {"importer_args"} =~ /(\w+)=([^;]+)/g;
        $self -> {"args"} = \%args;
    }

    return $self;
}


# ============================================================================
#  Importer loading

## @method $ load_importer($source)
# Load the importer with the specified ID. This will create an instance of an import
# module identified by the specified ID in the import_sources table.
#
# @param source The shortname of the import source to create an importer for.
# @return A reference to an importer object on success, undef on error.
sub load_importer {
    my $self   = shift;
    my $source = shift;

    $self -> clear_error();

    # Fetch the importer data
    my $importdata = $self -> _get_import_source($source)
        or return undef;

    return $self -> {"module"} -> load_module($importdata -> {"perl_module"},
                                              "importer_id"        => $importdata -> {"id"},
                                              "importer_shortname" => $importdata -> {"shortname"},
                                              "importer_args"      => $importdata -> {"args"},
                                              "importer_lastrun"   => $importdata -> {"lastrun"})
        or $self -> self_error("Unable to load import module '$source': ".$self -> {"module"} -> errstr());
}


# ============================================================================
#  Interface

## @method $ find_by_sourceid($sourceid)
# Determine whether an article already exists containing the data for the imported
# article with the specified import-specific id.
#
# @param sourceid   The ID of the article as it appears in the import.
# @return A reference to a hash containing the
sub find_by_sourceid {
    my $self       = shift;
    my $sourceid   = shift;

    $self -> clear_error();

    my $datah = $self -> {"dbh"} -> prepare("SELECT *
                                             FROM `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                             WHERE `importer_id` = ?
                                             AND `source_id` LIKE ?");
    $datah -> execute($self -> {"importer_id"}, $sourceid)
        or return $self -> self_error("Unable to look up import metadata: ".$self -> {"dbh"} -> errstr());

    return $datah -> fetchrow_hashref() || 0;
}


## @method valid_source($source)
# Determine whether the specified source is a valid source. This looks for the
# source in the import sources table, and if it is a valid source the ID of
# the source is returned.
#
# @param source The name of the source to check.
# @return The importer source ID if the source name is valid, 0 if it is not,
#         or undef on error.
sub valid_source {
    my $self   = shift;
    my $source = shift;

    $self -> clear_error();

    my $checkh = $self -> {"dbh"} -> prepare("SELECT `id`
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"import_sources"}."`
                                              WHERE `shortname` LIKE ?");
    $checkh -> execute($source)
        or return $self -> self_error("Unable to look up source timing information: ".$self -> {"dbh"} -> errstr());

    my $importer = $checkh -> fetchrow_arrayref();

    return $importer ? $importer -> [0] : 0;
}


## @method $ all_sources()
# Fetch a list of all the sources defined in the system.
#
# @return A reference to an array of source names known to the system.
sub all_sources {
    my $self = shift;

    $self -> clear_error();

    my $sourceh = $self -> {"dbh"} -> prepare("SELECT `shortname`
                                               FROM `".$self -> {"settings"} -> {"database"} -> {"import_sources"}."`
                                               ORDER BY `shortname`");
    $sourceh -> execute()
        or return $self -> self_error("Unable to obtain list of import sources: ".$self -> {"dbh"} -> errstr());

    my @names = flat(@{ $sourceh -> fetchall_arrayref() || []});

    return \@names;
}


## @method $ should_run($source)
# Determine whether the importer with the specified name should run.
#
# @param source The shortname of the import source to create an importer for.
# @return True if the importer should run, false if not, undef on error.
sub should_run {
    my $self   = shift;
    my $source = shift;

    $self -> clear_error();

    my $checkh = $self -> {"dbh"} -> prepare("SELECT `frequency`, `last_run`
                                              FROM `".$self -> {"settings"} -> {"database"} -> {"import_sources"}."`
                                              WHERE `shortname` LIKE ?");
    $checkh -> execute($source)
        or return $self -> self_error("Unable to look up source timing information: ".$self -> {"dbh"} -> errstr());

    my $sdata = $checkh -> fetchrow_hashref()
        or return $self -> self_error("Request for non-existent source $source");

    return(time() >= ($sdata -> {"last_run"} + $sdata -> {"frequency"}));
}


## @method $ touch_importer($source)
# Update the lastrun time associated with the specified importer.
#
# @param source The shortname of the import source to create an importer for.
# @return True on success, undef on error.
sub touch_importer {
    my $self   = shift;
    my $source = shift;

    $self -> clear_error();

    my $touch = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"import_sources"}."`
                                             SET `last_run` = UNIX_TIMESTAMP()
                                             WHERE `shortname` LIKE ?");
    my $rows = $touch -> execute($source);
    return $self -> self_error("Unable to perform article source update: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article source update failed, no rows updated") if($rows eq "0E0");

    return 1;
}


# ============================================================================
#  Class support functions

## @method protected $ _get_import_source($source)
# Fetch the information for the specified import source from the database.
#
# @param source The shortname of the importer to fetch the data for.
# @return A reference to a hash containing the importer data on success, undef
#         on error.
sub _get_import_source {
    my $self   = shift;
    my $source = shift;

    $self -> clear_error();

    my $sourceh = $self -> {"dbh"} -> prepare("SELECT s.*,m.perl_module
                                               FROM `".$self -> {"settings"} -> {"database"} -> {"import_sources"}."` AS `s`,
                                                    `".$self -> {"settings"} -> {"database"} -> {"modules"}."` AS `m`
                                               WHERE `m`.`module_id` = `s`.`module_id`
                                               AND `s`.`shortname` LIKE ?");
    $sourceh -> execute($source)
        or return $self -> self_error("Unable to look up import metadata: ".$self -> {"dbh"} -> errstr());

    return ($sourceh -> fetchrow_hashref() || $self -> self_error("Request for unknown import source."));
}


## @method protected $ _get_import_meta($articleid, $sourceid)
# Fetch the metainfo data for the specified article and source, if possible.
#
# @param articleid The ID of the article associated with this import.
# @param sourceid  The ID of the article in the source data
# @return A reference to a hash containing the metainfo on success, undef
#         on error.
sub _get_import_meta {
    my $self      = shift;
    my $articleid = shift;
    my $sourceid  = shift;

    $self -> clear_error();

    my $geth = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                            WHERE importer_id = ?
                                            AND article_id = ?
                                            AND source_id = ?");
    my $rows = $geth -> execute($self -> {"importer_id"}, $articleid, $sourceid)
        or return $self -> self_error("Unable to perform article metainfo lookup: ". $self -> {"dbh"} -> errstr);

    return $rows -> fetchrow_hashref() || $self -> self_error("No article metainfo found for $articleid, sourceid $sourceid");
}


## @method protected $ _set_import_meta($articleid, $sourceid, $data)
# Set or add an entry in the import metainfo table for the specified article. If
# the entry already exists, this will set the update timestamp at the same time
# as setting the data. If you do not need to change the data, use _touch_import_meta()
# instead of this function!
#
# @param articleid The ID of the article associated with this import.
# @param sourceid  The ID of the article in the source data
# @param data      An optional data string to associate with the metainfo row.
# @return true on success, undef on error.
sub _set_import_meta {
    my $self      = shift;
    my $articleid = shift;
    my $sourceid  = shift;
    my $data      = shift;

    $self -> clear_error();

    my $metainfo = $self -> _get_import_meta($articleid, $sourceid);

    if($metainfo) {
        my $seth = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                                SET `data` = ?, `updated` = UNIX_TIMESTAMP()
                                                WHERE `id` = ?");
        my $rows = $seth -> execute($data, $metainfo -> {"id"});
        return $self -> self_error("Unable to perform article metainfo update: ". $self -> {"dbh"} -> errstr) if(!$rows);
        return $self -> self_error("Article metainfo update failed, no rows updated") if($rows eq "0E0");
    } else {
        my $addh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                                (`importer_id`, `article_id`, `source_id`, `imported`, `updated`, `data`)
                                                VALUES(?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP(), ?)");
        my $rows = $addh -> execute($self -> {"importer_id"}, $articleid, $sourceid, $data);
        return $self -> self_error("Unable to perform article metainfo insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
        return $self -> self_error("Article metainfo insert failed, no rows inserted") if($rows eq "0E0");
    }

    return 1;
}


## @method protected $ _touch_import_meta($metaid)
# Update the timestamp associated with the specified import metadata
#
# @param metaid The ID of the import metadata to update.
# @return true on success, undef on error.
sub _touch_import_meta {
    my $self   = shift;
    my $metaid = shift;

    $self -> clear_error();

    my $touch = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                            SET `updated` = UNIX_TIMESTAMP()
                                            WHERE id = ?");
    my $rows = $touch -> execute($metaid);
    return $self -> self_error("Unable to perform article metainfo update: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article metainfo update failed, no rows updated") if($rows eq "0E0");

    return 1;
}

1;
