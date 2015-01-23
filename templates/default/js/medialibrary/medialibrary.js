var MediaLibrary = new Class({

    Implements: [Options],

    options: {
        title: 'Image Library',
        selectTxt: 'Select',
        cancelTxt: 'Cancel',
        loadingTxt: 'Loading, please wait...',
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
                                      height: "420px",
                                      buttons: [ { title: this.options.selectTxt,
                                                   color: 'blue',
                                                   event: function() { this.selectImage(); }.bind(this) },
                                                 { title: this.options.cancelTxt,
                                                   color: 'blue',
                                                   event: function() { this.popup.close(); this.load('<div></div>'); }.bind(this) }
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
        this.loadingBody();
        this.popup.open();
    }

});
