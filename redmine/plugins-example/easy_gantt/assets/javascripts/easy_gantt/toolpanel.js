/* toolpanel.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.toolPanel = ysy.pro.toolPanel || {};
$.extend(ysy.pro.toolPanel, {
  _name: "ToolPanel",
  extendees: [],
  initToolbar: function (ctx) {
    var toolPanel = new ysy.view.ToolPanel();
    toolPanel.init(ysy.settings.toolPanel);
    ctx.children.push(toolPanel);
  },
  patch: function () {
    var toolSetting = ysy.settings.toolPanel = new ysy.data.Data();
    toolSetting.init({
      _name: "ToolPanel", buttonIds: [], buttons: {},
      registerButtonSilent: function (button) {
        if (button.id === undefined) throw("Missing id for button");
        this.buttons[button.id] = button;
        this.buttonIds.push(button.id);
      }
    });

    ysy.proManager.register("initToolbar", this.initToolbar);

    for (var i = 0; i < this.extendees.length; i++) {
      var button = this.extendees[i];
      if (button.isRemoved && button.isRemoved()) continue;
      toolSetting.registerButtonSilent(button);
    }
    toolSetting._fireChanges(this, "delayed registerButton");
    delete this.extendees;
  },
  registerButton: function (button) {
    if (button.isRemoved && button.isRemoved()) return;
    if (ysy.settings.toolPanel) {
      ysy.settings.toolPanel.registerButtonSilent(button);
      ysy.settings.toolPanel._fireChanges(this, "direct registerButton");
    } else {
      this.extendees.push(button);
    }
  }
});

ysy.view.ToolPanel = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.ToolPanel, {
  name: "ToolPanelWidget",
  templateName: "ToolButtons",

  _postInit: function () {
    var $toolPanel = $("#easy_gantt_tool_panel");
    $toolPanel.find("a:not([href])").attr("href", "javascript:void(0)");
    $toolPanel.find("li > *").hide();
  },
  _updateChildren: function () {
    var model = this.model;
    var children = [];
    // this.$target = $("#content");
    for (var i = 0; i < model.buttonIds.length; i++) {
      var elid = model.buttonIds[i];
      var extendee = model.buttons[elid];
      // if (!this.getChildTarget(extendee).length) continue;
      var button;
      if (extendee.widget) {
        button = new extendee.widget();
      } else {
        button = new ysy.view.Button();
      }
      $.extend(button, extendee);
      button.init();
      children.push(button);
    }
    this.children = children;
  },
  _repaintCore: function () {
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      this.setChildTarget(child, i);
      child.repaint(true);
    }
  },
  setChildTarget: function (child /*,i*/) {
    var selector = "#" + child.elementPrefix + child.id;
    var target = this.$target.find(selector);
    if (target.length === 0) throw("element #" + child.elementPrefix + child.id + " missing");
    child.$target = target;
  }
});
