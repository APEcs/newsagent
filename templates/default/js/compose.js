
/*******************************************************************************
 *  Text use displays
 */

var limitcols = {
     '0': '#009100',
    '75': '#9B5203',
    '90': '#AF0000',
   'out': '#FF0000'
};

function textcount_display(counterid, current, limit)
{
    $(counterid).innerHTML = limit - current;
    var used = (current * 100) / limit;
    var color;
    for(var key in limitcols) {
        if(key != 'out' && used < key) break;
        color = limitcols[key];
    }

    $(counterid).setStyle('color', color);
    $(counterid).setStyle('font-weight', (used > 100 ? "bold" : "normal"));
}


function text_fielduse(fieldid, counterid, limit)
{
    var twitterctrl = $('twitter-mode');
    var twitteron   = $$('input.matrix.Twitter').filter(function(box) { return box.get('checked'); }).length;

    if(twitterctrl && twitteron > 0) {
        var mode = twitterctrl.getSelected().get('value');
        if(mode == 'summary') {
            twitter_fielduse(fieldid, counterid);
            return;
        }
    }

    var curlength = $(fieldid).get("value").length;
    textcount_display(counterid, curlength, limit);
}


/*******************************************************************************
 *  Date fields
 */

var rdate_picker;
var sdate_picker;
var feed_levels;
var sendat_picker = new Array();

function date_control(datefield, tsfield, dateopt, control, picker)
{
    var selVal = $(control).getSelected()[0].get("value");
    var disabled = (selVal != 'timed' && selVal != 'after');

    $(datefield).set("disabled", disabled);

    // clear the contents if the field is disabled
    if(disabled) {
        $(datefield).set('value', '');
        $(tsfield).set('value', '');
        $(dateopt).dissolve();
    } else {
        if(!$(tsfield).get('value')) {
            // Create a default date one day from now
            var defdate = new Date();
            defdate.setTime(defdate.getTime() + 86400000);

            $(tsfield).set('value', defdate.getTime() / 1000);
            picker.select(defdate);
        } else {
            var defdate = new Date($(tsfield).get('value') * 1000);
            picker.select(defdate);
        }
        $(dateopt).reveal();
    }
}


function release_control(datefield, tsfield, dateopt, presetfield, presetopt, control, picker)
{
    date_control(datefield, tsfield, dateopt, control, picker);

    var selVal = $(control).getSelected()[0].get("value");
    var presetdisabled = (selVal != 'preset');

    $(presetfield).set("disabled", presetdisabled);

    if(presetdisabled) {
        $(presetfield).set('value', '');
        $(presetopt).dissolve();
    } else {
        $(presetopt).reveal();
    }
}


function notify_control(container, datefield, tsfield, control)
{
    var selVal = $(control).getSelected().get("value");
    var datedisabled = (selVal != 'timed');

    var id = datefield.substr(11);

    $(datefield).set("disabled", datedisabled);
    if(datedisabled) {
        $(datefield).set('value', '');
        $(tsfield).set('value', '');
        $(container).dissolve();
    } else {
        if(!$(tsfield).get('value')) {
            // Create a default date one day from now
            var defdate = new Date();
            defdate.setTime(defdate.getTime() + 86400000);

            $(tsfield).set('value', defdate.getTime() / 1000);
            sendat_picker[id].select(defdate);
        } else {
            var defdate = new Date($(tsfield).get('value') * 1000);
            sendat_picker[id].select(defdate);
        }

        $(container).reveal();
    }
}


function setup_notify_picker(element)
{
    var id = element.get('id').substr(11);

    sendat_picker[id] = new Picker.Date($('send_atdate'+id), { timePicker: true,
                                                               yearPicker: true,
                                                               positionOffset: {x: 5, y: 0},
                                                               pickerClass: 'datepicker_dashboard',
                                                               useFadeInOut: !Browser.ie,
                                                               onSelect: function(date) {
                                                                   date.setSeconds(0, 0);
                                                                   $('send_at'+id).set('value', date.getTimeAdjusted(utcoffset));
                                                               }
                                                             });
    element.addEvent('change', function() { notify_control('matrix-mode'+id+'-date', 'send_atdate'+id, 'send_at'+id, 'matrix-mode'+id); });
    notify_control('matrix-mode'+id+'-date', 'send_atdate'+id, 'send_at'+id, 'matrix-mode'+id);
}


/*******************************************************************************
 *  Image controls
 */

function show_image_subopt(selid)
{
    var opts = $(selid).options;
    var sel  = $(selid).selectedIndex;
    var opt;

    for(opt = 0; opt < opts.length; ++opt) {
        var elem = $(selid + "_" + opts[opt].value);
        if(elem) {
            if(opt == sel) {
                elem.reveal();
            } else {
                elem.dissolve();
            }
        }
    }
}


/*******************************************************************************
 *  Level controls
 */

function set_visible_levels()
{
    var avail_levels = { };
    var feeds = 0;

    level_list.each(function(level) {
        avail_levels[level] = 0;
    });

    // first find out which levels the user can post to from the selected feeds.
    // The level names are used as counters: if the user can post at the level
    // in a given feed the count for that level is incremeneted.
    $$('input[name=feed]:checked').each(function(element) {
        ++feeds;
        var id = element.get('value');

        level_list.each(function(level) {
            avail_levels[level] += feed_levels[id][level];
        });
    });

    // now go through the levels, enabling or disabling them. The idea is that, for
    // a given level, if the count of feeds the user can post at this level to matches
    // the number of selected feeds, the option is available, otherwise it is not.
    level_list.each(function(level) {
        if(feeds && avail_levels[level] == feeds) {
            $('level-'+level).disabled = 0;
            $('forlevel-'+level).removeClass("disabled");
        } else {
            $('level-'+level).disabled = 1;
            $('level-'+level).set('checked', false); /* force no check when disabled */
            $('forlevel-'+level).addClass("disabled");
        }
    });
}


function cascade_levels(element)
{
    if(!element.get('checked')) return 0;

    var position = level_list.indexOf(element.value);

    for(var i = position + 1; i < level_list.length; ++i) {
        if($('level-'+level_list[i])) {
            $('level-'+level_list[i]).set('checked', true);
        }
    }
}


/*******************************************************************************
 *  Schedule related
 */

function set_schedule_sections()
{
    var sched_drop = $('comp-schedule');

    if(sched_drop) {
        var schedule = sched_drop.getSelected().get("value");

        $('schedule-next1').set('html', schedule_data['id_'+schedule]['next'][0]['time']);
        if(schedule_data['id_'+schedule]['next'][0]['late']) {
            $('schedule-next1').addClass('late');
        } else {
            $('schedule-next1').removeClass('late');
        }

        $('schedule-next2').set('html', schedule_data['id_'+schedule]['next'][1]['time']);

        $('comp-section').empty();

        schedule_data['id_'+schedule]['sections'].each(function (item, index) {
            $('comp-section').adopt(new Element('option', {'html': item.name, 'value': item.value}));
            if(item.selected) $('comp-section').selectedIndex = index;
        });
    }
}

/*******************************************************************************
 *  Confirmation popup related
 */

function confirm_errors(relmode, summary, fulltext, feeds, levels, publish, pubtime, newspub, newstime, pubname)
{
    var errlist = new Element('ul');
    var errelem = new Element('div').adopt(
        new Element('p', { html: confirm_messages['errors'] }),
        errlist
    );

    if(relmode == 0) {
        if(!feeds) {
            errlist.adopt(new Element('li', { html: confirm_messages['nofeeds'] }));
        }

        if(!levels) {
            errlist.adopt(new Element('li', { html: confirm_messages['nolevels'] }));
        }

        if(publish == "timed" && !pubtime.length) {
            errlist.adopt(new Element('li', { html: confirm_messages['noreltime'] }));
        }

        if(publish == 'preset' && !pubname.length) {
            errlist.adopt(new Element('li', { html: confirm_messages['nopreset'] }));
        }
    } else {
        if(newspub == 'after' && !newstime.length) {
            errlist.adopt(new Element('li', { html: confirm_messages['noreltime'] }));
        }
    }

    if(!summary.length && !fulltext.length) {
        errlist.adopt(new Element('li', { html: confirm_messages['notext'] }));
    }



    return errelem;
}


function confirm_levels()
{
    var levellist = new Element('ul');
    var levelelem = new Element('div').adopt(
        new Element('p', { html: confirm_messages['levshow'] }),
        levellist
    );

    $$('input[name=level]:checked').each(
        function(element) {
            levellist.adopt(new Element('li', { html: confirm_messages['levels'][element.get('value')] }));
        }
    );

    return levelelem;
}


function enabled_notify()
{
    var enabled = { };
    var format = /^(\d+)-(\d+)$/;

    $$('input[name=matrix]:checked').each(
        function(element) {
            var value = element.get('value');
            var match = format.exec(value);

            if(match) {
                var titleElem = $$('li#recip-'+match[1]+' > div.recipient')[0];
                if(titleElem) {
                    var method = notify_methods[match[2]];
                    var name   = titleElem.get('title');

                    if(!enabled[method]) enabled[method] = new Array();
                    enabled[method].push({name: name,
                                          id: 'mcount-'+value,
                                          mid: value,
                                          // embedding a toString() here lets confirm_notify() just stringify the objects.
                                          toString: function() { return '<span id="'+this.id+'">'+this.name+'</span>'; }
                                         });
                }
            }
        }
    );

    return enabled;
}


function confirm_preset(isPreset)
{
    var presetelem;

    if(isPreset) {
        presetelem = new Element('p', { html: confirm_messages['ispreset'] });
    }

    return presetelem;
}


function notify_count_api(enabled)
{
    // First get the selected year id
    var yearid = $('matrix-acyear').getSelected()[0].get("value");

    // Build a list of ids to send to the api
    var mlist = new Array();
    Object.each(enabled, function(value, key) {
                    value.each(function(targ) {
                                   mlist.push(targ.mid);
                               });
                });

    var req = new Request({ url: api_request_path("webapi", "rcount", basepath),
                            onSuccess: function(respText, respXML) {
                                $('notifycount-spinner').dissolve();

                                var err = respXML.getElementsByTagName("error")[0];
                                if(err) {
                                    $('errboxmsg').set('html', '<p class="error">'+err.getAttribute('info')+'</p>');
                                    errbox.open();

                                    // No error, we have counts
                                } else {
                                    var recipients = respXML.getElementsByTagName('recipient');
                                    Array.each(recipients, function(element) {
                                                   var count = element.getAttribute('count');
                                                   var name  = element.getAttribute('name');
                                                   if($('mcount-'+element.id) && count >= 0) {
                                                       $('mcount-'+element.id).set('html', name+" ["+count+"]");
                                                   }
                                               });
                                    $('notifycount-msg').reveal();
                                }
                            }
                          });

    req.post({ yearid: yearid,
               matrix: mlist.join(',')});
}


function confirm_notify()
{
    var notifyelem;
    var enabled = enabled_notify();

    if(enabled && Object.keys(enabled).length) {
        notifyelem = new Element('div');

        Object.each(enabled, function(value, key) {
                        notifyelem.adopt(new Element('dl').adopt(
                                             new Element('dt', { html: confirm_messages['notify']+" "+key+":" }),
                                             new Element('dd', { html: value.join(", ") })
                                         )
                                        );
                    });

        // Add a spinner to show work is in progress fetching the counts
        notifyelem.adopt(new Element('div', {
                                         id: 'notifycount-spinner'
                                     }).adopt(new Element('img', { 'width': 16,
                                                                   'height': 16,
                                                                   'src': spinner_imgurl }),
                                              new Element('span', { html: confirm_messages['counting'] })
                                             ));

        // And a message indicating approximation
        notifyelem.adopt(new Element('div', { 'id': 'notifycount-msg',
                                              'styles': { 'display': 'none' },
                                              'html': confirm_messages['countwarn'] }));

        // And set off the count fetch code
        notify_count_api(enabled);
    }

    return notifyelem;
}


function confirm_newsletter()
{
    var newsletter = $('comp-schedule').getSelected()[0].get('html');
    var section    = $('comp-section').getSelected()[0].get('html');

    var confirmelem = new Element('div').adopt(
        new Element('dl').adopt(
            new Element('dt', { html: confirm_messages['newsintro'] }),
            new Element('dd', { html: confirm_messages['newsname']+": "+newsletter }),
            new Element('dd', { html: confirm_messages['newssect']+": "+section })
        )
    );

    return confirmelem;
}


function confirm_timed(relmode, delaytime)
{
    if(relmode == 0) {
        return new Element('p', { html: confirm_messages['relnormal']+" "+delaytime});
    } else {
        return new Element('p', { html: confirm_messages['relnewslet']+" "+delaytime});
    }
}


function check_valid(relmode, summary, fulltext, feeds, levels, publish, pubtime, newspub, newstime, pubname)
{
    // Must always have summary or full text set regardless of mode
    if(!(summary.length || fulltext.length)) {
        return false;
    } else {
        // normal release must have feed and level, and valid publish setting
        if(relmode == 0) {
            if(!feeds || !levels) {
                return false;
            }

            // valid publish setting basic checks - preset must have a name, timed must have a time
            if(publish == "preset" && !pubname.length) {
                return false;
            } else if(publish == "timed" && !pubtime.length) {
                return false;
            }

        // newsletters must have valid publish
        } else if(relmode == 1) {
            if(newspub == "after" && !newstime.length) {
                return false;
            }
        } else {
            return false;
        }
    }

    return true;
}


function confirm_submit()
{
    fixup_files();

    if($('stopconfirm').get('value') == '1') {
        window.onbeforeunload = null;
        $('fullform').submit();
    } else {
        // If no schedule dropdown is available, the user has no schedule access, so force normal mode.
        var relmode  = $('comp-schedule') ? $('relmode').get('value') : 0;
        var summary  = $('comp-summ').get('value');
        var fulltext = CKEDITOR.instances['comp-desc'].getData();
        var feeds    = $$('input[name=feed]:checked').length;
        var levels   = $$('input[name=level]:checked').length;
        var publish  = $('comp-release').getSelected()[0].get("value");
        var pubtime  = $('release_date').get('value');
        var newspub  = $('comp-srelease') ? $('comp-srelease').getSelected()[0].get("value") : '';
        var newstime = $('schedule_date') ? $('schedule_date').get('value') : '';
        var pubname  = $('preset').get('value');

        var buttons  = [ { title: confirm_messages['cancel'] , color: 'blue', event: function() { popbox.close(); popbox.footer.empty(); }} ];

        // The start of the body text is the same regardless of whether there are are any errors.
        var bodytext = new Element('div').adopt(
            // Side image for the confirm dialog
            new Element('img', { src: confirm_imgurl,
                                 styles: {  'width': 48,
                                            'height': 48,
                                            'float': 'right',
                                            'margin': '0em 0em 0.5em 1em'
                                         }
                               }),
            // Introduction message.
            new Element('p', { html: confirm_messages['intro'] }));

        // If at least one level has been specified, and either the summary or full text have been set,
        // the article is almost certainly going to be accepted by the system so show the "this is where
        // the message will appear" stuff and the confirm button.
        if(check_valid(relmode, summary, fulltext, feeds, levels, publish, pubtime, newspub, newstime, pubname)) {
            var bodyelems = new Array();
            if(relmode == 0) {
                if(publish == "draft") {
                    bodyelems.push(new Element('p', { html: confirm_messages['draft']}));
                } else {
                    bodyelems.push(new Element('p', { html: confirm_messages['normal']}),
                                   confirm_preset(publish == 'preset'),
                                   confirm_levels(),
                                   confirm_notify());

                    if(publish == "timed") {
                        bodyelems.push(confirm_timed(relmode, pubtime));
                    }
                }
            } else {
                if(newspub == "nldraft") {
                    bodyelems.push(new Element('p', { html: confirm_messages['draft']}));
                } else {
                    bodyelems.push(new Element('p', { html: confirm_messages['newsletter']}),
                                   confirm_newsletter());

                    if(newspub == "after") {
                        bodyelems.push(confirm_timed(relmode, newstime));
                    }
                }
            }

            bodyelems.push(new Element('hr'));
            bodytext.adopt(bodyelems);

            // Inject a confirmation disable checkbox into the footer, it looks better there than in the body
            popbox.footer.adopt(new Element('label', { 'for': 'conf-suppress-cb',
                                                       'styles': { 'float': 'left' }
                                                     }).adopt(
                                                         new Element('input', { type: 'checkbox',
                                                                                id: 'conf-suppress-cb'
                                                                              }),
                                                         new Element('span', { html: confirm_messages['stop'] })
                                                     ));

            buttons = [ { title: confirm_messages['confirm'], color: 'blue', event: function() { if($('conf-suppress-cb').get('checked')) {
                                                                                                     $('stopconfirm').set('value', 1);
                                                                                                 }
                                                                                                 $('popspinner').fade('in');
                                                                                                 popbox.disableButtons(true);
                                                                                                 window.onbeforeunload = null;
                                                                                                 $('fullform').submit();
                                                                                               }
                        },
                        buttons[0] ];

            // Otherwise, the system will reject the article - produce errors to show to the user, and keep
            // the single 'cancel' button.
        } else {
            bodytext.adopt(confirm_errors(relmode, summary, fulltext, feeds, levels, publish, pubtime, newspub, newstime, pubname));
        }

        $('poptitle').set('text', confirm_messages['title']);
        $('popbody').empty().adopt(bodytext);
        popbox.setButtons(buttons);
        new Element("img", {   'id': 'popspinner',
                               'src': spinner_url,
                               width: 16,
                               height: 16,
                               'class': 'workspin'}).inject(popbox.footer, 'top');
        popbox.open();
    }
}


/*******************************************************************************
 *  Twitter related
 */

function twitter_showinput(control, box)
{
    var mode = $(control).getSelected().get("value");
    if(mode == 'summary') {
        $(box).dissolve();
    } else {
        $(box).reveal();
    }
    text_fielduse('comp-summ', 'sumchars', 240);
}


function twitter_fielduse(textbox, counter)
{
    var text = $(textbox).get('value');
    var len  = twttr.txt.getTweetLength(text);

    var autolink = $('twitter-auto').getSelected().get('value');
    if(autolink != 'none') len += 24; // 23 for https URL, plus space.

    var articleimg = $('imageb_mode').getSelected().get('value');
    if(articleimg == 'file' || articleimg == 'img') len += 24; // Space for the image link + space

    textcount_display(counter, len, 140);
}


/*******************************************************************************
 *  Utility
 */

function fixup_files()
{
    var files = fileupload.serialize();

    $('files').set('value', files.join(","));
}


/*******************************************************************************
 *  Page load setup
 */

window.addEvent('domready', function() {
    Locale.use('en-GB');
    rdate_picker = new Picker.Date($('release_date'), { timePicker: true,
                                                        yearPicker: true,
                                                        positionOffset: {x: 5, y: 0},
                                                        pickerClass: 'datepicker_dashboard',
                                                        useFadeInOut: !Browser.ie,
                                                        onSelect: function(date) {
                                                            date.setSeconds(0, 0);
                                                            $('rtimestamp').set('value', date.getTimeAdjusted(utcoffset));
                                                        }
                                                      });
    if($('comp-release')) {
        $('comp-release').addEvent('change', function() { release_control('release_date', 'rtimestamp', 'comp-reldate', 'preset', 'comp-relpreset', 'comp-release', rdate_picker); });
        release_control('release_date', 'rtimestamp', 'comp-reldate', 'preset', 'comp-relpreset', 'comp-release', rdate_picker);
    }

    $$('select.notifymode').each(function(element) { setup_notify_picker(element) });

    if($('comp-summ')) {
        $('comp-summ').addEvent('keyup', function() { text_fielduse('comp-summ', 'sumchars', 240); });
        text_fielduse('comp-summ', 'sumchars', 240);
    }

    if($('imagea_mode')) {
        $('imagea_mode').addEvent('change', function() { show_image_subopt('imagea_mode'); });
        show_image_subopt('imagea_mode');
        $('imageb_mode').addEvent('change', function() { show_image_subopt('imageb_mode'); });
        show_image_subopt('imageb_mode');
    }

    if($('comp-schedule')) {
        sdate_picker = new Picker.Date($('schedule_date'), { timePicker: true,
                                                             yearPicker: true,
                                                             positionOffset: {x: 5, y: 0},
                                                             pickerClass: 'datepicker_dashboard',
                                                             useFadeInOut: !Browser.ie,
                                                             onSelect: function(date) {
                                                                 date.setSeconds(0, 0);
                                                                 $('stimestamp').set('value', date.getTimeAdjusted(utcoffset));
                                                             }
                                                           });
        $('comp-schedule').addEvent('change', function() { set_schedule_sections(); });
        set_schedule_sections();

        $('comp-srelease').addEvent('change', function() { date_control('schedule_date', 'stimestamp', 'comp-sreldate', 'comp-srelease', sdate_picker); });
        date_control('schedule_date', 'stimestamp', 'comp-sreldate', 'comp-srelease', sdate_picker);
    }

    $$('input[name=level]').addEvent('change', function(event) { cascade_levels(event.target); });

    if($('submitarticle')) {
        $('submitarticle').addEvent('click', function() { check_login(confirm_submit); });
    }
});
