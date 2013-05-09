
var rdate_picker;

function date_control(datefield, tsfield, control) {
    var selVal = $(control).getSelected().get("value");
    var disabled = (selVal != 'timed');

    $(datefield).set("disabled", disabled);

    // clear the contents if the field is disabled
    if(disabled) {
        $(datefield).set('value', '');
        $(tsfield).set('value', '');
    } else {
        var now = new Date();

        var offset = (mode == 'close') ? 7 : 0;
        var targdate = new Date(now.getTime() + (offset * 86400000));

        $(tsfield).set('value', targdate.getTime() / 1000);
        rdate_picker.select(targdate);
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

    $('comp-summ').addEvent('keyup', function() { limit_textfield('comp-summ', 'sumchars', 140); });
    limit_textfield('comp-summ', 'sumchars', 140);

    $('imagea_mode').addEvent('change', function() { show_image_subopt('imagea_mode'); });
    show_image_subopt('imagea_mode');
    $('imageb_mode').addEvent('change', function() { show_image_subopt('imageb_mode'); });
    show_image_subopt('imageb_mode');
});
