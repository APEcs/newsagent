
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


window.addEvent('domready', function() {
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
});
