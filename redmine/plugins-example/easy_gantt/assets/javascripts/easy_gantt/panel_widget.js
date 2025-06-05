/* panel_widget.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};

ysy.view.Toolbars = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.Toolbars, {
  name: "ToolbarsWidget",
  template: "",
  childTargets: {
    "SuperPanelWidget": "#supertop_panel",
    "BottomPanelWidget": "#gantt_footer_buttons",
    "BaselinePanelWidget": "#baseline_panel",
    "CriticalPanelWidget": "#critical_panel",
    "AddTaskPanelWidget": "#add_task_panel",
    "LegendWidget": "#easy_gantt_footer_legend",
    "ToolPanelWidget": "#easy_gantt_tool_panel",
    "CollapsorsWidget": "#gantt_cont",
    "AffixWidget": "#easy_gantt_menu"
  },
  _updateChildren: function () {
    if (this.children.length > 0) {
      return;
    }
    if (ysy.view.SuperPanel) {
      var superpanel = new ysy.view.SuperPanel();
      superpanel.init(ysy.settings.sample);
      this.children.push(superpanel);
    }

    var toppanel = new ysy.view.AllButtons();
    toppanel.init();
    this.children.push(toppanel);

    ysy.proManager.fireEvent("initToolbar", this);

    var legend = new ysy.view.Legend();
    legend.init(null);
    this.children.push(legend);

    var collapsors = new ysy.view.Collapsors();
    collapsors.init(null);
    ysy.view.collapsors = collapsors;
    this.children.push(collapsors);

    if (window.affix || !ysy.settings.easyRedmine) {
      var affix = new ysy.view.Affix();
      ysy.view.affix = affix;
      affix.init();
      this.children.push(affix);
    } else {
      ysy.view.affix = {
        requestRepaint: function () {
        }
      };
    }

  },
  _repaintCore: function () {
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      this.setChildTarget(child, i);
      child.repaint(true);
    }
  },
  setChildTarget: function (child/*, i*/) {
    if (this.childTargets[child.name]) {
      child.$target = this.$target.find(this.childTargets[child.name]);
    }
  }
});
//#############################################################################################
ysy.view.AllButtons = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.AllButtons, {
  name: "AllButtonsWidget",
  templateName: "AllButtons",
  extendees: {
    test: {
      func: function () {
        ysy.test.run();
      }, on: true,
      hid: true
    },
    back: {
      bind: function () {
        this.model = ysy.history;
      },
      func: function () {
        ysy.history.revert();
      },
      isDisabled: function () {
        return ysy.history.isEmpty();
      }

    },
    save: {
      bind: function () {
        this.model = ysy.history;
        this.sample = ysy.settings.sample;
        this._register(this.sample);
      },
      func: function () {
        if (ysy.settings.sample.active) {
          ysy.data.loader.load();
          return;
        }
        var $content =$(".easy-content-page");
        var height = $content.height();
        $content.css({"height": height});
        if (this.timeoutSubscription){
          window.clearTimeout(this.timeoutSubscription);
        }
        this.timeoutSubscription = window.setTimeout(function(){
          $content.css({"height": ""});
        },5000);
        ysy.data.save();
      },
      specialRepaint: function () {
        var button_labels = ysy.view.getLabel("buttons");
        if (ysy.settings.sample.active) {
          var label = button_labels.button_reload;
        } else {
          label = button_labels.button_save;
        }
        this.$target.children("icon-label").html(label);
      },
      //isHidden:function(){return ysy.settings.sample.active;},
      isDisabled: function () {
        return this.model.isEmpty()
      },
      timeoutSubscription: 0
    },
    day_zoom: {
      value: "day",
      bind: function () {
        this.model = ysy.settings.zoom;
      },
      func: function () {
        if (ysy.settings.zoom.setSilent("zoom", this.value)) ysy.settings.zoom._fireChanges(this, this.value);
      },
      isOn: function () {
        return ysy.settings.zoom.zoom === this.value;
      }
    },
    week_zoom: {
      value: "week",
      bind: function () {
        this.model = ysy.settings.zoom;
      },
      func: function () {
        if (ysy.settings.zoom.setSilent("zoom", this.value)) ysy.settings.zoom._fireChanges(this, this.value);
      },
      isOn: function () {
        return ysy.settings.zoom.zoom === this.value;
      }
    },
    month_zoom: {
      value: "month",
      bind: function () {
        this.model = ysy.settings.zoom;
      },
      func: function () {
        if (ysy.settings.zoom.setSilent("zoom", this.value)) ysy.settings.zoom._fireChanges(this, this.value);
      },
      isOn: function () {
        return ysy.settings.zoom.zoom === this.value;
      }
    },
    quarter_zoom: {
      value: "quarter",
      bind: function () {
        this.model = ysy.settings.zoom;
      },
      func: function () {
        if (ysy.settings.zoom.setSilent("zoom", this.value)) ysy.settings.zoom._fireChanges(this, this.value);
      },
      isOn: function () {
        return ysy.settings.zoom.zoom === this.value;
      }
    },
    year_zoom: {
      value: "year",
      bind: function () {
        this.model = ysy.settings.zoom;
      },
      func: function () {
        if (ysy.settings.zoom.setSilent("zoom", this.value)) ysy.settings.zoom._fireChanges(this, this.value);
      },
      isOn: function () {
        return ysy.settings.zoom.zoom === this.value;
      }
    },

    task_control: {
      bind: function () {
        this.model = ysy.settings.controls;
      },
      func: function () {
        ysy.settings.controls.setSilent("controls", !this.isOn());
        ysy.settings.controls._fireChanges(this, !this.isOn());
        //this.on=!$(".gantt_bars_area").toggleClass("no_task_controls").hasClass("no_task_controls");
        $(".gantt_bars_area").toggleClass("no_task_controls");
        this.requestRepaint();
      },
      isOn: function () {
        return ysy.settings.controls.controls;
      },
      isHidden: function () {
        // return !ysy.settings.permissions.allowed("edit_easy_gantt", "edit_issues");
        return false;
      }
    },
    resource_help: {},
    add_task_help: {},
    baseline_help: {},
    critical_help: {},
    print: {
      func: function () {
        return ysy.pro.print.directPrint(this);
      },
      isOn: function () {
        return ysy.pro.print.printPreparing;
      },
      forceRepaint:function () {
        this.requestRepaint();
        this.repaint();
      }
    },
    jump_today: {
      func: function () {
        gantt.showDate(moment());
      }
    }
  },
  _updateChildren: function () {
    var children = [];
    this.$target = $("#content");
    //var spans=this.$target.children("span");
    for (var elid in this.extendees) {
      if (!this.extendees.hasOwnProperty(elid)) continue;
      var extendee = this.extendees[elid];
      var button;
      if (extendee.widget) {
        button = new extendee.widget();
      } else {
        button = new ysy.view.Button();
      }
      $.extend(button, extendee, {elid: elid});
      if (!this.getChildTarget(button, elid).length) continue;
      button.init();
      children.push(button);
    }
    this.children = children;
  },
  out: function () {
    //return {buttons:this.child_array};
  },
  _repaintCore: function () {
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      this.setChildTarget(child, i);
      child.repaint(true);
    }
  },
  setChildTarget: function (child /*,i*/) {
    child.$target = this.getChildTarget(child);
  },
  getChildTarget: function (child, elid) {
    if (!elid) elid = child.elid;
    return this.$target.find("#" + child.elementPrefix + elid);
  }
});
//##############################################################################
ysy.view.Button = function () {
  ysy.view.Widget.call(this);
  this.on = false;
  this.disabled = false;
  this.func = function () {
    var div = $(this.$target).next('div');
    var x = div.clone().attr({"id": div[0].id + "_popup"}).appendTo($("body"));
    showModal(x[0].id);
    //var template=ysy.view.getTemplate("easy_unimplemented");
    //var rendered=Mustache.render(template, {modal: ysy.view.getLabel("soon_"+this.elid)});
    //$("#ajax-modal").html(rendered); // REPAINT
    //window.showModal("ajax-modal");
  }
};
ysy.main.extender(ysy.view.Widget, ysy.view.Button, {
  name: "ButtonWidget",
  templateName: "Button",
  elementPrefix: "button_",
  _replace: true,
  init: function () {
    this.name = (this.elid || this.id) + this.name;
    this.name = this.name.charAt(0).toUpperCase() + this.name.slice(1);
    if (this.bind) {
      this.bind();
    }
    if (this.model) {
      this._register(this.model);
    }
    //this.tideFunctionality();
    return this;
  },
  tideFunctionality: function () {
    if (this.func && !this.isDisabled() && (!this.$target.is("a") || this.$target.attr("href") === "javascript:void(0)")) {
      this.$target.off("click").on("click", $.proxy(this.func, this));
    }
  },
  isHidden: function () {
    return this.hid;
  },
  _repaintCore: function () {
    var target = this.$target;
    var hidden = this.isHidden();
    target.toggle(!hidden);
    if (hidden) {
      if (this.specialRepaint) {
        this.specialRepaint(hidden);
      }
      return;
    }
    if (this.isDisabled()) {
      target.addClass("disabled");
      target.removeClass("active");
    } else {
      target.removeClass("disabled");
      if (this.isOn()) {
        target.addClass("active");
      } else {
        target.removeClass("active");
      }
    }
    if (this.specialRepaint) {
      this.specialRepaint();
    }
    this.tideFunctionality();
  },
  isOn: function () {
    return this.on;
  },
  isDisabled: function () {
    return this.disabled;
  }
});
//##############################################################################
ysy.view.Select = function () {
  ysy.view.Button.call(this);
};
ysy.main.extender(ysy.view.Button, ysy.view.Select, {
  name: "SelectWidget",
  templateName: "Select",
  elementPrefix: "select_",
  _repaintCore: function () {
    var target = this.$target;
    var hidden = this.isHidden();
    target.toggle(!hidden);
    if (hidden) {
      if (this.specialRepaint) {
        this.specialRepaint(hidden);
      }
      return;
    }
    target.prop('disabled', this.isDisabled());
    target.val(this.modelValue());
    if (this.specialRepaint) {
      this.specialRepaint();
    }
    this.tideFunctionality();
  },
  tideFunctionality: function () {
    if (this.func && !this.isDisabled()) {
      this.$target.off("change").on("change", $.proxy(this.func, this));
    }
  },
  modelValue: function () {
    return "";
  }
});
//##############################################################################
ysy.view.CheckBox = function () {
  ysy.view.Button.call(this);
};
ysy.main.extender(ysy.view.Button, ysy.view.CheckBox, {
  name: "CheckBoxWidget",
  elementPrefix: "checkbox_",
  _repaintCore: function () {
    var target = this.$target;
    var hidden = this.isHidden();
    target.toggle(!hidden);
    if (hidden) {
      if (this.specialRepaint) {
        this.specialRepaint(hidden);
      }
      return;
    }
    target.prop('disabled', this.isDisabled());
    target.prop('checked', this.isOn());
    if (this.specialRepaint) {
      this.specialRepaint();
    }
    this.tideFunctionality();
  },
  tideFunctionality: function () {
    if (this.func && !this.isDisabled()) {
      this.$target.off("change").on("change", $.proxy(this.func, this));
    }
  }
});
//####################################################
ysy.view.Legend = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.Legend, {
  name: "LegendWidget",
  templateName: "legend",
  _postInit: function () {
  },
  out: function () {
    return null;
    //return {text: "Legend for EasyGantt"};
  }
});
//###################################################
ysy.view.Affix = function () {
  ysy.view.Widget.call(this);
  this.offset = 0;
};
ysy.main.extender(ysy.view.Widget, ysy.view.Affix, {
  name: "AffixWidget",
  init: function () {
    this.$document = $(document);
    this.$superPanel = $("#supertop_panel");
    this.$cont = $("#gantt_cont");
    this.$document.on("scroll", $.proxy(this.requestRepaint, this));
    $(window).on("resize", $.proxy(this.requestRepaint, this));
    if (ysy.settings.easyRedmine) {
      this.offset += $("#top-menu").outerHeight();
    }
    this.bottomFixed = false;
    //this._updateChildren();
  },
  _repaintCore: function () {
    var top = this.$document.scrollTop() + this.offset - this.$superPanel.offset().top - this.$superPanel.outerHeight();
    top = Math.max(Math.floor(top), 0);
    this.setPosition(top);
    var box = this.$cont[0].getBoundingClientRect();

    if (box.bottom > window.innerHeight) {
      if (!this.bottomFixed) {
        // this.$cont.find(".gantt_hor_scroll").css({position: "fixed", top: (window.innerHeight - 15) + "px"});
        this.$cont.find(".gantt_hor_scroll").css({position: "fixed", bottom: "0"});
        this.bottomFixed = true;
      }
    } else {
      if (this.bottomFixed) {
        this.$cont.find(".gantt_hor_scroll").css({position: "relative", bottom: ""});
        this.bottomFixed = false;
      }
    }
  },
  setPosition: function (top) {
    this.$target.css({transform: "translate(0, " + top + "px)"});
    this.$cont.find(".gantt_grid_scale, .gantt_task_scale").css({transform: "translate(0, " + (top - 1) + "px)"});
  }
});
