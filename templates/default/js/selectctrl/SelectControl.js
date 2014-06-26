
var SelectControl = new Class(
{
    Implements: [Options, Events],

    options: {
        checkClass: 'input.selctrl-opt',
        newClass: 'new',
        readClass: 'read',
		offset: { x: 0, y: 0 }
    },

    initialize: function(element, options)
    {
        this.setOptions(options);

        this.action = 'open';

        // Grab the element, and extend it if needed
        this.element = document.id(element);
        this.element.store('selectctrl_object', this);

        this._create();
    },


    _create: function()
    {
        // Get the mode icon element
        this.mode = this.element.getFirst('span.selctrl-mode');
        if(!this.mode) return;

        // fetch the ul which should form the menu
        this.menu = this.element.getFirst('ul');
        if(!this.menu) return;

        this.menu.dispose();                   // remove from the dom
        this.menu.addClass('selctrl-menu');    // ensture the menu has the right class
        this.menu.setStyle('display', 'none'); // make sure the menu is hidden

        // Move the menu into position below the control box
        var offset = this.options.offset;
		var position = this.element.getCoordinates();
		this.menu.setStyles({'top': position.top + position.height + offset.y,
			                 'left': position.left + offset.x });

        this.menu.inject(this.element, 'after'); // and put it back in place

        // Enable menu toggle
        this.element.addEvents({ 'click': function() {
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
            element.addEvents({ click: function(event) { this.updateBoxes(event.target.get('data-selctrl-mode'));
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

        // Update the mode display when any checkboxes are ticked
        $$(this.options.checkClass).each(function(element) {
            element.addEvent('change', function() { this.updateMode(); }.bind(this));
        }, this);

        this.updateMode();
    },

    updateMode: function()
    {
        var options = $$(this.options.checkClass);
        var checked = options.filter(function(box) { return box.get('checked'); });

        if(!options.length) {
            this.mode.setStyle('background-position', '0px 0px');
        } else {
            if(!checked.length) {
                this.mode.setStyle('background-position', '0px 0px');
            } else if(checked.length < options.length) {
                this.mode.setStyle('background-position', '-16px 0px');
            } else {
                this.mode.setStyle('background-position', '-32px 0px');
            }
        }
    },

    updateBoxes: function(mode)
    {
        switch(mode) {
            case "all": $$(this.options.checkClass).each(function(element) {
                                                             element.set('checked', true);
                                                         });
                break;
            case "none": $$(this.options.checkClass).each(function(element) {
                                                              element.set('checked', false);
                                                          });
                break;
            case "new": $$(this.options.checkClass).each(function(element) {
                                                              element.set('checked', element.hasClass(this.options.newClass));
                                                         }, this);
                break;
        }

        this.updateMode();
    },

    toggleMenu: function(mode)
    {
        if(mode == "close") {
            this.menu.removeClass("open");
            this.menu.setStyle('display', 'none');

            this.fireEvent('listOpen', this.element);
        } else {
            this.menu.addClass("open");
            this.menu.setStyle('display', 'block');

            this.fireEvent('listClose', this.element);
        }
    }

});
