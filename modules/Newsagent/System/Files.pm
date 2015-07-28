## @file
# This file contains the implementation of the file handling code.
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
package Newsagent::System::Files;

use strict;
use experimental 'smartmatch';
use base qw(Webperl::SystemModule); # This class extends the system module class
use v5.12;

use Digest;
use File::Path qw(make_path);
use File::Copy;
use File::LibMagic;
use Webperl::Utils qw(path_join trimspace);
use File::Scan::ClamAV;


# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# Create a new Images object to manage image storage and information.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Images object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Allowed file types
    $self -> {"allowed_types"} = { "image/x-png" => "png",
                                   "image/jpeg"  => "jpg",
                                   "image/gif"   => "gif",
    };

    return $self;
}


# ============================================================================
#  Interface

## @method $ get_file_info($id, $order)
# Obtain the storage information for the file with the specified id.
#
# @param id    The ID of the file to fetch the information for.
# @param order Sort position indicator for ordering.
# @return A reference to the file data on success, undef on error.
sub get_file_info {
    my $self  = shift;
    my $id    = shift;
    my $order = shift;

    $self -> clear_error();

    my $imgh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"files"}."`
                                            WHERE `id` = ?");
    $imgh -> execute($id)
        or return $self -> self_error("Unable to execute file lookup: ".$self -> {"dbh"} -> errstr);

    my $data = $imgh -> fetchrow_hashref();

    # copy in the order
    $data -> {"order"} = $order
        if($data);

    return $data || {};
}


## @method $ get_file_url($file, $mode, $defurl)
# Given an file hash or ID, generate the URL for the file.
#
# @param file  A reference to an file hash, or the Id of the file.
# @param mode   The file mode, must be one of 'icon', 'thumb', 'media', or 'large'
# @param defurl The URL to return if the file is not available.
sub get_file_url {
    my $self   = shift;
    my $file   = shift;
    my $mode   = shift;
    my $defurl = shift;

    my $url = $defurl;

    if($file) {
        # Fetch the file data if we don't have a hash
        $file = $self -> get_file_info($file)
            unless(ref($file) eq "HASH");

        $url = $file -> {"location"}
            if($file && $file -> {"id"});
    }

    # If the URL isn't absolute, make it so
    $url = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_file_url"}, $url)
        unless(!defined($url) || $url =~ m|^https?://|);

    return $url;
}


## @method $ store_file($srcfile, $filename, $userid)
# Given a source filename and a userid, move the file into the file filestore
# (if needed) and then return the information needed to attach to an article.
#
# @param srcfile  The absolute path to the source file to obtain a path for.
# @param filename The name of the file to write the source file to, without any path.
# @param userid   The ID of the user saving the file
# @return A reference to the file storage data hash on success, undef on error.
sub store_file {
    my $self     = shift;
    my $srcfile  = shift;
    my $filename = shift;
    my $userid   = shift;
    my $digest;

    $self -> clear_error();

    # Determine whether the file is allowed
    my $filetype = File::LibMagic -> new();
    my $info = $filetype -> info_from_filename($srcfile);

    my @types = sort(values(%{$self -> {"allowed_types"}}));
    return $self -> self_error("$filename is not a supported file format. Permitted formats are: ".join(", ", @types))
        unless($type && $self -> {"allowed_types"} -> {$info -> {"mime_type"}});

    # File is allowed type, but might be infected
    $self -> _virus_check($srcfile)
        or return undef;

    # Now, calculate the md5 of the file so that duplicate checks can be performed
    open(IMG, $srcfile)
        or return $self -> self_error("Unable to open uploaded file '$srcfile': $!");
    binmode(IMG); # probably redundant, but hey

    eval {
        $digest = Digest -> new("MD5");
        $digest -> addfile(*IMG);

        close(IMG);
    };
    return $self -> self_error("An error occurred while processing '$filename': $@")
        if($@);

    my $md5 = $digest -> hexdigest;

    # Determine whether a file already exists with the current md5. IF it does,
    # return the information for the existing file rather than making a new copy.
    my $exists = $self -> _md5_lookup($md5);
    if($exists || $self -> errstr()) {
        # Log the duplicate hit if appropriate.
        $self -> {"logger"} -> log('notice', $userid, undef, "Request to store file $filename, already exists as file $exists")
            if($exists);

        return $exists ? $self -> get_file_info($exists) : undef;
    }

    # File does not appear to be a duplicate, so moving it into the tree should be okay.
    # The first stage of this is to obtain a new file record ID to use as a unique
    # directory name.
    my $newid = $self -> _add_file($filename, $md5, $userid)
        or return undef;

    # Convert the id to a destination directory
    if(my $outdir = $self -> _build_destdir($newid)) {
        # Now build the paths needed for moving things
        my $outname = path_join($outdir, $filename);

        if($self -> _update_location($newid, $outname)) {
            $self -> {"logger"} -> log('notice', $userid, undef, "Storing file $filename in $outname, file id $newid");

            move($srcfile, $outname)
                or return $self -> self_error("Unable to move $filename into filestore: $!");

            # If all worked, return the information
            return $self -> get_file_info($newid);
        }
    }

    # Get here and something broke, save the error and clean up before returning it
    my $errstr = $self -> errstr();
    $self -> {"logger"} -> log('error', $userid, undef, "Unable to store image $filename: $errstr");

    $self -> _delete_file($newid);
    return $self -> self_error($errstr);
}


## @method $ add_file_relation($articleid, $fileid, $order)
# Add a relation between an article and an file
#
# @param articleid The ID of the article to add the relation for.
# @param fileid    The ID of the file to add the relation to.
# @param order     The order of the relation. The first file should be 1, second 2, and so on.
# @return The id of the new file association row on success, undef on error.
sub add_file_relation {
    my $self      = shift;
    my $articleid = shift;
    my $fileid    = shift;
    my $order     = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articlefiles"}."`
                                            (`article_id`, `file_id`, `order`)
                                            VALUES(?, ?, ?)");
    my $rows = $newh -> execute($articleid, $fileid, $order);
    return $self -> self_error("Unable to perform file relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("File relation insert failed, no rows inserted") if($rows eq "0E0");

    # MYSQL: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new file relation row")
        if(!$newid);

    return $newid;
}

# ============================================================================
#  Internals

## @method private $ _build_destdir($id)
# Given a file id, determine which directory the corresponding file should be stored
# in, and ensure that the directory tree is in place for it. Note that this will
# create a hierarchy of directories, up to 100 directories (00 to 99) at the top
# level, and with up to 100 directories (again, 0 to 99) in each of the top-level
# directories. This is to reduce the number of files and directories present in
# any single directory to help out filesystems that struggle with lots of either.
#
# @param id The ID of the file to store.
# @return A path to store the file in on success, undef on error.
sub _build_destdir {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    # Pad the id with zeros out to at least 4 characters
    my $pad    = 4 - length($id);
    my $padded = $pad > 0 ? ("0" x $pad).$id : $id;

    # Now pull out the bits, and rejoin them into the required form
    my ($base, $sub) = $padded =~ /^(\d\d)(\d\d)/;
    my $fullpath = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_file_path"}, $base, $sub, $id);

    eval { make_path($fullpath); };
    return $self -> self_error("Unable to create file store directory: $@")
        if($@);

    return $fullpath;
}


## @method private $ _md5_lookup($md5)
# Look up a file based on the provided md5. Why use MD5 rather than a more secure hash
# like SHA-256? Primarily as a result of speed (md5 is usually 30% faster), but also
# because getting duplicate files is really not the end of the world, this is here
# as a simple check to prevent egregious duplication of uploads by end users, rather
# than as a vital bastion against the many-angled ones that live at the bottom of the
# Mandelbrot set.
#
# @param md5 The hex-encoded MD5 digest to search for
# @return The ID of the file on success, undef if the md5 does not exist, or on error.
sub _md5_lookup {
    my $self = shift;
    my $md5  = shift;

    $self -> clear_error();

    # Does the md5 match an already present file?
    my $md5h = $self -> {"dbh"} -> prepare("SELECT id
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"files"}."`
                                            WHERE `md5` LIKE ?");
    $md5h -> execute($md5)
        or return $self -> self_error("Unable to perform file md5 search: ".$self -> {"dbh"} -> errstr);

    my $idrow = $md5h -> fetchrow_arrayref();
    return $idrow ? $idrow -> [0] : undef;
}


## @method private $ _add_file($name, $md5, $userid)
# Add an entry for a file to the files table.
#
# @param name   The name of the file file to add.
# @param md5    The md5 of the file file being added.
# @param userid The ID of the user adding the file.
# @return The id of the new file row on success, undef on error.
sub _add_file {
    my $self   = shift;
    my $name   = shift;
    my $md5    = shift;
    my $userid = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"files"}."`
                                            (md5, name, uploader, uploaded)
                                            VALUES(?, ?, ?, UNIX_TIMESTAMP())");
    my $rows = $newh -> execute($md5, $name, $userid);
    return $self -> self_error("Unable to perform file insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("File insert failed, no rows inserted") if($rows eq "0E0");

    # MYSQL: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new file row")
        if(!$newid);

    return $newid;
}


## @method private $ _delete_file($id)
# Remove the file entry for the specified row. This is primarily needed to
# clean up partial file entries that are created during store_file() if that
# function fails to copy the file into place.
#
# @param id The ID of the file row to remove.
# @return true on success, undef on error.
sub _delete_file {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"files"}."`
                                             WHERE id = ?");
    $nukeh -> execute($id)
        or return $self -> self_error("File delete failed: ".$self -> {"dbh"} -> errstr);

    return 1;
}


## @method private $ _update_location($id, $location)
# Update the file location for the specified file.
#
# @param id       The ID of the file to update the location for.
# @param location The location to set for the file.
# @return true on success, undef on error.
sub _update_location {
    my $self     = shift;
    my $id       = shift;
    my $location = shift;

    $self -> clear_error();

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"files"}."`
                                               SET `location` = ?
                                               WHERE `id` = ?");
    my $result = $updateh -> execute($location, $id);
    return $self -> self_error("Unable to update file location: ".$self -> {"dbh"} -> errstr) if(!$result);
    return $self -> self_error("File location update failed: no rows updated.") if($result eq "0E0");

    return 1;
}


## @method private $ _virus_check($srcfile)
# Run ClamAV on the specified file. This determines whether the file contains
# any viruses recorgnised by ClamAV.
#
# @param srcfile The name of the file to check with ClamAV.
# @return true if the file is clean, false if it contains a virus or an
#         error occurred during checking.
sub _virus_check {
    my $self    = shift;
    my $srcfile = shift;

    $self -> clear_error();

    my $clamav = File::Scan::ClamAV -> new();
    return $self -> self_error("File upload failed: ClamAV is not running")
        unless($clamav -> ping());

    my ($file, $virus) = $clamav -> scan($srcfile);
    return $self -> self_error("File upload failed: virus '$virus' found in uploaded file.")
        if($virus);

    return $self -> self_error("File upload failed: ".$clamav -> errstr())
        if(!$file && $clamav -> errstr());

    return 1;
}

1;