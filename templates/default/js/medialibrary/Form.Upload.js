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

// Enable listeners for drag events
Object.append(Element.NativeEvents, {
	dragenter: 2, dragleave: 2, dragover: 2, dragend: 2, drop: 2
});

if (!this.Form) this.Form = {};
var Form = this.Form;

Form.Uploader = new Class({

    Implements: [Options, Events],

    options: {
        url: "",
        param: 'upload'/*,
        onSuccess:,
        onFailure:,
        */
    },

    initialize: function(dropArea, progress, options) {
        this.hasFormData = ('FormData' in window);
        this.progress = $(progress);
        this.dropArea = $(dropArea);

        this.setOptions(options);

        this.request = new Request.File({ url: this.options.url,
                                          onRequest: function() { this.progress.setStyles({ display: 'block', width: 0}); },
                                          onProgress: function(event){
                                              var loaded = event.loaded, total = event.total;
                                              this.progress.setStyle('width', parseInt(loaded / total * 100, 10).limit(0, 100) + '%');
                                          },
                                          onComplete: function(){
                                              this.progress.setStyle('width', '100%');
                                              this.reset();
                                          },
                                          onSuccess: function(responseText, responseXML) {
                                              this.fireEvent('success', responseText, responseXML);
                                          },
                                          onFailure: function(xhr) {
                                              this.fireEvent('failure', xhr);
                                          }
                                        });

        this.dropArea.addEvent("dragenter", function() { this.fireEvent('dragenter'); }.bind(this));
        this.dropArea.addEvent("dragleave", function() { this.fireEvent('dragleave'); }.bind(this));
        this.dropArea.addEvent("dragend",   function() { this.fireEvent('dragend'); }.bind(this));
        this.dropArea.addEvent("dragover",  function(event) {
                                   event.preventDefault();
                                   this.fireEvent('dragover', event);
                               }.bind(this));
        this.dropArea.addEvent("drop", function(event) {
                                   event.preventDefault();
                                   var dataTransfer = event.event.dataTransfer;
                                   if (dataTransfer) this.send(dataTransfer.files[0]);
                                   this.fireEvent('drop', event);
                               }.bind(this));
    },

    send: function(file) {
        this.request.reset();
        this.request.append(this.options.param, file);
        this.request.send();
    }
});

// Invoke with this set to window.
}).call(window);