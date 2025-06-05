/* pro_manager.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.proManager = ysy.proManager || {};
ysy.pro = ysy.pro || {};
$.extend(ysy.proManager, {
  proFunctionsMap: {},
  name:"proManager",
  patch: function () {
    window.ysy = window.ysy || {};
    ysy.settings = ysy.settings || {};
    for (var key in ysy.pro) {
      if (!ysy.pro.hasOwnProperty(key)) continue;
      if (ysy.pro[key].patch) {
        ysy.pro[key].patch();
      }
    }
  },
  forEachPro: function (wrapperFunc, event) {
    var proFunctions = this.proFunctionsMap[event];
    if (!proFunctions) return;
    for (var i = 0; i < proFunctions.length; i++) {
      wrapperFunc.call(this, proFunctions[i]);
    }
  },
  fireEvent: function (event) {
    var proFunctions = this.proFunctionsMap[event];
    if (!proFunctions) return;
    var slicedArgs = Array.prototype.slice.call(arguments, 1);
    for (var i = 0; i < proFunctions.length; i++) {
      proFunctions[i].apply(this, slicedArgs);
    }
  },
  register: function (event, func) {
    if (!func) throw "missing call function";
    var eventList = this.proFunctionsMap[event];
    if (!eventList) this.proFunctionsMap[event] = eventList = [];
    for (var i = 0; i < eventList.length; i++) {
      if (eventList[i] === func) {
        return;
      }
    }
    eventList.push(func);
  },
  unregister: function (event, func) {
    var eventList = this.proFunctionsMap[event];
    if (!eventList) return;
    for (var i = 0; i < eventList.length; i++) {
      if (eventList[i] === func) {
        eventList.splice(i, 1);
        return;
      }
    }
  },
  showHelp: function () {
    var div = $(this).next();
    var x = div.clone().attr({"id": div[0].id + "_popup"}).appendTo($("body"));
    showModal(x[0].id);
  },
  closeAll: function (except) {
    this.forEachPro(function (func) {
      if (except.close !== func) func.call(this,except);
    }, "close");
  },
  eventFilterTask: function (id, task) {
    var ret = true;
    this.forEachPro(function (func) {
      if (ret) ret = func(id, task);
    }, "filterTask");
    return ret;
  }
});
