/*
---
name: Form.Upload
description: Updated implementation of Form.Upload by Arian Stolwijk
license: MIT-style license.

authors:
- Chris Page

requires:
- core/1.5.1: [Request, Options, Events]
- Request.File

provides: Form.Upload

...
 */

/* This is loosely based on the Form.Upload code originally written by Arian Stolwijk
 * with a number of notable changes. In particular, this version of the
 * class does not support multiple file uploads per request, as it is intended
 * to be used to handle individual media file uploads, and it does not support
 * fallback for brwosers without FormData support (notably IE before v10)
 */

(function() {

// Enable listeners for drag events. This is safe to include even if other D&D
// stuff has been enabled.
Object.append(Element.NativeEvents, {
	dragenter: 2, dragleave: 2, dragover: 2, dragend: 2, drop: 2
});

if (!this.Form) this.Form = {};
var Form = this.Form;

Form.Uploader = new Class({

    Implements: [Options, Events],

    options: {
        url: "",
        param: 'upload',
        uploadmsg: 'Uploading file: {loaded} of {total} ({percent}% complete)',
        donemsg: 'Complete'/*,
        onSuccess:,
        onFailure:,
        */
    },

    /** Initialise a new Form.Upload object. This allows users to drag and drop
     *  files onto an arbitrary element on the page and have it uploaded to the
     *  URL specified in the options.
     *
     * @param dropArea    (mixed) The element users should be able to drag files onto to upload them.
     * @param progress    (mixed) The element to update the width of to indicate upload progress.
     * @param progressMsg (mixed) The element to update with the upload progress message.
     * @param options     (object) The options to set for the new Form.Upload object.
     */
    initialize: function(dropArea, progress, progressMsg, options) {
        this.hasFormData = ('FormData' in window);
        this.progress = $(progress);
        this.progmess = $(progressMsg);
        this.dropArea = $(dropArea);

        this.setOptions(options);

        // build the request object used to upload files. Note that this handles most
        // of the behaviour of the uploader - performing th eupload, and maintaining
        // the progress information in the page.
        this.request = new Request.File({ url: this.options.url,
                                          onRequest: function() {
                                              this.progress.setStyles({ display: 'block', width: 0});
                                              this.dropArea.addClass("disabled");
                                              this.progmess.set('html', this.options.uploadmsg.substitute({'loaded': 0,
                                                                                                           'total': 0,
                                                                                                           'percent': 0}));
                                              this.fireEvent('request');
                                          }.bind(this),
                                          onProgress: function(event) {
                                              var loaded = event.loaded, total = event.total;
                                              var percent = parseInt(loaded / total * 100, 10).limit(0, 100);
                                              this.progress.setStyle('width', percent + '%');
                                              this.progmess.set('html', this.options.uploadmsg.substitute({'loaded': this.filesize_format(loaded),
                                                                                                           'total': this.filesize_format(total),
                                                                                                           'percent': percent}));
                                          }.bind(this),
                                          onComplete: function(){
                                              this.progress.setStyle('width', '0');
                                              this.dropArea.removeClass("disabled");
                                              this.request.reset();
                                              this.progmess.set('html', this.options.donemsg);
                                              this.fireEvent('complete');
                                          }.bind(this),
                                          onSuccess: function(responseText, responseXML) {
                                              this.fireEvent('success', responseText, responseXML);
                                          }.bind(this),
                                          onFailure: function(xhr) {
                                              this.fireEvent('failure', xhr);
                                          }.bind(this)
                                        });

        // Attach the drag and drop events to the drop area. Note that the drag
        // and drop events only do anything if an upload is not in progress
        this.dropArea.addEvents({"dragenter": function() { if(!this.request.isRunning()) this.fireEvent('dragenter'); }.bind(this),
                                 "dragleave": function() { if(!this.request.isRunning()) this.fireEvent('dragleave'); }.bind(this),
                                 "dragend":   function() { if(!this.request.isRunning()) this.fireEvent('dragend'); }.bind(this),
                                 "dragover":  function(event) {
                                     event.preventDefault();
                                     if(!this.request.isRunning()) this.fireEvent('dragover', event);
                                 }.bind(this),
                                 "drop": function(event) {
                                     event.preventDefault();
                                     if(!this.request.isRunning()) {
                                         var dataTransfer = event.event.dataTransfer;
                                         if (dataTransfer) this.send(dataTransfer.files[0]);
                                         this.fireEvent('drop', event);
                                     }
                                 }.bind(this)});
    },

    /** Send a file to the server. This starts the upload of the file to the
     *  url specified when creating the Form.Upload object. Can be invoked directly
     *  to upload a file as if it had been dropped into the drop area (so that an input
     *  field can be used to select the file instead, for example).
     *
     * Note that this will do nothing if an upload is currently in progress.
     *
     * @param file (File) The file to upload to the server.
     */
    send: function(file) {
        // do nothing if the request is working
        if(this.request.isRunning()) return this;

        // Reset the request before sending the file, to be sure it can't be sent twice.
        this.request.reset();
        this.request.append(this.options.param, file);
        this.request.send();

        return this;
    },

    /** Format a number into a more reabable form. This takes a number and generates
     *  a string representation for it, optionally including thousand separators and
     *  limiting the number of decimal places included.
     *
     * @param number   (number) The number to convert to a string.
     * @param decimals (integer) The maximum number of decimal places to include in the output.
     * @param dec_point (string, defaults to '.') The string to use as the decimal point indicator.
     * @param thousands_sep (string, defaults to ',') The string to use as the thousands separator.
     *                      Set to '' to suppress thousands separators.
     */
    number_format: function( number, decimals, dec_point, thousands_sep ) {
	    // http://kevin.vanzonneveld.net
	    // +   original by: Jonas Raoni Soares Silva (http://www.jsfromhell.com)
	    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +	 bugfix by: Michael White (http://crestidg.com)
	    // +	 bugfix by: Benjamin Lupton
	    // +	 bugfix by: Allan Jensen (http://www.winternet.no)
	    // +	revised by: Jonas Raoni Soares Silva (http://www.jsfromhell.com)
        // +   modified by: Chris Page
	    // *	 example 1: number_format(1234.5678, 2, '.', '');
	    // *	 returns 1: 1234.57
	    var n = number;
        var c = isNaN(decimals = Math.abs(decimals)) ? 2 : decimals;
	    var d = dec_point == undefined ? "." : dec_point;
	    var t = thousands_sep == undefined ? "," : thousands_sep;
        var s = n < 0 ? "-" : "";
	    var i = parseInt(n = Math.abs(+n || 0).toFixed(c)) + "", j = (j = i.length) > 3 ? j % 3 : 0;

	    return s + (j ? i.substr(0, j) + t : "") + i.substr(j).replace(/(\d{3})(?=\d)/g, "$1" + t) + (c ? d + Math.abs(n - i).toFixed(c).slice(2) : "");
    },

    /** Convert the specified file size to a 'human-readable' string. This
     *  generates a string giving the file size in the most appropriate
     *  units (gigabytes, megabytes, kilobytes, or just bytes).
     *
     *  @param filesize (integer) The file size to convert to a string.
     *  @return A human-readable version of the filesize.
     */
    filesize_format: function(filesize) {
        // Taken from https://github.com/milanvrekic/JS-humanize
        // + Modified by: Chris Page

	    if(filesize >= 1073741824) {
		    filesize = this.number_format(filesize / 1073741824, 2, '.', '') + ' GB';
	    } else if(filesize >= 1048576) {
	 		filesize = this.number_format(filesize / 1048576, 2, '.', '') + ' MB';
   	    } else if(filesize >= 1024) {
			filesize = this.number_format(filesize / 1024, 0) + ' KB';
  		} else {
			filesize = this.number_format(filesize, 0) + ' bytes';
		};

	    return filesize;
    }
});

// Invoke with this set to window.
}).call(window);