window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.sample = {
  patch: function () {
    var setting = ysy.settings.sample;
    $.extend(ysy.view.AllButtons.prototype.extendees, {
      sample: {
        bind: function () {
          this.model = ysy.settings.sample;
        },
        func: function () {
          if (ysy.data.loader.loaded) {
            this.model.toggle();
            ysy.data.loader.load();
          }
        },
        isOn: function () {
          return this.model.active;
        }
        //icon:"zoom-in icon-day"
      }
    });

    $.extend(setting, {
      init: function () {
        if (ysy.settings.easyRedmine || this.isViewed()) {
          this.prevented = true;
        }
        this.active = this.getSampleVersion();
      },
      getSampleVersion: function (turnOn) {
        if (ysy.settings.global) return "global";
        if (turnOn === false) return 0;
        if (turnOn === true) return 1;
        return this.prevented ? 0 : 1;
      },
      toggle: function (turnOn) {
        if (turnOn === undefined) {
          turnOn = !this.active;
        }
        this.setSilent("active", this.getSampleVersion(turnOn));
        this._fireChanges(this, "toggle");
      },
      storageKey: "sample_viewed",
      setViewed: function () {
        ysy.data.storage.savePersistentData(this.storageKey, true);
      },
      isViewed: function () {
        return ysy.data.storage.getPersistentData(this.storageKey);
      }
    });
  },
  _loadSampleData: function (data) {
    if (!data.easy_gantt_data) return;
    var json = data.easy_gantt_data;
    var projects = json.projects;
    for (var i = 0; i < projects.length; i++) {
      projects[i].needLoad = false;
      projects[i].permissions = {editable: true};
    }
    var issues = json.issues;
    for (i = 0; i < issues.length; i++) {
      issues[i].permissions = {editable: true};
    }
    var versions = json.versions;
    for (i = 0; i < versions.length; i++) {
      versions[i].permissions = {editable: true};
    }
    ysy.data.loader._handleMainGantt(data);
  },
  loadSample:function (sampleVersion) {
    ysy.gateway.polymorficGetJSON(
        ysy.settings.paths.sample_data.replace("{{version}}", sampleVersion), null,
        $.proxy(this._loadSampleData, this),
        function () {
          ysy.log.error("Error: Example data fetch failed");
        }
    );
  }
};
//##############################################################################
ysy.view.SuperPanel = function () {
  ysy.view.Widget.call(this);
};
ysy.main.extender(ysy.view.Widget, ysy.view.SuperPanel, {
  name: "SuperPanelWidget",
  templateName: "SuperPanel",
  _repaintCore: function () {
    if (!this.template) {
      var templ = ysy.view.getTemplate(this.templateName);
      if (templ) {
        this.template = templ;
      } else {
        return true;
      }
    }
    var rendered = Mustache.render(this.template, this.out()); // REPAINT
    var $easygantt = $("#easy_gantt");
    $easygantt.find(".flash").remove();
    this.$target = $(rendered);
    $easygantt.prepend(this.$target);
    //window.showFlashMessage("notice",rendered);
    this.tideFunctionality();
  },
  out: function () {
    var obj, label;
    var free = !!ysy.settings.sample.getSampleVersion(false);
    if (free) {
      label = ysy.view.getLabel("sample_global_free_text");
      obj = {global_free: true};
    } else {
      label = ysy.view.getLabel("sample_text");
      obj = {};
    }
    return $.extend({}, {text: label}, {sample: this.model.active}, obj);
  },
  tideFunctionality: function () {
    this.$target.find("#sample_close_button").click($.proxy(function () {
      if (ysy.data.loader.loaded) {
        this.model.setViewed();
        this.model.setSilent("active", false);
        this.model._fireChanges(this, "toggle");
        ysy.data.loader.load();
      }
    }, this));
    this.$target.find("#sample_video_button").click($.proxy(function () {
      if (ysy.settings.global) {
        var template = ysy.view.getTemplate("video_modal_global");
      } else {
        template = ysy.view.getTemplate("video_modal");
      }
      var $modal = ysy.main.getModal("video-modal", "850px");
      $modal.html(template); // REPAINT
      $modal.off("dialogclose");
      window.showModal("video-modal", 850);
      $modal.on("dialogclose", function () {
        $modal.empty();
      });
    }));
  }
});