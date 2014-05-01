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
        // Note that using ckeditor_data() is safe even for plain input
        // or textarea fields, as it will just return their value
        this.options.fields.each(function(fieldid) {
            $(fieldid).store('initialValue', this.ckeditor_data(fieldid));
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
    },


    /** Fetch the value stored in a text area that may be being replaced
     *  by a ckeditor instance. This is required to allow the initial value
     *  recording to work even if ckeditor hasn't loaded and replaced the
     *  textarea yet.
     */
    ckeditor_data: function(fieldname) {
        var value = $(fieldname).get('value');

        if(CKEDITOR && CKEDITOR.instances[fieldname]) {
            return CKEDITOR.instances[fieldname].getData();
        }

        return value;
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
             if(this.ckeditor_data(fieldid) !== $(fieldid).retrieve('initialValue')) {
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
     }

});


window.addEvent('domready', function() {
    new EditTools({warnmsg: confirm_messages['warnmsg'],
                   fields: [ 'comp-title', 'comp-summ', 'comp-desc' ]});

});