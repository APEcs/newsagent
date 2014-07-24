
var MessageControl = new Class(
{
    Implements: [Options, Events],

    options: {
        checkClass: 'input.selctrl-opt',
        selClass: 'msgctrl-selected',
		offset: { x: 0, y: 0 }
    },

    initialize: function(element, options)
    {
        this.setOptions(options);

        this.action = 'open';

        // Grab the element, and extend it if needed
        this.element = document.id(element);
        this.element.store('messagectrl_object', this);

        this._create();
    },


    _create: function()
    {
        this.move = this.element.getFirst('li.msgctrl-move');
        if(this.move) {
            this.menu = this.move.getFirst('ul');
            if(!this.menu) return;

            this.menu.dispose();                   // remove from the dom
            this.menu.addClass('msgctrl-menu');    // ensture the menu has the right class
            this.menu.setStyle('display', 'none'); // make sure the menu is hidden

            // Move the menu into position below the control box
            this.positionMenu();
            this.menu.inject(this.element, 'after'); // and put it back in place

            // Enable menu toggle
            this.move.addEvents({ 'click': function() {
                                      if(this.menu.hasClass("open")) {
                                          this.toggleMenu('close');
                                      } else {
                                          this.toggleMenu('open');
                                      }
                                  }.bind(this),
                                  'mouseenter': function() { this.action = 'open'; }.bind(this),
                                  'mouseleave': function() { this.action = 'close'; }.bind(this),
                                  'keydown': function(event) {
                                      if(event.key == 'space' || event.key == 'down' || event.key == 'up') {
                                          this.action = 'close';
                                      this.toggleMenu('open');
                                      }
                                  }.bind(this)
                                });

            // Set up menu options
            this.menu.getChildren('li').each(function(element) {
                                                 element.addEvents({ click: function(event) { this.fireEvent('moveMsg', [ event.target.get('data-msgctrl-queue'), this.selectedMsgs() ]);
                                                                                              this.toggleMenu('close');
                                                                                            }.bind(this),
                                                                     'mouseenter': function() { this.action = 'open'; }.bind(this),
                                                                     'mouseleave': function() { this.action = 'close'; }.bind(this)
                                                                   });
                                             }, this);

            // clicks elsewhere in the document should close the menu
            document.addEvents({ 'click': function() {
                                     if (this.action == 'close') {
                                         this.toggleMenu('close');
                                     }
                                 }.bind(this),
                                 'keydown': function(event) {
                                     if (event.key == 'esc') {
                                         this.toggleMenu('close');
                                     }
                                     if (this.menu.hasClass('open') && (event.key == 'down' || event.key == 'up')) {
                                         event.stop();
                                     }
                                 }.bind(this)
                               });
        }

        // Update the visibility when any checkboxes are changed
        $$(this.options.checkClass).each(function(element) {
            element.addEvent('change', function(event) {
                                 this.updateSelected(event.target);
                                 this.updateVis();
                             }.bind(this));
        }, this);

        // Fire events when buttons are clicked
        this.mark   = this.element.getFirst('li.msgctrl-mark');
        this.reject = this.element.getFirst('li.msgctrl-reject');
        this.del    = this.element.getFirst('li.msgctrl-delete');

        if(this.mark)   this.mark.addEvent('click', function() { this.fireEvent('markReadMsg', [this.selectedMsgs()]); }.bind(this));
        if(this.reject) this.reject.addEvent('click', function() { this.fireEvent('rejectMsg', [this.selectedMsgs()]); }.bind(this));
        if(this.del)    this.del.addEvent('click', function() { this.fireEvent('deleteMsg', [this.selectedMsgs()]); }.bind(this));

        this.updateVis();
    },

    updateVis: function() {
        var checked = $$(this.options.checkClass).filter(function(box) { return box.get('checked'); });

        if(checked.length && this.element.getStyle('visibility') == 'hidden') {
            this.element.fade('in');
        } else if(!checked.length && this.element.getStyle('visibility') == 'visible') {
            this.element.fade('out');
        }
    },

    updateSelected: function(element) {

        // If called with an element, update just that element
        if(element) {
            var row = element.getParent('tr');

            if(element.get('checked')) {
                row.addClass(this.options.selClass);
            } else {
                row.removeClass(this.options.selClass);
            }

        // Otherwise, UPDATE ALL THE ELEMENTS
        } else {
            $$(this.options.checkClass).each(function(elem) { this.updateSelected(elem); }, this);
        }
    },

    toggleMenu: function(mode)
    {
        if(mode == "close") {
            this.menu.removeClass("open");
            this.menu.setStyle('display', 'none');

            this.fireEvent('listOpen', this.element);
        } else {
            this.positionMenu();
            this.menu.addClass("open");
            this.menu.setStyle('display', 'block');

            this.fireEvent('listClose', this.element);
        }
    },

    positionMenu: function()
    {
        var offset = this.options.offset;
		var position = this.element.getCoordinates();
		this.menu.setStyles({'top': position.top + position.height + offset.y,
			                 'left': position.left + offset.x });
    },

    selectedMsgs: function()
    {
        var checked = $$(this.options.checkClass).filter(function(box) { return box.get('checked'); });
        var vals = new Array();

        checked.each(function(element) { vals.push(element.get('value')); });
        return vals;
    }
});
