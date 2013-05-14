## @file
# This file contains the implementation of the article model.
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
package Newsagent::System::Article;

use strict;
use base qw(Webperl::SystemModule); # This class extends the Newsagent block class
use v5.12;

use File::Path qw(make_path);
use File::Copy;
use File::Type;
use Digest;
use Webperl::Utils qw(path_join);


## @cmethod $ new(%args)
# Create a new Article object to manage tag allocation and lookup.
# The minimum values you need to provide are:
#
# * dbh       - The database handle to use for queries.
# * settings  - The system settings object
# * metadata  - The system Metadata object.
# * logger    - The system logger object.
#
# @param args A hash of key value pairs to initialise the object with.
# @return A new Article object, or undef if a problem occured.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_)
        or return undef;

    # Check that the required objects are present
    return Webperl::SystemModule::set_error("No metadata object available.") if(!$self -> {"metadata"});
    return Webperl::SystemModule::set_error("No roles object available.")    if(!$self -> {"roles"});

    # Allowed file types
    $self -> {"allowed_types"} = { "image/x-png" => "png",
                                   "image/jpeg"  => "jpg",
                                   "image/gif"   => "gif",
    };

    return $self;
}


sub get_user_levels {
    my $self = shift;
    my $user = shift;

    $self -> clear_error();

    my $levelsh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"levels"}."`
                                               ORDER BY `id`");
    $levelsh -> execute()
        or return $self -> self_error("Unable to execute user levels query: ".$self -> {"dbh"} -> errstr);

    my @levellist;
    while(my $level = $levelsh -> fetchrow_hashref()) {
        # FIXME: Check user permission for level here?

        push(@levellist, {"name"  => $level -> {"description"},
                          "value" => $level -> {"level"}});
    }

    return \@levellist;
}


sub get_user_sites {
    my $self = shift;
    my $user = shift;

    $self -> clear_error();

    my $sitesh = $self -> {"dbh"} -> prepare("SELECT * FROM `".$self -> {"settings"} -> {"database"} -> {"sites"}."`
                                              ORDER BY `name`");
    $sitesh -> execute()
        or return $self -> self_error("Unable to execute user sites query: ".$self -> {"dbh"} -> errstr);

    my @sitelist;
    while(my $site = $sitesh -> fetchrow_hashref()) {
        # FIXME: Check user permission for site here?

        push(@sitelist, {"name"  => $site -> {"description"}." (".$site -> {"full_url"}.")",
                         "value" => $site -> {"name"}});
    }

    return \@sitelist;
}


sub get_file_images {
    my $self = shift;

    $self -> clear_error();

    my $imgh = $self -> {"dbh"} -> prepare("SELECT id, name, location
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            WHERE `type` = 'file'
                                            ORDER BY `name`");
    $imgh -> execute()
        or return $self -> self_error("Unable to execute image list query: ".$self -> {"dbh"} -> errstr);

    my @imagelist;
    while(my $image = $imgh -> fetchrow_hashref()) {
        push(@imagelist, {"name"  => $image -> {"name"},
                          "title" => path_join($self -> {"settings"} -> {"config"} -> {"upload_image_url"}, $image -> {"location"}),
                          "value" => $image -> {"id"}});
    }

    return \@imagelist;
}


## @method $ get_image_info($id)
# Obtain the storage information for the image with the specified id.
#
# @param id The ID of the image to fetch the information for.
# @return A reference to the image data on success, undef on error.
sub get_image_info {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $imgh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            WHERE `id` = ?");
    $imgh -> execute($id)
        or return $self -> self_error("Unable to execute image lookup: ".$self -> {"dbh"} -> errstr);

    return $imgh -> fetchrow_hashref();
}


## @method $ store_image($srcfile, $filename, $userid)
# Given a source filename and a userid, move the file into the image filestore
# (if needed) and then return the information needed to attach to an article.
#
# @param srcfile  The absolute path to the source file to obtain a path for.
# @param filename The name of the file to write the source file to, without any path.
# @param userid   The ID of the user saving the file
# @return A reference to the image storage data hash on success, undef on error.
sub store_image {
    my $self     = shift;
    my $srcfile  = shift;
    my $filename = shift;
    my $userid   = shift;
    my $digest;

    $self -> clear_error();

    # Determine whether the file is allowed
    my $filetype = File::Type -> new();
    my $type = $filetype -> mime_type($srcfile);

    my @types = sort(values(%{$self -> {"allowed_types"}}));
    return $self -> self_error("$filename is not a supported image format. Permitted formats are: ".join(", ", @types))
        unless($type && $self -> {"allowed_types"} -> {$type});

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
    my $exists = $self -> _file_md5_lookup($md5);
    if($exists || $self -> errstr()) {
        # Log the duplicate hit if appropriate.
        $self -> {"logger"} -> log('notice', $userid, undef, "Request to store image $filename, already exists as image ".$exists -> {"id"})
            if($exists);

        return $exists;
    }

    # File does not appear to be a duplicate, so moving it into the tree should be okay.
    # The first stage of this is to obtain a new file record ID to use as a unique
    # directory name.
    my $newid = $self -> _add_file($filename, $md5)
        or return undef;

    # Convert the id to a destination directory
    if(my $outdir = $self -> _build_destdir($newid)) {
        # Now build the paths needed for moving things
        my $outname = path_join($outdir, $filename);
        my $outpath = path_join($self -> {"settings"} -> {"config"} -> {"upload_image_path"}, $outname);

        my ($cleanout) = $outpath =~ m|^((?:/[-\w.]+)+?(?:\.\w+)?)$|;

        if(copy($srcfile, $cleanout)) {
            if($self -> _update_location($newid, $outname)) {
                $self -> {"logger"} -> log('notice', $userid, undef, "Stored image $filename in $outname, image id $newid");

                return $self -> get_image_info($newid);
            }
        } else {
            $self -> self_error("Unable to copy image file $filename: $!");
        }
    }

    # Get here and something broke, save the error and clean up before returning it
    my $errstr = $self -> errstr();
    $self -> {"logger"} -> log('error', $userid, undef, "Unable to store image $filename: $errstr");

    $self -> _delete_image($newid);
    return $self -> self_error($errstr);
}


## @method $ add_article($article, $userid, $previd)
# Add an article to the system's database. This function adds an article to the system
# using the contents of the specified hash to fill in the article fields in the db.
#
# @param article A reference to a hash containing article data, as generated by the
#                _validate_article_fields() function.
# @param userid  The ID of the user creating this article.
# @oaram previd  The ID of a previous revision of the article.
# @return The ID of the new article on success, undef on error.
sub add_article {
    my $self    = shift;
    my $article = shift;
    my $userid  = shift;
    my $previd  = shift;

    $self -> clear_error();

    # Add urls to the database
    foreach my $id (keys(%{$article -> {"images"}})) {
        if($article -> {"images"} -> {$id} -> {"mode"} eq "url") {
            $article -> {"images"} -> {$id} -> {"img"} = $self -> _add_url($article -> {"images"} -> {$id} -> {"url"})
                or return undef;
        }
    }

    # Add the article itself
    my $addh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articles"}."`
                                            (previous_id, creator_id, created, site_id, title, summary, article, release_mode, release_time)
                                            VALUES(?, ?, UNIX_TIMESTAMP(), ?, ?, ?, ?, ?, ?)");
    my $rows = $addh -> execute($previd, $userid, $article -> {"site"}, $article -> {"title"}, $article -> {"summary"}, $article -> {"article"}, $article -> {"mode"}, $article -> {"rtimestamp"});
    return $self -> self_error("Unable to perform article insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Article insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new article row")
        if(!$newid);

    # Now set up image and level associations
    $self -> _add_image_relation($newid, $article -> {"images"} -> {"a"} -> {"img"}, 0) or return undef
        if($article -> {"images"} -> {"a"} -> {"img"});

    $self -> _add_image_relation($newid, $article -> {"images"} -> {"b"} -> {"img"}, 1) or return undef
        if($article -> {"images"} -> {"b"} -> {"img"});

    foreach my $level (keys(%{$article -> {"levels"}})) {
        $self -> _add_level_relation($newid, $level)
            or return undef;
    }

    return $newid;
}


# ==============================================================================
# Private methods


## @method private $ _build_destdir($id)
# Given a file id, determine which directory the corresponding file should be stored
# in, and ensure that the directory tree is in place for it. Note that this will
# create a hierarchy of directories, up to 100 directories (00 to 99) at the top
# level, and with up to 100 directories (again, 0 to 99) in each of the top-level
# directories. This is to reduce the number of files and directories present in
# any single directory to help out filesystems that struggle with lots of either.
#
# @param id The ID of the file to store.
# @return A path to store the file in, relative to upload_image_path, on success.
#         undef on error.
sub _build_destdir {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    # Pad the id with zeros out to at least 4 characters
    my $pad    = 4 - length($id);
    my $padded = $pad > 0 ? ("0" x $pad).$id : $id;

    # Now pull out the bits, and rejoin them into the required form
    my ($base, $sub) = $padded =~ /^(\d\d)(\d\d)/;
    my $destdir = path_join($base, $sub, $id);

    # Make sure the path exists
    my $fullpath = path_join($self -> {"settings"} -> {"config"} -> {"upload_image_path"}, $destdir);
    eval { make_path($fullpath); };
    return $self -> self_error("Unable to create image store directory: $@")
        if($@);

    return $destdir;
}


## @method private $ _file_md5_lookup($md5)
# Look up a file based on the provided md5. Why use MD5 rather than a more secure hash
# like SHA-256? Primarily as a result of speed (md5 is usually 30% faster), but also
# because getting duplicate files is really not the end of the world, this is here
# as a simple check to prevent egregious duplication of uploads by end users, rather
# than as a vital bastion against the many-angled ones that live at the bottom of the
# Mandelbrot set.
#
# @param md5 The hex-encoded MD5 digest to search for
# @return A reference to an image record hash on success, undef if the md5 does
#         not exist, or on error.
sub _file_md5_lookup {
    my $self = shift;
    my $md5  = shift;

    $self -> clear_error();

    # Does the md5 match an already present image?
    my $md5h = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            WHERE `md5` LIKE ?");
    $md5h -> execute($md5)
        or return $self -> self_error("Unable to perform image md5 search: ".$self -> {"dbh"} -> errstr);

    return $md5h -> fetchrow_hashref();
}


## @method private $ _add_file($name, $md5)
# Add an entry for a file to the images table.
#
# @param name The name of the image file to add.
# @param md5  The md5 of the image file being added.
# @return The id of the new image file row on success, undef on error.
sub _add_file {
    my $self = shift;
    my $name = shift;
    my $md5  = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            (type, md5, name)
                                            VALUES('file', ?, ?)");
    my $rows = $newh -> execute($md5, $name);
    return $self -> self_error("Unable to perform image file insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Image file insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new image file row")
        if(!$newid);

    return $newid;
}


## @method private $ _add_url($url)
# Add an entry for a url to the images table.
#
# @param url The url of the image link to add.
# @return The id of the new image file row on success, undef on error.
sub _add_url {
    my $self = shift;
    my $url  = shift;

    $self -> clear_error();

    # Work out the name
    my ($name) = $url =~ m|/([^/]+?)(\?.*)?$|;
    $name = "unknown" if(!$name);

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            (type, name, location)
                                            VALUES('url', ?, ?)");
    my $rows = $newh -> execute($name, $url);
    return $self -> self_error("Unable to perform image url insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Image url insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new image url row")
        if(!$newid);

    return $newid;
}


## @method private $ _delete_image($id)
# Remove the file entry for the specified row. This is primarily needed to
# clean up partial file entries that are created during store_image() if that
# function fails to copy the image into place.
#
# @param id The ID of the image row to remove.
# @return true on success, undef on error.
sub _delete_image {
    my $self = shift;
    my $id   = shift;

    $self -> clear_error();

    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"image"}."`
                                             WHERE id = ?");
    $nukeh -> execute($id)
        or return $self -> self_error("Image delete failed: ".$self -> {"dbh"} -> errstr);

    return 1;
}


## @method private $ _update_location($id, $location)
# Update the image location for the specified image.
#
# @param id       The ID of the image to update the location for.
# @param location The location to set for the image.
# @return true on success, undef on error.
sub _update_location {
    my $self     = shift;
    my $id       = shift;
    my $location = shift;

    $self -> clear_error();

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                               SET `location` = ?
                                               WHERE `id` = ?");
    my $result = $updateh -> execute($location, $id);
    return $self -> self_error("Unable to update file location: ".$self -> {"dbh"} -> errstr) if(!$result);
    return $self -> self_error("File location update failed: no rows updated.") if($result eq "0E0");

    return 1;
}


## @method private $ _add_image_relation($articleid, $imageid, $order)
# Add a relation between an article and an image
#
# @param articleid The ID of the article to add the relation for.
# @param imageid   The ID of the image to add the relation to.
# @param order     The order of the relation. The first imge should be 1, second 2, and so on.
# @return The id of the new image association row on success, undef on error.
sub _add_image_relation {
    my $self      = shift;
    my $articleid = shift;
    my $imageid   = shift;
    my $order     = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            (article_id, image_id, order)
                                            VALUES('?, ?, ?)");
    my $rows = $newh -> execute($articleid, $imageid, $order);
    return $self -> self_error("Unable to perform image file insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Image file insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new image file row")
        if(!$newid);

    return $newid;
}


## @method private $ _add_image_relation($articleid, $imageid, $order)
# Add a relation between an article and an image
#
# @param articleid The ID of the article to add the relation for.
# @param imageid   The ID of the image to add the relation to.
# @param order     The order of the relation. The first imge should be 1, second 2, and so on.
# @return The id of the new image association row on success, undef on error.
sub _add_image_relation {
    my $self      = shift;
    my $articleid = shift;
    my $imageid   = shift;
    my $order     = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articleimages"}."`
                                            (`article_id`, `image_id`, `order`)
                                            VALUES(?, ?, ?)");
    my $rows = $newh -> execute($articleid, $imageid, $order);
    return $self -> self_error("Unable to perform image relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Image relation insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new image relation row")
        if(!$newid);

    return $newid;
}


## @method private $ _get_level_byname($name)
# Obtain the ID of the level with the specified name, if possible.
#
# @param name The name of the level to get the ID for
# @return the level ID on success, undef on failure
sub _get_level_byname {
    my $self  = shift;
    my $level = shift;

    my $levelh = $self -> {"dbh"} -> prepare("SELECT id FROM `".$self -> {"settings"} -> {"database"} -> {"levels"}."`
                                              WHERE `level` LIKE ?");
    $levelh -> execute($level)
        or return $self -> self_error("Unable to execute level lookup query: ".$self -> {"dbh"} -> errstr);

    my $levrow = $levelh -> fetchrow_arrayref()
        or return $self -> self_error("Request for non-existent level '$level', giving up");

    return $levrow -> [0];
}


## @method private $ _add_level_relation($articleid, $level)
# Add a relation between an article and a level
#
# @param articleid The ID of the article to add the relation for.
# @param level     The title (NOT the ID!) of the level to add the relation to.
# @return The id of the new level association row on success, undef on error.
sub _add_level_relation {
    my $self      = shift;
    my $articleid = shift;
    my $level     = shift;

    $self -> clear_error();

    my $levelid = $self -> _get_level_byname($level)
        or return undef;

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"articlelevels"}."`
                                            (`article_id`, `level_id`)
                                            VALUES(?, ?)");
    my $rows = $newh -> execute($articleid, $levelid);
    return $self -> self_error("Unable to perform level relation insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Level relation insert failed, no rows inserted") if($rows eq "0E0");

    # FIXME: This ties to MySQL, but is more reliable that last_insert_id in general.
    #        Try to find a decent solution for this mess...
    # NOTE: the DBD::mysql documentation doesn't actually provide any useful information
    #       about what this will contain if the insert fails. In fact, DBD::mysql calls
    #       libmysql's mysql_insert_id(), which returns 0 on error (last insert failed).
    #       There, why couldn't they bloody /say/ that?!
    my $newid = $self -> {"dbh"} -> {"mysql_insertid"};

    return $self -> self_error("Unable to obtain id for new level relation row")
        if(!$newid);

    return $newid;
}


1;
