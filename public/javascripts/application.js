// application.js

$(function() { //jQuery shortcut syntax for code to have a document on-ready call.

  $("form.delete").submit(function(event) {
    event.preventDefault(); // Prevents default behavior of submit button in form.
    event.stopPropagation();

    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      // this.submit(); // "this" represents the dom element is that fired the event, the form.
      
      var form = $(this);

      var request = $.ajax({
        url: form.attr("action"),
        method: form.attr("method")
      });

      request.done(function(data, textStatus, jqXHR) {
        if (jqXHR.status === 204) {
          form.parent("li").remove();
        } else if (jqXHR.status === 200) {
          document.location = data;
        }
      });
    }
  });

});