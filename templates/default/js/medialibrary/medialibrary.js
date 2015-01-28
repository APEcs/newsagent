var MediaLibrary = new Class({

    Implements: [Options],

    options: {
        title: 'Image Library',
        selectTxt: 'Select',
        cancelTxt: 'Cancel',
        loadingTxt: 'Loading, please wait...',
        mode: 'media', /* valid values: icon, media, thumb, large */
        width: '1000px'
    },

    initialize: function(button, idstore, options) {
        this.button  = $(button);
        this.idstore = $(idstore);
        this.setOptions(options);

        this.popup   = new LightFace({title: this.options.title,
                                      draggable: false,
                                      overlayAll: true,
                                      content: '',
                                      zIndex: 8001,
                                      pad: 200,
                                      width: "1000px",
                                      height: "560px",
                                      buttons: [ { title: this.options.selectTxt,
                                                   color: 'blue',
                                                   event: function() { this.selectImage(); }.bind(this) },
                                                 { title: this.options.cancelTxt,
                                                   color: 'blue',
                                                   event: function() { this.popup.close(); this.loadingBody(); }.bind(this) }
                                               ]});

        this.button.addEvent('click', function(event) { event.preventDefault();
                                                        this.open();
                                                      }.bind(this));
    },

    loadingBody: function() {
        var loading = new Element('div', { 'class': 'loading' }).adopt(
            new Element('img', { src: spinner_imgurl,
                                 styles: { 'width': 16,
                                           'height': 16,
                                           'alt': "working" }}),
            new Element('span', { html: this.options.loadingTxt })
        );

        this.popup.setContent(loading);
    },

    open: function() {
        // Do nothing if the popup is already open
        if(this.popup.isOpen) return this;

        // Otherwise clear any old body, and then start the load
        this.loadingBody();
        this.popup.open();

        this.loadReq = new Request.HTML({ url: api_request_path("webapi", "media.open", basepath),
                                          method: 'post',
                                          onSuccess: function(espTree, respElems, respHTML) {
                                              this.popup.messageBox.fade('out').get('tween').chain(function() {
                                                  this.popup.messageBox.set('html', respHTML);

                                                  this.uploader = new Form.Uploader('ml-dropzone', 'ml-progress', 'ml-progressmsg',
                                                                                    { url: api_request_path("webapi", "media.upload", basepath),
                                                                                      args: {'mode': this.options.mode },
                                                                                      onSuccess: function(respText, respXML) {
                                                                                          var err = respXML.getElementsByTagName("error")[0];
                                                                                          if(err) {
                                                                                              $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                                                                              errbox.open();
                                                                                          } else {
                                                                                              var resp = respXML.getElementsByTagName("result");
                                                                                              if(resp) {
                                                                                                  this.idstore.set('value', resp[0].getAttribute('imageid'));
                                                                                                  this.button.set('html', '<img src="' + resp[0].getAttribute('path') + '" />');

                                                                                                  this.popup.close();
                                                                                                  this.loadingBody();
                                                                                              } else {
                                                                                                  $('errboxmsg').set('html', '<p class="error">No result found in response data.</p>');
                                                                                                  errbox.open();
                                                                                              }
                                                                                          }
                                                                                      }.bind(this),
                                                                                      onFailure: function() { alert("Upload failed!"); },
                                                                                      onDragenter: function() { $('ml-droparea').addClass('hover'); },
			                                                                          onDragleave: function() { $('ml-droparea').removeClass('hover'); },
			                                                                          onDrop: function() { $('ml-droparea').removeClass('hover'); },
			                                                                          onRequest: function() { $('ml-droparea').addClass('disabled'); },
			                                                                          onComplete: function() { $('ml-droparea').removeClass('disabled'); }
                                                                                    });

                                                  this.attachClickListeners($$('div.selector-image'));
                                                  this.popup.messageBox.fade('in');
                                              }.bind(this));
                                          }.bind(this)
                                        });
        this.loadReq.post({ 'mode': this.options.mode });
    },

    attachClickListeners: function(elements) {
        elements.each(function(element) {
            element.removeEvents('click');
            element.medialib = this;

            element.addEvent('click', function(event) {
                var id  = this.get('id').substr(4);
                var img = this.getElement('img');
                var medialib = this.medialib;

                medialib.idstore.set('value', id);
                medialib.button.set('html', '<img src="' + img.getAttribute('src') + '" />');
                medialib.popup.close();
                medialib.loadingBody();
            });
        }.bind(this));
    }

});