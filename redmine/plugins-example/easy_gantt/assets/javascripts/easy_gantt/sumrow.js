/* sumrow.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.sumRow = ysy.pro.sumRow || {};
$.extend(ysy.pro.sumRow, {
  summers: {
    count: {
      day: function (date, issue) {
        if (issue._start_date.isAfter(date)) return 0;
        if (issue._end_date.isBefore(date)) return 0;
        return 1;
      },
      week: function (first_date, last_date, issue) {
        if (issue._start_date.isAfter(last_date)) return 0;
        if (issue._end_date.isBefore(first_date)) return 0;
        return 1;
      },
      //formatter:function(value){return value},
      entities: ["issues"],
      title: "Count"
    }
  },
  patch: function () {
    $.extend(ysy.settings.sumRow, {
      summerArray: [],
      setSummer: function (summer) {
        if (!ysy.pro.sumRow.summers[summer]) return;
        var index = this.summerArray.indexOf(summer);
        if (index !== -1) {
          this.summerArray.splice(index, 1);
        }
        this.summerArray.push(summer);
        this.setSilent({
          active: true,
          summer: summer
        });
        this._fireChanges(this, "setSummer to " + summer);
      },
      removeSummer: function (summer) {
        var index = this.summerArray.indexOf(summer);
        if (index !== -1) {
          this.summerArray.splice(index, 1);
        }
        if (this.summerArray.length === 0) {
          this.setSilent({
            active: false,
            summer: false
          });
        } else {
          this.setSilent({
            active: true,
            summer: this.summerArray[this.summerArray.length - 1]
          });
        }
        this._fireChanges(this, "removeSummer " + summer);
      }
    });
    // ysy.settings.sumRow.setSummer("count");
  }
});


ysy.view = ysy.view || {};
ysy.view.SumRow = function () {
  ysy.view.Widget.call(this);
  this.temper = {
    values: []
  };
};
ysy.main.extender(ysy.view.Widget, ysy.view.SumRow, {
  name: "SumRowWidget",
  _postInit: function () {
    ysy.data.issues.childRegister(this.invalidateIssues, this);
    ysy.data.projects.childRegister(this.invalidateProjects, this);
    ysy.data.issues.register(this.invalidateIssues, this);
    ysy.data.projects.register(this.invalidateProjects, this);
    gantt.attachEvent("onGanttRender", $.proxy(this.requestRepaint, this));
  },
  nopeFormatter: function () {
    return ""
  },
  invalidateProjects: function () {
    if (this.summer && this.summer.entities && this.summer.entities.indexOf("projects") > -1)
      this.requestRepaint();
  },
  invalidateIssues: function () {
    if (this.summer && (!this.summer.entities || this.summer.entities.indexOf("issues") > -1))
      this.requestRepaint();
  },
  getSubScale: function (zoom) {
    var summer = ysy.pro.sumRow.summers[ysy.settings.sumRow.summer];
    if (!summer) return;
    ysy.log.debug("getSubScale for " + summer.title, "summer");
    this.summer = summer;
    this.updateTemper();
    var temper = this.temper;
    // var max = Math.max.apply(null, values);
    // var min = Math.min.apply(null, values);
    var template = this.nopeFormatter;
    if (temper.values) {
      if (summer.formatter) {
        template = function (date) {
          var index = -temper.minDate.diff(date, zoom);
          if (index < 0 || index > temper.valuesLength) return "";
          return summer.formatter(temper.values[index], temper.widths[index]);
        }
      } else {
        template = function (date) {
          var index = -temper.minDate.diff(date, zoom);
          if (index < 0 || index > temper.valuesLength) return "";
          return temper.values[index];
        }
      }
    }
    return {
      step: 1,
      className: "gantt-sum-row",
      unit: zoom,
      template: template
    };
  },
  getSummerFunction: function (zoom) {
    return zoom === "day" ? this.summer.day : this.summer.week;
  },
  getEntities: function () {
    if (!this.summer) return null;
    var types = this.summer.entities || ["issues"];
    var entities = [];
    for (var i = 0; i < types.length; i++) {
      entities = entities.concat(ysy.data[types[i]].getArray());
    }
    return entities;
  },
  _repaintCore: function () {
    if (!ysy.settings.sumRow.active) return;
    ysy.log.debug("sumRow repaintCore", "summer");
    var summer = ysy.pro.sumRow.summers[ysy.settings.sumRow.summer];
    if (!summer) return;
    this.summer = summer;
    this.updateTemper(this.calculateSums(ysy.settings.zoom.zoom));
    var $target = $(".gantt_scale_line.gantt-sum-row");
    var config = gantt.config;

    var resize = gantt._get_resize_options();
    var avail_width = resize.x ? Math.max(config.autosize_min_width, 0) : gantt.$task.offsetWidth;

    var cfgs = gantt._scale_helpers.prepareConfigs([this.getSubScale(ysy.settings.zoom.zoom)], config.min_column_width, avail_width, config.scale_height - 1);
    var html = gantt._prepare_scale_html(cfgs[0]);
    $target.html(html);
  },
  updateTemper: function (values) {
    if (values) {
      this.temper.values = values;
      this.temper.valuesLength = values.length;
    }
    //this.temper.fullRange = moment(gantt._max_date).diff(gantt._min_date, ysy.settings.zoom.zoom);
    this.temper.minDate = moment(gantt._min_date);
    this.temper.widths = gantt._tasks.width;
  },
  calculateSums: function (unit) {
    var summerFunction = this.getSummerFunction(unit);
    var values = [];
    var mover = moment(gantt._min_date);
    var maxDate = moment(gantt._max_date);
    var issues = this.getEntities();
    // var lastValue = 0;
    if (unit === "day") {
      while (mover.isBefore(maxDate)) {
        var count = 0;
        for (var i = 0; i < issues.length; i++) {
          count += summerFunction(mover, issues[i]);
        }
        // if (summer.cumulative) {
        //   count += lastValue;
        // }
        values.push(count);
        // lastValue = count;
        mover.add(1, unit);
      }
    } else {
      var nextMover = moment(mover).add(1, unit);
      while (mover.isBefore(maxDate)) {
        count = 0;
        for (i = 0; i < issues.length; i++) {
          count += summerFunction(mover, nextMover, issues[i]);
        }
        // if (summer.cumulative) {
        //   count += lastValue;
        // }
        values.push(count);
        // lastValue = count;
        mover.add(2, unit);
        var tempMover = mover;
        mover = nextMover;
        nextMover = tempMover;
      }
    }
    return values;
  }
});