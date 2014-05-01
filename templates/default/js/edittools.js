/* onbeforeunload edit warning handling. This is based on the technique
 * used in mediawiki - the onbeforeunload handler must be removed as
 * part of the submission process, or the onbeforeunload warning dialog
 * will be shown during submission as well as normal navigation.
 */

var EditTools = new Class({

    Implements: [Options],

    options: {
        savedHook: null,
        warnMsg: null,
        fields: [ ],
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
     *  textarea yet.
     */
    get_ckeditor_data: function(fieldname) {
        var value = $(fieldname).get('value');

        if(CKEDITOR && CKEDITOR.instances[fieldname]) {
            return CKEDITOR.instances[fieldname].getData();
        }

        return value;
    },

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
             this.check_autosave();
         }
     },


     /** Determine whether the user has an autosave set, and if so when it was made.
      *
      */
     load_autosave: function() {

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
                                         }

                                         $('autostatus').set('html', response.getAttribute('desc'));
                                     }
                                 }.bind(this)
                               });
         req.post();
     }
});

/*          var data = {};
         this.options.fields.each(function(fieldid) {
             data[fieldid] = this.get_ckeditor_data(fieldid)
         }.bind(this));

*/

window.addEvent('domready', function() {
    new EditTools({warnmsg: confirm_messages['warnmsg'],
                   fields: [ 'comp-title', 'comp-summ', 'comp-desc' ]});

});