/* view.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};
$.extend(ysy.view, {
  onRepaint: [],
  patch: function () {
    this.applyGanttRewritePatch();
    this.addGanttAddons();
    this.applyGanttPatch();
    if (!window.initEasyAutocomplete) {
      window.initEasyAutocomplete = function () {
      };
    }
    if (ysy.settings.easyRedmine && $("#content").children(".easy-content-page").length === 0) {
      $("#easy_gantt").addClass("easy-content-page");
    }
  },
  start: function () {
    this.labels = ysy.settings.labels;
    var main = new ysy.view.Main();
    main.init(ysy.data.projects);
    this.anim();
  },
  anim: function () {
    var view = ysy.view;
    for (var i = 0; i < view.onRepaint.length; i++) {
      view.onRepaint[i]();
    }
    //requestAnimFrame($.proxy(this.anim, this));
    requestAnimFrame(view.anim);
  },
  getTemplate: function (name) {
    return this.templates[name];
  },
  getLabel: function () {
    var temp = this.labels;
    for (var i = 0; i < arguments.length; i++) {
      var arg = arguments[i];
      if (temp[arg]) {
        temp = temp[arg];
      } else {
        return temp;
      }
    }
    return temp;
  }
});
