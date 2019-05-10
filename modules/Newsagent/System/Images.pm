## @file
# This file contains the implementation of the image handling code.
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
package Newsagent::System::Images;

use strict;
use experimental 'smartmatch';
use base qw(Webperl::SystemModule); # This class extends the system module class
use v5.12;

use Digest;
use File::Path qw(make_path);
use File::Copy;
use File::Slurp;
use Webperl::Utils qw(path_join trimspace hash_or_hashref);
use Data::Dumper;

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
    $self -> {"allowed_types"} = { "image/png"  => "png",
                                   "image/jpeg" => "jpg",
                                   "image/gif"  => "gif",
    };

                                 # fill the 130x63 area (extending outside as needed), crop the image to 130x63 from the centre, repage to discard out-of-bounds canvas
    $self -> {"image_sizes"} = { "icon"  => '-resize 130x63^ -gravity Center -crop 130x63+0+0 +repage',

                                 # fill the 128x128 area (extending outside as needed), crop the image to 128x129 from the centre, repage to discard out-of-bounds canvas
                                 "media" => '-resize 128x128^ -gravity Center -crop 128x128+0+0 +repage' ,

                                 # fill the 500x298 area (extending outside as needed), crop the image to 500x298 from the centre, repage to discard out-of-bounds canvas
                                 "ppcompat" => '-resize 500x298^ -gravity Center -crop 500x298+0+0 +repage' ,

                                 # Fill the 350x167 area (extending outside as needed to preserve aspect)
                                 "thumb" => '-resize 350x167^',

                                 # Resize images down that are larger than 500x298, preserving aspect,
                                 # with fit to 500 width
                                 "large" => '-resize 500x298^',

                                 # Resize images to fit into the 2560x1440 tactus size, preserving aspect
                                 "tactus" => '-resize 2560x1440',
    };

    return $self;
}


# ============================================================================
#  Interface

## @method $ get_file_images(%args)
# Obtain a list of all images currently stored in the system. This generates
# a list of images, including all the image data needed for the media library.
#
# - `userid`: The ID of the user to filter the images by. If zero or undef,
#             images by all users are included.
# - `sort`:   The field to sort the images on. Valid values are 'uploaded' and 'name'
# - `offset`: The offset to start fetching images from.
# - `count`:  The number of images to fetch.
# @return A reference to an array of hashrefs to image data.
sub get_file_images {
    my $self = shift;
    my $args = hash_or_hashref(@_);

    $self -> clear_error();

    my $query = "SELECT `i`.*, `u`.`username`, `u`.`realname`, `u`.`email`
                 FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."` AS `i`,
                      `".$self -> {"settings"} -> {"database"} -> {"users"}."` AS `u`
                 WHERE `i`.`type` = 'file'
                 AND `u`.`user_id` = `i`.`uploader`";

    my @params = ();
    if($args -> {"userid"}) {
        $query .= " AND `uploader` = ? ";
        push(@params, $args -> {"userid"});
    }

     if($args -> {"id"}) {
        $query .= " AND `id` = ? ";
        push(@params, $args -> {"id"});
    }

    if($args -> {"md5"}) {
        $query .= " AND `md5` = ? ";
        push(@params, $args -> {"md5"});
    }

    if($args -> {"name"}) {
        $query .= " AND `name` LIKE ? ";
        push(@params, $args -> {"name"});
    }

    my $way;
    given($args -> {"sort"}) {
        when("uploaded") { $way = "DESC"; }
        when("name")     { $way = "ASC"; }
        default {
            $args -> {"sort"} = "uploaded";
            $way              = "DESC";
        }
    }
    $query .= " ORDER BY `".$args -> {"sort"}."` $way";

    $args -> {"offset"} = 0
        if(!defined($args -> {"offset"}) && $args -> {"limit"});

    if(defined($args -> {"offset"}) && $args -> {"limit"}) {
        $query .= " LIMIT ".$args -> {"offset"};
        $query .= ",".$args -> {"limit"} if($args -> {"limit"});
    }

    my $imgh = $self -> {"dbh"} -> prepare($query);
    $imgh -> execute(@params)
        or return $self -> self_error("Unable to execute image list query: ".$self -> {"dbh"} -> errstr);

    my $results = $imgh -> fetchall_arrayref({})
        or return $self -> self_error("Unable to fetch image list query: ".$self -> {"dbh"} -> errstr);

    foreach my $image (@{$results}) {
        # Work out the user's name
        $image -> {"fullname"} = $image -> {"realname"} || $image -> {"username"};

        # Make the user gravatar hash
        my $digest = Digest -> new("MD5");
        $digest -> add(lc(trimspace($image -> {"email"} || "")));
        $image -> {"gravatar_hash"} = $digest -> hexdigest;

        # And build the loading paths
        foreach my $size (keys(%{$self -> {"image_sizes"}})) {
            $image -> {"path"} -> {$size} = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"}, $size, $image -> {"location"});
        }
    }

    return $results;
}


## @method $ get_image_info($id, $order)
# Obtain the storage information for the image with the specified id.
#
# @param id    The ID of the image to fetch the information for.
# @param order Sort position indicator for ordering.
# @return A reference to the image data on success, a reference to an
#         empty hash if the image does not exist, undef on error.
sub get_image_info {
    my $self  = shift;
    my $id    = shift;
    my $order = shift;

    $self -> clear_error();

    my $imgh = $self -> {"dbh"} -> prepare("SELECT *
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            WHERE `id` = ?");
    $imgh -> execute($id)
        or return $self -> self_error("Unable to execute image lookup: ".$self -> {"dbh"} -> errstr);

    my $data = $imgh -> fetchrow_hashref();
    if($data) {
        foreach my $size (keys(%{$self -> {"image_sizes"}})) {
            if($data -> {"type"} eq "file") {
                # Only include the image at this size if it exists.
                $data -> {"path"} -> {$size} = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"}, $size, $data -> {"location"})
                    if(-f path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_path"}, $size, $data -> {"location"}));
            } else {
                $data -> {"path"} -> {$size} = $data -> {"location"};
            }
        }

        # copy in the order
        $data -> {"order"} = $order;
    }

    return $data || {};
}


## @method $ get_image_url($image, $mode, $defurl)
# Given an image hash or ID, generate the URL the image may be found at
# based on the image type and mode.
#
# @param image  A reference to an image hash, or the Id of the image.
# @param mode   The image mode, must be one of 'icon', 'thumb', 'media', 'ppcompat', or 'large'
# @param defurl The URL to return if the image is not available.
sub get_image_url {
    my $self   = shift;
    my $image  = shift;
    my $mode   = shift;
    my $defurl = shift;

    my $url = $defurl;

    if($image) {
        # Fetch the image data if we don't have a hash
        $image = $self -> get_image_info($image)
            unless(ref($image) eq "HASH");

        # If image is still defined, we have a hash...
        if($image && $image -> {"id"}) {
            given($image -> {"type"}) {
                when("url")  { $url = $image -> {"location"}; }
                when('file') { $url = $image -> {"path"} -> {$mode}; }
            }
        }
    }

    # If the URL isn't absolute, make it so
    $url = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_url"}, $url)
        unless(!defined($url) || $url =~ m|^https?://|);

    return $url;
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

    # Slurp the file into memory. This is possibly a Bad Idea, but File::LibMagic
    # can not handle reading from $srcfile directly.
    my $data = read_file($srcfile, binmode => ':raw');

    # Determine whether the file is allowed
    my $info = $self -> {"magic"} -> info_from_string($data);

    my @types = sort(values(%{$self -> {"allowed_types"}}));
    return $self -> self_error("$filename is not a supported image format (".$info -> {"mime_type"}."). Permitted formats are: ".join(", ", @types))
        unless($info && $self -> {"allowed_types"} -> {$info -> {"mime_type"}});

    # Now, calculate the md5 of the file so that duplicate checks can be performed
    eval {
        $digest = Digest -> new("MD5");
        $digest -> add($data);
    };
    return $self -> self_error("An error occurred while processing '$filename': $@")
        if($@);

    my $md5 = $digest -> hexdigest;

    # Determine whether a file already exists with the current md5. IF it does,
    # return the information for the existing file rather than making a new copy.
    my $exists = $self -> _md5_lookup($md5);
    if($exists || $self -> errstr()) {
        # Log the duplicate hit if appropriate.
        $self -> {"logger"} -> log('notice', $userid, undef, "Request to store image $filename, already exists as image $exists")
            if($exists);

        return $exists ? $self -> get_image_info($exists) : undef;
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
            $self -> {"logger"} -> log('notice', $userid, undef, "Storing image $filename in $outname, image id $newid");

            my $converted = 1;
            # Go through the required sizes, converting the source image
            foreach my $size (keys(%{$self -> {"image_sizes"}})) {
                my $outpath = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_path"}, $size, $outname);
                my ($cleanout) = $outpath =~ m|^((?:/[-\w.]+)+?(?:\.\w+)?)$|;

                if(!$self -> _convert($srcfile, $cleanout, $self -> {"image_sizes"} -> {$size})) {
                    $converted = 0;
                    last;
                }
            }

            # If all worked, return the information
            return $self -> get_image_info($newid)
                if($converted);
        }
    }

    # Get here and something broke, save the error and clean up before returning it
    my $errstr = $self -> errstr();
    $self -> {"logger"} -> log('error', $userid, undef, "Unable to store image $filename: $errstr");

    $self -> _delete_image($newid);
    return $self -> self_error($errstr);
}


## @method $ add_url($url)
# Add an entry for a url to the images table.
#
# @param url The url of the image link to add.
# @return The id of the new image file row on success, undef on error.
sub add_url {
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

    # MYSQL: This ties to MySQL, but is more reliable that last_insert_id in general.
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


## @method $ add_image_relation($articleid, $imageid, $order)
# Add a relation between an article and an image
#
# @param articleid The ID of the article to add the relation for.
# @param imageid   The ID of the image to add the relation to.
# @param order     The order of the relation. The first imge should be 1, second 2, and so on.
# @return The id of the new image association row on success, undef on error.
sub add_image_relation {
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

    # MYSQL: This ties to MySQL, but is more reliable that last_insert_id in general.
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
# @return A path to store the file in, relative to Article:upload_image_path, on success.
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

    # Make sure the paths exist
    foreach my $size (keys(%{$self -> {"image_sizes"}})) {
        my $fullpath = path_join($self -> {"settings"} -> {"config"} -> {"Article:upload_image_path"}, $size, $destdir);
        eval { make_path($fullpath); };
        return $self -> self_error("Unable to create image store directory: $@")
            if($@);
    }

    return $destdir;
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
# @return The ID of the image on success, undef if the md5 does not exist, or on error.
sub _md5_lookup {
    my $self = shift;
    my $md5  = shift;

    $self -> clear_error();

    # Does the md5 match an already present image?
    my $md5h = $self -> {"dbh"} -> prepare("SELECT id
                                            FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            WHERE `md5` LIKE ?");
    $md5h -> execute($md5)
        or return $self -> self_error("Unable to perform image md5 search: ".$self -> {"dbh"} -> errstr);

    my $idrow = $md5h -> fetchrow_arrayref();
    return $idrow ? $idrow -> [0] : undef;
}


## @method private $ _add_file($name, $md5, $userid)
# Add an entry for a file to the images table.
#
# @param name   The name of the image file to add.
# @param md5    The md5 of the image file being added.
# @param userid The ID of the user adding the image.
# @return The id of the new image file row on success, undef on error.
sub _add_file {
    my $self   = shift;
    my $name   = shift;
    my $md5    = shift;
    my $userid = shift;

    $self -> clear_error();

    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO `".$self -> {"settings"} -> {"database"} -> {"images"}."`
                                            (type, md5, name, uploader, uploaded)
                                            VALUES('file', ?, ?, ?, UNIX_TIMESTAMP())");
    my $rows = $newh -> execute($md5, $name, $userid);
    return $self -> self_error("Unable to perform image file insert: ". $self -> {"dbh"} -> errstr) if(!$rows);
    return $self -> self_error("Image file insert failed, no rows inserted") if($rows eq "0E0");

    # MYSQL: This ties to MySQL, but is more reliable that last_insert_id in general.
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

    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM `".$self -> {"settings"} -> {"database"} -> {"images"}."`
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


## @method private $ _convert($source, $dest, $operation)
# Given a source filename and a destination to write it to, apply the specified
# conversion operation to it.
#
# @param source    The name of the image file to convert.
# @param dest      The destination to write the converted file to.
# @param operation The ImageMagick operation(s) to apply.
# @return true on success, undef on error.
sub _convert {
    my $self      = shift;
    my $source    = shift;
    my $dest      = shift;
    my $operation = shift;

    # NOTE: this does not use Image::Magick, instead it invokes `convert` directly.
    # The conversion steps are established to work correctly in convert, and
    # image conversion is a rare enough operation that the overhead of going out
    # to another process is not onerous. It could be done using Image::Magick,
    # but doing so will require replication of the steps `convert` already does
    # not sure that much effort is worth it, really.
    my $cmd = join(" ", ($self -> {"settings"} -> {"config"} -> {"Media:convert_path"}, $source, $operation, $dest));

    my $result = `$cmd 2>&1`;
    return $self -> self_error("Image conversion failed: $result")
        if($result);

    return 1;
}

1;