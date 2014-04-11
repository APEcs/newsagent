/* Fix javascript dates so that they can be used by a server in a
 * different timezone than the client.
 *
 * So, the problem:
 *
 * - The server expects all datestamps to be UTC, to avoid madness and spiders in the code.
 * - Javascript Date objects always operate in the user's local time anddo their own
 *   translation to UTC.
 * - User expectation is that dates and times set via the UI will be in server local time,
 *   but the local Javascript code assumes they mean local time.
 *
 * Assume a user selects a date and time via some method and that gets placed into a Date
 * object. The UTC timestamp is pulled out, but the value is the UTC for the time selected
 * in the user's local time, rather than server local time. If the user local time and server
 * local time are the same, it works. But if they differ, the server will be sent the
 * 'wrong' time from the user's point of view.
 *
 * This adds a function to the standard Date object that allows the time selected by the user
 * to be converted to the UTC timstamp of the selected time and day in the server local time.
 */

/** Return the number of seconds since January 1, 1970, adjusting the date and time
 *  so that they are in a different timezone than the user's local time.
 *
 * @param utcoffset The offset from UTC of the target timezone.
 *
 * @note This returns **seconds**, not milliseconds as getTime() does.
 */
Date.prototype.getTimeAdjusted = function(utcoffset) {
    return ((this.getTime()/1000) - (this.getTimezoneOffset() * 60) - utcoffset);
};
