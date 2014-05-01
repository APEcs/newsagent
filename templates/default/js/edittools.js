/* onbeforeunload edit warning handling. This is based on the technique
 * used in mediawiki - the onbeforeunload handler must be removed as
 * part of the submission process, or the onbeforeunload warning dialog
 * will be shown during submission as well as normal navigation.
 */

var EditTools = new Class({

    Implements: [Options],

    options: {
//        delay: 120000,   // Default autosave delay is 2 minutes
        delay: 20000,   // Default autosave delay is 2 minutes
        savedHook: null,
        warnMsg: null,
        fields: [ ],
        saving: false
    },

    initialize: function(options) {
        this.setOptions(options);

        // Get the original values of the important elements
        // Note that using get_ckeditor_data() is safe even for plain input
        // or textarea fields, as it will just return their value
        this.options.fields.each(function(fieldid) {
            $(fieldid).store('initialValue', this.get_ckeditor_data(fieldid));
        }.bind(this));

        // addEvent doesn't work for this as mootools bizarrely does not
        // support returning values from event handlers.
        window.onbeforeunload = this.warn_unload.bind(this);

        // Make sure the handler is set when the page is show if needed.
        window.addEvent('pageshow', function() {
            if(!window.onbeforeunload) {
                window.onbeforeunload = this.options.savedHook;
            }
        }.bind(this));

        this.init_autosave();
    },


    /** Fetch the value stored in a text area that may be being replaced
     *  by a ckeditor instance. This is required to allow the initial value
     *  recording to work even if ckeditor hasn't loaded and replaced the
     *  textarea yet. This will work for normal input elements as well.
     */
    get_ckeditor_data: function(fieldname) {
        var value = $(fieldname).get('value');

        if(CKEDITOR && CKEDITOR.instances[fieldname]) {
            return CKEDITOR.instances[fieldname].getData();
        }

        return value;
    },

    /** Set the contents of a ckeditor instance with the specified field
     *  name. If no ckeditor instance is attached to the field, this sets
     *  the field value instead.
     */
    set_ckeditor_data: function(fieldname, value) {

        if(CKEDITOR && CKEDITOR.instances[fieldname]) {
            return CKEDITOR.instances[fieldname].setData(value);
        } else {
            $(fieldname).set('value', value);
        }

    },

    /** Handle the beforeunload event. This will return a warning message
     *  to show in the dialog if the user should be prompted to confirm
     *  unload, and undef if no edits have been made.
     *
     * @return A warning message to show in the beforeunload dialog, or
     *         undef if a warning message is not needed.
     */
     warn_unload: function() {
         var warnmsg;

         this.options.fields.each(function(fieldid) {
             if(this.get_ckeditor_data(fieldid) !== $(fieldid).retrieve('initialValue')) {
                 warnmsg = confirm_messages['editwarn'];
             }
         }.bind(this));

         this.options.savedHook = window.onbeforeunload;
         window.onbeforeunload = null;
         if(warnmsg !== undefined) {
             setTimeout(function() { window.onbeforeunload = this.options.savedHook; }.bind(this), 1);
             return warnmsg;
         }

         return null;
     },

     /** Initialise the autosave stuff. If the edit boxes are empty, attempt to restore
      *  any previously set autosave. If the edit boxes contain stuff, simply check
      *  whether any autosave is available.
      */
     init_autosave: function() {
         var allEmpty = true;

         this.options.fields.each(function(fieldid) {
             if(this.get_ckeditor_data(fieldid) !== '') {
                 allEmpty = false;
             }
         }.bind(this));

         if(allEmpty) {
             this.load_autosave();
         } else {
             this.autosave_store_fields();
             this.check_autosave();
         }

         // turn on the load and save buttons
         $('autoload').addEvent('click', function() {
             this.load_autosave();
         }.bind(this));

         $('autosave').addEvent('click', function() {
             this.save_autosave(true);
         }.bind(this));

         // and start the initial save timer
         this.timeout_id = window.setTimeout(function() { this.save_autosave(); }.bind(this), this.options.delay);
     },


     /** Record the current state of the input boxes so that the autosave routine can tell
      *  if they have changed since the last save.
      */
     autosave_store_fields: function() {

        this.options.fields.each(function(fieldid) {
            $(fieldid).store('lastSaved', this.get_ckeditor_data(fieldid));
        }.bind(this));

     },

     /** Determine whether the user has an autosave set, and if so when it was made.
      *
      */
     load_autosave: function() {
         // nuke any running timeout if there is one to prevent it saving before the load
         if(typeof this.timeout_id == "number") {
             window.clearTimeout(this.timeout_id);
             delete this.timeout_id;
         }

         var req = new Request({ url: api_request_path("webapi", "auto.load", basepath),
                                 onRequest: function() {
                                     $('autostate').fade('in');
                                     $('autostatus').set('html', confirm_messages['restoring']);
                                 },
                                 onSuccess: function(respText, respXML) {
                                     $('autostate').fade('out');

                                     var err = respXML.getElementsByTagName("error")[0];
                                     if(err) {
                                         $('autostatus').set('html', err.getAttribute('info'));
                                     } else {
                                         var response = respXML.getElementsByTagName("result")[0];

                                         // Is any autosave data available?
                                         if(response.getAttribute('autosave') == "available") {
                                             this.options.fields.each(function(fieldid) {
                                                 var fielddata = respXML.getElementById(fieldid);
                                                 if(fielddata) {
                                                     this.set_ckeditor_data(fieldid, fielddata.textContent);
                                                 }
                                             }.bind(this));

                                             $('autoloadopt').fade('in');
                                         }

                                         $('autostatus').set('html', response.getAttribute('desc'));

                                         // Record the new state of the boxes
                                         this.autosave_store_fields();

                                         // restart the timer
                                         this.timeout_id = window.setTimeout(function() { this.save_autosave(); }.bind(this), this.options.delay);
                                     }
                                 }.bind(this)
                               });
         req.post();
     },

     /** Determine whether the user has an autosave, and update the UI but do
      *  not restore any content.
      */
     check_autosave: function() {
         var req = new Request({ url: api_request_path("webapi", "auto.check", basepath),
                                 onRequest: function() {
                                     $('autostate').fade('in');
                                     $('autostatus').set('html', confirm_messages['restoring']);
                                 },
                                 onSuccess: function(respText, respXML) {
                                     $('autostate').fade('out');

                                     var err = respXML.getElementsByTagName("error")[0];
                                     if(err) {
                                         $('autostatus').set('html', err.getAttribute('info'));
                                     } else {
                                         var response = respXML.getElementsByTagName("result")[0];

                                         if(response.getAttribute('autosave') == "available") {
                                             $('autoloadopt').fade('in');
                                         }

                                         $('autostatus').set('html', response.getAttribute('desc'));
                                     }
                                 }
                               });
         req.post();
     },


     save_autosave: function(force) {
         // nuke any running timeout if there is one
         if(typeof this.timeout_id == "number") {
             window.clearTimeout(this.timeout_id);
             delete this.timeout_id;
         }

         // ignore repeated save attempts
         if(this.options.saving) {
             return false;
         }
         this.options.saving = true;

         // Have any of the field changed, or is a save being forced?
         var changed = force;
         if(!changed) {
             this.options.fields.each(function(fieldid) {
                 if(this.get_ckeditor_data(fieldid) !== $(fieldid).retrieve('lastSaved')) {
                     changed = true;
                 }
             }.bind(this));
         }

         // If nothing is being changed, let others back in and restore the timer
         if(!changed) {
             this.options.saving = false;

             // restart the timer
             this.timeout_id = window.setTimeout(function() { this.save_autosave(); }.bind(this), this.options.delay);

             return false;
         }

         var req = new Request({ url: api_request_path("webapi", "auto.save", basepath),
                                 onRequest: function() {
                                     $('autostate').fade('in');
                                     $('autoloadopt').fade('out');
                                     $('autostatus').set('html', confirm_messages['saving']);
                                 },
                                 onSuccess: function(respText, respXML) {
                                     $('autostate').fade('out');

                                     var err = respXML.getElementsByTagName("error")[0];
                                     if(err) {
                                         $('autostatus').set('html', err.getAttribute('info'));
                                     } else {
                                         var response = respXML.getElementsByTagName("result")[0];

                                         if(response.getAttribute('autosave') == "available") {
                                             $('autoloadopt').fade('in');
                                         }

                                         $('autostatus').set('html', response.getAttribute('desc'));
                                     }
                                     this.options.saving = false;

                                     // Record the new state of the boxes
                                     this.autosave_store_fields();

                                     // restart the timer
                                     this.timeout_id = window.setTimeout(function() { this.save_autosave(); }.bind(this), this.options.delay);
                                 }.bind(this)
                               });

         var data = {};
         this.options.fields.each(function(fieldid) {
             data[fieldid] = this.get_ckeditor_data(fieldid);
         }.bind(this));

         req.post(data);
     }
});


window.addEvent('domready', function() {
    new EditTools({warnmsg: confirm_messages['warnmsg'],
                   fields: [ 'comp-title', 'comp-summ', 'comp-desc' ]});

});