
var rdate_picker;
var sdate_picker;
var feed_levels;

function date_control(datefield, tsfield, control) {
    var selVal = $(control).getSelected().get("value");
    var disabled = (selVal != 'timed');

    $(datefield).set("disabled", disabled);

    // clear the contents if the field is disabled
    if(disabled) {
        $(datefield).set('value', '');
        $(tsfield).set('value', '');
    } else if(!$(tsfield).get('value')) {
        // Create a default date one day from now
        var defdate = new Date();
        defdate.setTime(defdate.getTime() + 86400000);

        $(tsfield).set('value', defdate.getTime() / 1000);
        rdate_picker.select(defdate);
    } else {
        var defdate = new Date($(tsfield).get('value') * 1000);
        rdate_picker.select(defdate);
    }
}


function limit_textfield(fieldid, counterid, charlimit) {
    var curlength = $(fieldid).get("value").length;

    if(curlength >= charlimit) {
        $(fieldid).set("value", $(fieldid).get("value").substring(0, charlimit));
        $(counterid).innerHTML = "0";
    } else {
        $(counterid).innerHTML = charlimit - curlength;
    }
}


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


function set_visible_levels()
{
    var feed = $('comp-feed').getSelected().get("value");

    Object.each(feed_levels[feed], function (value, key) {
                     var box = $('level-'+key);
                     if(box) {
                         if(value) {
                             $('level-'+key).disabled = 0;
                             $('forlevel-'+key).removeClass("disabled");
                         } else {
                             $('level-'+key).disabled = 1;
                             $('level-'+key).checked = 0; /* force no check when disabled */
                             $('forlevel-'+key).addClass("disabled");
                         }
                     }
                 });
}


function set_schedule_sections()
{
    var sched_drop = $('comp-schedule');

    if(sched_drop) {
        var schedule = sched_drop.getSelected().get("value");

        $('schedule-next1').set('html', schedule_data['id_'+schedule]['next'][0]);
        $('schedule-next2').set('html', schedule_data['id_'+schedule]['next'][1]);

        $('comp-section').empty();

        schedule_data['id_'+schedule]['sections'].each(function (item, index) {
            $('comp-section').adopt(new Element('option', {'html': item.name, 'value': item.value}));
            if(item.selected) $('comp-section').selectedIndex = index;
        });
    }
}


window.addEvent('domready', function() {
    Locale.use('en-GB');
    rdate_picker = new Picker.Date($('release_date'), { timePicker: true,
                                                        yearPicker: true,
                                                        positionOffset: {x: 5, y: 0},
                                                        pickerClass: 'datepicker_dashboard',
                                                        useFadeInOut: !Browser.ie,
                                                        onSelect: function(date) {
                                                            $('rtimestamp').set('value', date.format('%s'));
                                                        }
                                                      });
    $('comp-release').addEvent('change', function() { date_control('release_date', 'rtimestamp', 'comp-release'); });
    date_control('release_date', 'rtimestamp', 'comp-release');

    $('comp-summ').addEvent('keyup', function() { limit_textfield('comp-summ', 'sumchars', 240); });
    limit_textfield('comp-summ', 'sumchars', 240);

    $('imagea_mode').addEvent('change', function() { show_image_subopt('imagea_mode'); });
    show_image_subopt('imagea_mode');
    $('imageb_mode').addEvent('change', function() { show_image_subopt('imageb_mode'); });
    show_image_subopt('imageb_mode');

    $('comp-feed').addEvent('change', function() { set_visible_levels(); });

    if($('comp-schedule')) {
        sdate_picker = new Picker.Date($('schedule_date'), { timePicker: true,
                                                             yearPicker: true,
                                                             positionOffset: {x: 5, y: 0},
                                                             pickerClass: 'datepicker_dashboard',
                                                             useFadeInOut: !Browser.ie,
                                                             onSelect: function(date) {
                                                                 $('stimestamp').set('value', date.format('%s'));
                                                             }
                                                           });
        $('comp-schedule').addEvent('change', function() { set_schedule_sections(); });
        set_schedule_sections();

        $('comp-srelease').addEvent('change', function() { date_control('schedule_date', 'stimestamp', 'comp-srelease'); });
        date_control('schedule_date', 'stimestamp', 'comp-srelease');
    }
});
