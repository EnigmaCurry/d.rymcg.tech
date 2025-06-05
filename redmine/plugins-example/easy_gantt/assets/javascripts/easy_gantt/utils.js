/* utils.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.main = ysy.main || {};
$.extend(ysy.main, {
  extender: function (parent, child, proto) {
    function ProtoCreator() {
    }
    ProtoCreator.prototype = parent.prototype;
    child.prototype = new ProtoCreator();
    child.prototype.constructor = child;
    $.extend(child.prototype, proto);
  },
  getModal: function (id, width) {
    var $target = $("#" + id);
    if ($target.length === 0) {
      $target = $("<div id=" + id + ">");
      $target.dialog({
        width: width,
        appendTo: document.body,
        modal: true,
        resizable: false,
        dialogClass: 'modal'
      });
      $target.dialog("close");
    }
    return $target;
  },
  startsWith: function (text, char) {
    if (text.startsWith) {
      return text.startsWith(char);
    }
    return text.toString().charAt(0) === char;
  },
  isSameMoment: function (date1, date2) {
    if (!moment.isMoment(date1)) return false;
    if (!moment.isMoment(date2)) return false;
    return date1.isSame(date2);
  },
  /**
   * Utility function for measuring performance of some code
   * @example
   * var perf = createPerformanceMeter("myFunction");
   * perf("part 1");
   * perf("part 2");
   * perf.whole();
   * @param {String} groupName
   * @return {Function}
   */
  createPerformanceMeter: function (groupName) {
    var lastTime = window.performance.now();
    var silence = false;
    var initTime = lastTime;
    var func = function (/** @param {String} name*/ name) {
      if (silence) return;
      var nowTime = window.performance.now();
      var nameString = groupName + " " + name + ":                                  ";
      nameString = nameString.substr(0, 30);
      var diffString = "        " + (nowTime - lastTime).toFixed(3);
      diffString = diffString.substr(diffString.length - 10);
      console.debug(nameString + diffString + " ms");
      lastTime = nowTime;
    };
    func.whole = function () {
      if (silence) return;
      var nowTime = window.performance.now();
      var nameString = groupName + ":                                  ";
      nameString = nameString.substr(0, 30);
      var diffString = "        " + (nowTime - initTime).toFixed(3);
      diffString = diffString.substr(diffString.length - 10);
      console.debug(nameString + diffString + " ms");
    };
    func.silence = function (verbose) {
      silence = !verbose;
    };
    return func;
  },
  /**
   *
   * @param {Array.<{name:String,value:String}>} formData
   * @return {Object}
   */
  formToJson: function (formData) {
    var result = {};
    var prolong = function (result, split, value) {
      var key = split.shift();
      if (key === "") {
        result.push(value);
      } else {
        if (split.length > 0) {
          var next = split[0];
          if (!result[key]) {
            if (next === "") {
              result[key] = [];
            } else {
              result[key] = {};
            }
          }
          prolong(result[key], split, value);
        } else {
          result[key] = value;
        }
      }
    };
    for (var i = 0; i < formData.length; i++) {
      var split = formData[i].name.split(/]\[|\[|]/);
      if (split.length > 1) {
        split.pop();
      }
      prolong(result, split, formData[i].value);
    }
    return result;
  },
  escapeText: function (text) {
    var tmp = document.createElement('div');
    tmp.appendChild(document.createTextNode(text));
    return tmp.innerHTML;
  }
});