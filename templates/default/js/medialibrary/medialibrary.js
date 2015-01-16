var mlwindow;

var MediaLibrary = new Class({

    Implements: [Options],

    options: {
        title: 'Image Library',
        width: '1000px'
    },

    initialize: function(button, idstore, popup, options) {
        this.button  = $(button);
        this.idstore = $(idstore);
        this.popup   = popup;

        this.setOptions(options);

        this.button.addEvent('click', function(event) { event.preventDefault();
                                                        this.open();
                                                      }.bind(this));
    },

    open: function() {
        this.popup.open();
    }

});


window.addEvent('domready', function() {
     mlwindow = new LightFace({title: "Image Library",
                               draggable: false,
                               overlayAll: true,
                               content: '<div id="ml-body"></div>',
                               zIndex: 8001,
                               pad: 200,
                               width: "1000px"});
     if($('imagea_mediabtn')) new MediaLibrary('imagea_mediabtn', 'imagea_imgid');
     if($('imageb_mediabtn')) new MediaLibrary('imageb_mediabtn', 'imageb_imgid');

});