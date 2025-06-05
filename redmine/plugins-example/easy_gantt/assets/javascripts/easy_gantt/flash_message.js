window.showFlashMessage = (function (type, message, delay) {
  var $content = $("#content");
  $content.find(".flash").remove();
  var element = document.createElement("div");
  element.className = 'fixed flash ' + type;
  element.style.position = 'fixed';
  element.style.zIndex = '10001';
  element.style.right = '5px';
  element.style.top = '5px';
  element.setAttribute("onclick", "closeFlashMessage($(this))");
  var close = document.createElement("a");
  close.className = 'icon-close close-icon';
  close.setAttribute("href", "javascript:void(0)");
  close.style.float = 'right';
  close.style.marginLeft = '5px';
  // close.setAttribute("onclick", "closeFlashMessage($(this))");
  var span = document.createElement("span");
  span.innerHTML = message;
  element.appendChild(close);
  element.appendChild(span);
  $content.prepend(element);
  var $element = $(element);
  if (delay) {
    setTimeout(function () {
      window.requestAnimationFrame(function () {
        closeFlashMessage($element);
      });
    }, delay);
  }
  return $element;
});

window.closeFlashMessage = (function ($element) {
  $element.closest('.flash').fadeOut(500, function () {
    $element.remove();
  });
});
