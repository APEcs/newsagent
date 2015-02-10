var MediaLibrary = new Class({

    Implements: [Options],

    options: {
        title: 'Image Library',
        selectTxt: 'Select',
        cancelTxt: 'Cancel',
        loadingTxt: 'Loading, please wait...',
        mode: 'media', /* valid values: icon, media, thumb, large */
        width: '1000px',
        loadCount: 12,
        initialCount: 24
    },

    initialize: function(button, idstore, options) {
        this.button  = $(button);
        this.idstore = $(idstore);
        this.setOptions(options);
        this.streaming = false;

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

    loadingElem: function() {
        return new Element('div', { 'class': 'loading' }).adopt(
            new Element('img', { src: spinner_imgurl,
                                 styles: { 'width': 16,
                                           'height': 16,
                                           'alt': "working" }}),
            new Element('span', { html: this.options.loadingTxt })
        );
    },

    loadingBody: function() {
        this.popup.setContent(this.loadingElem());
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
                                                  this.attachScrollSpy('selector');
                                                  this.attachModeChanger('selector', 'selector-show', 'selector-order');
                                                  this.popup.messageBox.fade('in');
                                              }.bind(this));
                                          }.bind(this)
                                        });
        this.loadReq.post({ 'mode': this.options.mode,
                            'count': this.options.initialCount
                          });
    },

    attachClickListeners: function(elements) {
        // Can't use elements.each() here as the argument may be either
        // an Elements object or a NodeList.
        Array.each(elements, function(element) {
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
    },

    attachScrollSpy: function(element) {
        var self = this;

        self.scrollSpy = new ScrollSpy(element, { onEnter: function() {
            if(!self.streaming) {
                self.streaming = true;

                self.streamReq = new Request.HTML({ url: api_request_path("webapi", "media.stream", basepath),
                                                    method: 'post',
                                                    onRequest: function() {
                                                        self.spinner = new Element("img", {'id': 'streamspinner',
                                                                                          'src': spinner_url,
                                                                                          'style': 'opacity: 0',
                                                                                          width: 16,
                                                                                          height: 16,
                                                                                          'class': 'workspin'});
                                                        $('selector').adopt(self.spinner);
                                                        self.spinner.fade('in');
                                                    }.bind(this),
                                                    onSuccess: function(respTree, respElems, respHTML) {
                                                        self.spinner.destroy();

                                                        if(respTree.length > 0) {
                                                            // shove the new elements into the selector list
                                                            self.attachClickListeners(respTree);
                                                            $('selector').adopt(respTree);

                                                            // And recalculate.
                                                            self.scrollSpy.update();
                                                        }

                                                        self.streaming = false;
                                                    }.bind(this)
                                                  });
                self.streamReq.post({'mode': self.options.mode,
                                     'offset': $('selector').getChildren().length,
                                     'count': self.options.loadCount,
                                     'show': $('selector-show').getSelected()[0].get('value'),
                                     'order': $('selector-order').getSelected()[0].get('value')
                                    });
            }
        }});
    },

    attachModeChanger: function(container, filter, order) {
        container = $(container);
        filter    = $(filter);
        order     = $(order);

        filter.addEvent('change', function() { this.modeChanged(container); }.bind(this));
        order.addEvent('change', function() { this.modeChanged(container); }.bind(this));
    },

    modeChanged: function(container) {

        this.streaming = true;
        this.streamReq = new Request.HTML({ url: api_request_path("webapi", "media.stream", basepath),
                                            method: 'post',
                                            onRequest: function() {
                                                container.fade('out').get('tween').chain(function() {
                                                    container.getChildren().destroy().empty();
                                                    container.adopt(this.loadingElem());
                                                }.bind(this));
                                            }.bind(this),
                                            onSuccess: function(respTree, respElems, respHTML) {
                                                container.fade('out').get('tween').chain(function() {
                                                    container.getChildren().destroy().empty();

                                                    // shove the new elements into the selector list
                                                    this.attachClickListeners(respTree);
                                                    container.adopt(respTree);

                                                    container.fade('in').get('tween').chain(function() {
                                                        // And recalculate.
                                                        this.scrollSpy.update();
                                                        this.streaming = false;
                                                    }.bind(this));
                                                }.bind(this));
                                            }.bind(this)
                                          });
        this.streamReq.post({'mode': this.options.mode,
                             'offset': 0,
                             'count': this.options.initialCount,
                             'show': $('selector-show').getSelected()[0].get('value'),
                             'order': $('selector-order').getSelected()[0].get('value')
                            });
    }

});