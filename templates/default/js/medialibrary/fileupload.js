var FileUpload = new Class({

    Implements: [Options],

    options: { droparea: null,
               dropelem: null,
               progelem: null,
               progtextelem: null,
               sortlist: null
    },

    initialize: function(options) {
        this.setOptions(options);

        this.sortlist = new CustomSortable(this.options.sortlist, { //clone: true,
		                                                            revert: true,
		                                                            opacity: 0.5,
                                                                    //dropClass: 'droplist',
                                                                    onStart: function() {  },
                                                                    onComplete: function() {  }
	                                         });

        this.uploader = new Form.Uploader($(this.options.dropelem), $(this.options.progelem), $(this.options.progtextelem),
                                          { url: api_request_path("webapi", "file.upload", basepath),
                                            onSuccess: function(respHTML) {
                                                // convert text to HTML (based on Resquest.HTML)
                                                var match = respHTML.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
		                                        if (match) respHTML = match[1];

                                                var temp = new Element('div').set('html', respHTML);
		                                        var row  = temp.childNodes[0];

                                                var err = respHTML.match(/^<div id="apierror"/);

                                                if(err) {
                                                    $('errboxmsg').set('html', respHTML);
                                                    errbox.open();

                                                // No error, content should be row.
                                                } else {
                                                    row.setStyle('display', 'none');
                                                    $('filelist').adopt(row);
                                                    row.reveal();

                                                    this.sortlist.addItems(row);
                                                }
                                            }.bind(this),
                                            onFailure: function()   { alert("Upload failed!"); }.bind(this),
                                            onDragenter: function() { $(this.options.droparea).addClass('hover'); }.bind(this),
			                                onDragleave: function() { $(this.options.droparea).removeClass('hover'); }.bind(this),
			                                onDrop: function()      { $(this.options.droparea).removeClass('hover'); }.bind(this),
			                                onRequest: function()   { $(this.options.droparea).addClass('disabled'); }.bind(this),
			                                onComplete: function()  { $(this.options.droparea).removeClass('disabled'); }.bind(this)
                                          });

    },

    serialize: function() {
        var files = this.sortlist.serialize();

        // Kill the 'file-' part - we only need IDs
        for(var i = 0; i < files.length; ++i) {
            files[i] = files[i].substr(5);
        }

        return files;
    }

});