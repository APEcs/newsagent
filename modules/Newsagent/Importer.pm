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
use base qw(Newsagent); # This class extends the Newsagent block class
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


# ============================================================================
#  Class support functions

## @method private $ _get_import_source($source)
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

    return $sourceh -> fetchrow_hashref()
        or $self -> self_error("Request for unknown import source.");
}


## @method private $ _add_import_meta($articleid, $sourceid)
# Add an entry to the import metainfo table for the specified article
#
# @param articleid The ID of the article associated with this import.
# @param sourceid  The ID of the article in the source data
# @return true on success, undef on error.
sub _add_import_meta {
    my $self      = shift;
    my $articleid = shift;
    my $sourceid  = shift;

    $self -> clear_error();

    my $addh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"import_meta"}."`
                                            (importer_id, article_id, source_id, imported, updated)
                                            VALUES(?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
    my $rows = $addh -> execute($self -> {"importer_id"}, $articleid, $sourceid);
    return $self -> self_error("Unable to perform article metainfo insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article metainfo insert failed, no rows inserted") if($rows eq "0E0");

    return 1;
}


## @method private $ _touch_import_meta($metaid)
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
