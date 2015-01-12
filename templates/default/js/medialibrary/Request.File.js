/*
---
name: Request.File
description: FormData file upload facility. Based around class of the same name by Mootools devs, Arian Stolwijk, and Djamil Legato
license: MIT-style license.

authors:
- Chris Page

requires:
- core/1.5.1: [Request, Options, Events]

provides: [Request.File]

...
 */

/* This is largely based around a modified version of the Mootools Request class
 * via the Request.File class in the 'form_upload' library by Arian Stolwijk.
 *
 * It's important to note the following differences from Request:
 * - `format` option is ignored
 * - `method` is always 'post' and can not be changed
 * - `emulation` is always false
 * - `urlEncoded` is always false
 * - `encoding` is ignored
 * - `noCache` is ignored
 * - HTTP basic auth is not supported
 */
(function(){

var progressSupport = ('onprogress' in new Browser.Request());

Request.File = new Class({

    Extends: Request,

    options: {
        emulation: false,
        urlEncoded: false/*,
        onProgress:,
        onComplete:,
        onRequest:,
        onLoadstart:,
        onCancel:,
        onSuccess:,
        onFailure:,
        onException:,
        onTimeout:
        */
    },

    initialize: function(options){
        this.xhr = new Browser.Request();
        this.formData = new FormData();
        this.setOptions(options);
        this.headers = this.options.headers;
    },

    append: function(key, value){
        this.formData.append(key, value);
        return this.formData;
    },

    reset: function(){
        this.formData = new FormData();
    },

    send: function(options){
        if(!this.check(options)) return this;

        this.options.isSuccess = this.options.isSuccess || this.isSuccess;
        this.running = true;

        var xhr = this.xhr;
        if(progressSupport){
            xhr.onloadstart = this.loadstart.bind(this);
            xhr.onprogress = this.progress.bind(this);
            xhr.upload.onprogress = this.progress.bind(this);
        }

        xhr.open('POST', this.options.url, true);
        xhr.onreadystatechange = this.onStateChange.bind(this);

        Object.each(this.headers, function(value, key){
            try {
                xhr.setRequestHeader(key, value);
            } catch (e){
                this.fireEvent('exception', [key, value]);
            }
        }, this);

        this.fireEvent('request');
        xhr.send(this.formData);

        if(!this.options.async) this.onStateChange();
        if(this.options.timeout) this.timer = this.timeout.delay(this.options.timeout, this);
        return this;
    }

});

})();
