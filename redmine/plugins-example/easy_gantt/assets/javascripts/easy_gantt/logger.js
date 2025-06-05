/* logger.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.log = {
  logLevel: 2,
  mainDebug: "",
  debugTypes: [
    // "refresher",
    // "critical",
    // "canvas_bg",
    // "set",
    // "baseline",
    // "baseline_render",
    // "inline",
    // "print",
    // "move_task",
    // "add_task",
    // "add_task_marker",
    // "taskModal",
    // "date_format",
    // "date_helper",
    // "date",
    // "tooltip",
    // "send",
    // "load",
    // "supersend",
    // "scroll",
    // "scrollRender",
    // "grid_resize",
    // "task_drag",
    // "asc",
    // "task_push",
    // "link_render",
    // "outer",
    // "sort",
    // "link_config",
    // "link_drag",
    // "empty_field",
    // "task_drag_milestone",
    // "widget_destroy",
    // "resource",
    // "summer",
    "nothing"
  ],
  log: function (text) {
    if (this.logLevel >= 4) {
      this.print(text);
    }
  },
  message: function (text) {
    if (this.logLevel >= 3) {
      this.print(text);
    }
  },
  debug: function (text, type) {
    if (type) {
      if (this.mainDebug === type) {
        this.print(text, "debug");
        return;
      }
      for (var i = 0; i < this.debugTypes.length; i++) {
        if (this.debugTypes[i] === type) {
          this.print(text, type === this.mainDebug ? "debug" : null);
          return;
        }
      }
    } else {
      this.print(text, "debug");
    }
  },
  warning: function (text) {
    if (this.logLevel >= 2) {
      this.print(text, "warning");
    }
  },
  error: function (text) {
    if (this.logLevel >= 1) {
      this.print(text, "error");
    }
  },
  print: function (text, type) {
    if (type === "error") {
      console.error(text);
    } else if (type === "warning") {
      console.warn(text);
    } else if (type === "debug") {
      console.debug(text);
    } else {
      console.log(text);
    }
  }
};