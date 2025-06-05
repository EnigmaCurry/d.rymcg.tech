/**
 * Created by Ringael on 5. 8. 2015.
 */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.baseline = {
  name: "Baseline PRO",
  initToolbar: function (ctx) {
    var baselinePanel = new ysy.view.BaselinePanel();
    baselinePanel.init(ysy.data.baselines, ysy.settings.baseline);
    ctx.children.push(baselinePanel);
  },
  patch: function () {
    var baselineClass = ysy.pro.baseline;
    ysy.proManager.register("initToolbar", this.initToolbar);
    ysy.proManager.register("close", this.close);
    ysy.proManager.register("ganttConfig", this.ganttConfig);


    ysy.view.AllButtons.prototype.extendees.baseline = {
      bind: function () {
        this.model = ysy.settings.baseline;
        this._register(ysy.settings.resource);
      },
      func: function () {
        ysy.proManager.closeAll(baselineClass);
        var sett = ysy.settings.baseline;
        sett.setSilent("open", !sett.open);
        sett._fireChanges(this, "toggle");
      },
      isOn: function () {
        return ysy.settings.baseline.open;
      },
      isHidden: function () {
        return ysy.settings.resource.open;
      },
      //model:ysy.settings.baseline,
      icon: "projects"
    };
    ysy.view.columnBuilders = ysy.view.columnBuilders || {};
    ysy.view.columnBuilders.baseline_start_date = function (task) {
      var base = ysy.pro.baseline._getBaselineForTask(task);
      if (!base || !base.start_date) return;
      if (base.start_date.isSame(task.start_date))
        return '<span>' + ysy.settings.labels.baselines.label_same + '</span>';
      return '<span >' + base.start_date.format(gantt.config.date_format) + '</span>';
    };
    ysy.view.columnBuilders.baseline_end_date = function (task) {
      var base = ysy.pro.baseline._getBaselineForTask(task);
      if (!base || !base.end_date) return;
      if (base.end_date.isSame(task.end_date))
        return '<span>' + ysy.settings.labels.baselines.label_same + '</span>';
      return '<span >' + base.end_date.format(gantt.config.date_format) + '</span>';
    };
    ysy.view.Gantt.prototype.addBaselineLayer = function (ctx) {
      baselineClass.addLayer();
    };
    ysy.settings.baseline.register(this.settingWatcher, this);
  },
  settingWatcher: function () {
    var settings = ysy.settings.baseline;
    //ysy.log.debug("settings.baseline onChange ["+settings.open+","+settings.active+"]","baseline");
    // GET ACTIVE BASELINE
    if (settings.open && settings.active) {
      var active = settings.active;
      var baseline = ysy.data.baselines.getByID(active);
      if (!baseline.loaded) {
        ysy.log.debug("loadBaseline " + active, "baseline");
        ysy.data.baselines.getByID(active).fetch();
        return;
      }
    }
    // GET BASELINE HEADER
    //ysy.log.debug("settings.baseline onChange ["+settings.open+","+settings.active+"]","baseline");
    if (settings.open && !settings.headerLoaded) {
      ysy.log.debug("loadBaselineHeader", "baseline");
      ysy.gateway.loadBaselineHeader(function (data) {
        var baselines = ysy.data.baselines;
        //baselines.clearSilent();
        var base_array = baselines.getArray();
        for (var i = 0; i < base_array.length; i++) {
          base_array[i]._deleted = true;
        }
        baselines.clearCache();
        var array = data.easy_baselines;
        for (i = 0; i < array.length; i++) {
          var base_data = array[i];
          var baseline = baselines.getByID(base_data.id);
          if (!baseline) baseline = new ysy.data.Baseline();
          baseline.init(base_data, ysy.data.baselines);
          baseline._deleted = false;
          baselines.pushSilent(baseline);
        }
        //ysy.log.debug("header loaded","baseline");
        baselines._fireChanges(ysy.settings.baseline, "header loaded");
        if (!settings.active && baselines.getArray().length) {
          var arr = baselines.getArray();
          var last = arr[arr.length - 1];
          settings.setSilent("active", last.id);
          ysy.log.debug("last baseline ID=" + last.id + " active", "baseline");
          last.fetch();
          //settings._fireChanges(this,"first baseline active");
        }
      });
      settings.headerLoaded = true;
      return;
    }
    ysy.log.debug("Baseline: gantt.render()", "baseline");
    ysy.view.initGantt();
    if (ysy.settings.baseline.open) {
      $("#gantt_cont").addClass("gantt-baselines");
    } else {
      $("#gantt_cont").removeClass("gantt-baselines");
    }
    //ysy.pro.baseline.addLayer();
    gantt.render();
  },
  close: function () {
    var sett = ysy.settings.baseline;
    if (sett.setSilent("open", false)) {
      sett._fireChanges(this, "close");
    }
  },
  resetHeader: function () {
    ysy.settings.baseline.setSilent("headerLoaded", false);
    ysy.settings.baseline.setSilent("active", false);
    ysy.settings.baseline._fireChanges(this, "reload after saveBaseline");
  },
  _getBaselineForTask: function (task) {
    var baseline = ysy.data.baselines.getByID(ysy.settings.baseline.active);
    if (!baseline || !baseline.loaded) return;
    //ysy.log.debug("baseline drawn for task "+task.id,"baseline");
    ysy.log.debug("baseline drawn", "baseline_render");
    if (task.type === gantt.config.types.milestone) {
      var base = baseline.versions[task.real_id];
    } else if (gantt._get_safe_type(task.type) === gantt.config.types.task) {
      base = baseline.issues[task.real_id];
    }
    return base;
  },
  addLayer: function () {
    if (!ysy.settings.baseline.open) return;
    var layer = gantt.addTaskLayer(function draw_planned(task) {
      if (!ysy.settings.baseline.open) return;
      if (!ysy.settings.baseline.active) return;
      var base = ysy.pro.baseline._getBaselineForTask(task);
      if (!base) return;
      var base_start = base.start_date;
      var base_end = base.end_date;
      ysy.log.debug("start=" + task.start_date.format("DD.MM.YYYY") + " bstart=" + base.start_date.format("DD.MM.YYYY"), "baseline_render");
      /*if (!task.base_start){
       task.base_start=moment(task.start_date);
       }
       if(!task.base_end) {
       task.base_end=gantt.date.Date(task.end_date);
       }*/
      var sizes = gantt.getTaskPosition(task, base_start, base_end);
      var className = 'gantt-baseline';
      if (task.type === "milestone") {
        var side = sizes.height;
        sizes.width = side;
        sizes.left -= side / 2 + 1;
        className += " gantt_milestone-type";
      } else {
        sizes.width -= 2;
        delete sizes.height;
      }
      var el = document.createElement('div');
      el.className = className;
      el.style.left = sizes.left + 'px';
      if (sizes.height) {
        el.style.height = sizes.height + 'px';
      }
      el.style.width = sizes.width + 'px';
      el.style.top = sizes.top + gantt.config.task_height + 13 + 'px';
      return el;
    });
    ysy.log.debug("TaskLayer ID=" + layer + " created", "baseline");
  },
  ganttConfig: function (config) {
    if (!ysy.settings.baseline.open) return;
    var labels = ysy.settings.labels.baselines;
    var baselineColumns = [
      {
        name: "baseline_start_date",
        title: labels.baseline + ' ' + labels.startDate
      },
      {
        name: "baseline_end_date",
        title: labels.baseline + ' ' + labels.dueDate
      }
    ];
    var columns = gantt.config.columns;
    columns = columns.concat(ysy.view.leftGrid.constructColumns(baselineColumns));
    $.extend(config, {
      columns: columns,
      task_height: 16,
      row_height: 40
    });
  }
};
//#############################################################################################
ysy.view.BaselinePanel = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.BaselinePanel, {
  name: "BaselinePanelWidget",
  templateName: "BaselineOption",
  _repaintCore: function () {
    var sett = ysy.settings.baseline;
    var target = this.$target;
    if (sett.open) {
      target.show();
    } else {
      target.hide();
      return;
    }
    if (!this.template) {
      var templ = ysy.view.getTemplate(this.templateName);
      if (templ) {
        this.template = templ;
      } else {
        return true;
      }
    }
    var baseOut = [
      //{name:"None selected",id:"none"}
    ];
    var model = this.model.getArray();
    if (model.length === 0) {
      target.find("#baseline_select").hide();
      target.find("#baseline_delete").hide();
    } else {
      for (var i = 0; i < model.length; i++) {
        baseOut.push({name: model[i].name, id: model[i].id, selected: model[i].id === sett.active ? " selected" : ""});
      }
      var rendered = Mustache.render(this.template, {baselines: baseOut});
      target.find("#baseline_select").show().html(rendered);
      target.find("#baseline_delete").show();
    }

    this.tideFunctionality();
  },
  tideFunctionality: function () {
    var baselineClass = ysy.pro.baseline;
    this.$target.find("#baseline_select").off("change").on("change", function (event) {
      var baseID = parseInt($(this).val());
      ysy.settings.baseline.setSilent("active", baseID);
      ysy.settings.baseline._fireChanges(ysy.view.BaselinePanel, "select")
    });
    this.$target.find("#baseline_create:not(.disabled)").off("click").on("click", function () {
      ysy.log.debug("Create baseline button pressed", "baseline");
      if (!ysy.history.isEmpty()) {
        dhtmlx.message(ysy.settings.labels.baselines.error_not_saved, "error");
        return;
      }
      baselineClass.openCreateModal();
    });
    this.$target.find("#baseline_delete:not(.disabled)").off("click").on("click", function () {
      ysy.log.debug("Delete baseline button pressed", "baseline");
      var baseline = ysy.data.baselines.getByID(ysy.settings.baseline.active);
      if (!baseline) return;
      var confirmLabel = $(this).data("confirmation");
      var confirmation = window.confirm(confirmLabel);
      if (!confirmation) return;
      ysy.gateway.deleteBaseline(baseline.id, function () {
            ysy.log.debug("deleteBaseline callback", "baseline");
            baselineClass.resetHeader();
          },
          function (response) {
            // FAIL
            var responseJSON = response.responseJSON;
            if (responseJSON && responseJSON.errors) {
              var errors = responseJSON.errors.join(", ");
            }
            dhtmlx.message(ysy.view.getLabel("baseline", "delete_failed") + ": " + errors, "error");
          });
    });
    this.$target.find("#button_baseline_help").off("click").on("click", ysy.proManager.showHelp);
  }
});
//##################################################################################################
ysy.pro.baseline.openCreateModal = function () {

  var generic = moment().format(gantt.config.date_format + " HH:mm") + " " + ysy.settings.project.name;
  var $target = ysy.main.getModal("form-modal", "50%");
  var submitFce = function () {
    var name = $target.find("#baseline_modal_name").val();
    ysy.gateway.saveBaseline(name, function (data) {
          ysy.log.debug("saveBaseline callback", "baseline");
          ysy.pro.baseline.resetHeader();
          //var baselines = ysy.data.baselines;
          //var baseline = new ysy.data.Baseline();
          //baseline.init({
          //  name: data.easy_baseline.name || name || generic,
          //  id: data.easy_baseline.id,
          //  mapping: data
          //}, baselines);
          //baselines.pushSilent(baseline);
          //baselines.clearCache();
          //ysy.settings.baseline.setSilent("active", baseline.id);
          //ysy.settings.baseline._fireChanges(ysy.pro.baseline, "baseline saved");
        },
        function (response) {
          // FAIL
          var responseText = response.responseText;
          try {
            var json = JSON.parse(responseText);
            if (json.errors.length) {
              responseText = json.errors.join(", ");
            }
          } catch (e) {
          }
          dhtmlx.message(ysy.view.getLabel("baselineCreateModal").request_failed + ": " + responseText, "error");
        });
    $target.dialog("close");
  };

  var template = ysy.view.getTemplate("baselineCreateModal");
  //var labels=
  var obj = $.extend({}, ysy.view.getLabel("baselineCreateModal"), {generic: generic});
  var rendered = Mustache.render(template, obj);
  $target.html(rendered);
  showModal("form-modal");
  $target.dialog({
    buttons: [
      {
        id: "baseline_modal_submit",
        text: ysy.settings.labels.buttons.button_submit,
        class: "button-1 button-positive",
        click: submitFce
      },
      {
        id: "baseline_modal_cancel",
        text: ysy.settings.labels.buttons.button_cancel,
        class: "button-2",
        click: function () {
          $target.dialog("close");
        }
      }
    ]
  });
};
//##################################################################################################
ysy.data.Baseline = function () {
  ysy.data.Data.call(this);
};
ysy.main.extender(ysy.data.Data, ysy.data.Baseline, {
  _name: "Baseline",
  fetch: function () {
    var thiss = this;
    ysy.log.debug("baseline " + this.id + " fetch", "baseline");
    if (this.loaded) {
      ysy.settings.baseline._fireChanges(this, "baseline active and loaded");
      return;
    } else if (!this.isLoading) {
      ysy.gateway.loadBaselineData(this.id, function (data) {
        thiss.construct(data.easy_baseline_gantt);
        thiss.loaded = true;
        thiss.isLoading = false;
        //ysy.log.debug("SourceData of baseline " + thiss.id + " loaded", "baseline");
        thiss.fetch();
      });
    }
    this.isLoading = true;
  },
  construct: function (data) {
    this.issues = {};
    for (var i = 0; i < data.issues.length; i++) {
      var source = data.issues[i];
      var target = {
        start_date: source.start_date ? moment(source.start_date, "YYYY-MM-DD") : moment().startOf("day"),
        end_date: source.due_date ? moment(source.due_date, "YYYY-MM-DD") : moment().startOf("day"),
        done_ratio: source.done_ratio,
        id: source.connected_to_issue_id
      };
      if (target.start_date.isAfter(target.end_date)) {
        if (source.start_date) {
          target.end_date = moment(target.start_date);
        } else {
          target.start_date = moment(target.end_date);
        }
      }
      target.end_date._isEndDate = true;
      this.issues[target.id] = target;
    }
    this.versions = {};
    for (i = 0; i < data.versions.length; i++) {
      source = data.versions[i];
      target = {
        start_date: moment(source.start_date, "YYYY-MM_DD"),
        id: source.connected_to_version_id
      };
      target.start_date._isEndDate = true;
      this.versions[target.id] = target;
    }
  }
});
if (ysy.gateway === undefined) {
  ysy.gateway = {};
}
$.extend(ysy.gateway, {
  loadBaselineHeader: function (callback) {
    var urlTemplate = ysy.settings.paths.baselineRoot;
    this.polymorficGetJSON(urlTemplate, null, callback);
  },
  loadBaselineData: function (baselineID, callback) {
    var urlTemplate = ysy.settings.paths.baselineGET.replace(":baselineID", baselineID);
    this.polymorficGetJSON(urlTemplate, null, callback);
  },
  saveBaseline: function (name, callback, fail) {
    ysy.log.debug("Create baseline request", "baseline");
    //return callback();
    var data = null;
    if (name) {
      data = {easy_baseline: {name: name}};
    }
    var urlTemplate = ysy.settings.paths.baselineRoot;
    this.polymorficPost(urlTemplate, null, data, callback, fail);
  },
  deleteBaseline: function (baselineID, callback) {
    ysy.log.debug("Delete baseline ID=" + baselineID + " request", "baseline");
    //return callback();
    var urlTemplate = ysy.settings.paths.baselineDELETE.replace(":baselineID", baselineID);
    this.polymorficDelete(urlTemplate, null, callback);
  }
});
