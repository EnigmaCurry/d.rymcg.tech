/* gantt_widget.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};
//#####################################################################
ysy.view.Gantt = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttInitWidget";
  ysy.log.message("widget Gantt created");
};
ysy.main.extender(ysy.view.Widget, ysy.view.Gantt, {
  _updateChildren: function () {
    if (this.children.length > 0) {
      return;
    }
    var renderer = new ysy.view.GanttRender();
    renderer.init(
        ysy.data.limits,
        ysy.settings.critical,
        ysy.settings.zoom,
        ysy.settings.sumRow
    );
    this.children.push(renderer);
  },
  _postInit: function () {
    //gantt.initProjectMarker(this.model.start,this.model.end);
  },
  _repaintCore: function () {
    if (this.$target === null) {
      throw "Target is null for " + this.name;
    }
    if (!ysy.data.columns) {
      //ysy.log.log("GanttInitWidget: columns are missing");
      return true;
    }
    ysy.data.limits.setSilent("zoomDate", gantt.getShowDate() || moment());
    ysy.view.initGantt();
    this.addBaselineLayer();
    gantt.init(this.$target); // REPAINT
    ysy.log.debug("gantt.init()", "load");
    this.tideFunctionality(); //   TIDE FUNCTIONALITY
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      child.$target = this.$target;  //   SET CHILD TARGET
      child.repaint(true); //  CHILD REPAINT
    }
    if (!ysy.settings.controls.controls) {
      $(".gantt_bars_area").addClass("no_task_controls");
    }
    dhtmlx.dragScroll();
  },
  addBaselineLayer: function () {
  }
});
//##############################################################################
ysy.view.GanttRender = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttRenderWidget";
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttRender, {
  _updateChildren: function () {
    if (!this.tasks) {
      this.tasks = new ysy.view.GanttTasks();
      this.tasks.init(
          ysy.data.issues,
          ysy.data.milestones,
          ysy.data.projects,
          ysy.settings.resource,
          ysy.data.assignees,
          ysy.settings.scheme
      );
      this.children.push(this.tasks);
    }
    if (!this.links) {
      this.links = new ysy.view.GanttLinks();
      this.links.init(
          ysy.data.relations,
          ysy.settings.resource
      );
      this.children.push(this.links);
    }
    if (!this.refresher) {
      this.refresher = new ysy.view.GanttRefresher();
      this.refresher.init(gantt);
      this.children.push(this.refresher);
    }
    if (!this.sumRow && ysy.settings.sumRow.active) {
      this.sumRow = new ysy.view.SumRow();
      this.sumRow.init();
      this.children.push(this.sumRow);
    }
  },
  zoomTo: function (timespan) {
    if (timespan === "year") {
      $.extend(gantt.config, {
        scale_unit: "year",
        date_scale: "%Y",
        subscales: [
        ]
      });
    } else if (timespan === "quarter") {
      $.extend(gantt.config, {
        scale_unit: "quarter",
        date_scale: "%Q",
        subscales: [
          {unit: "year", step: 1, date: "%Y"}
        ]
      });
    } else if (timespan === "month") {
      $.extend(gantt.config, {
        scale_unit: "month",
        date_scale: "%M",
        subscales: [
          {unit: "year", step: 1, date: "%Y"}
        ]
      });
    } else if (timespan === "week") {
      $.extend(gantt.config, {
        scale_unit: "week",
        date_scale: "%W",
        subscales: [
          {unit: "month", step: 1, date: "%F %Y"}
        ]
      });
    } else if (timespan === "day") {
      $.extend(gantt.config, {
        scale_unit: "day",
        date_scale: "%d",
        subscales: [
          {unit: "month", step: 1, date: "%F %Y"}
        ]
      });
    }
    if (this.sumRow && ysy.settings.sumRow.active) {
      gantt.config.subscales.push(this.sumRow.getSubScale(timespan));
    }
  },
  _repaintCore: function () {
    if (this.$target === null) {
      throw "Target is null for " + this.name;
    }
    this.zoomTo(ysy.settings.zoom.zoom);
    //this.addBaselineLayer();
    //ysy.data.limits.setSilent("pos", gantt.getScrollState());
    //var pos = ysy.data.limits.pos;
    //if (pos)ysy.log.debug("scrollSave pos={x:" + pos.x + ",y:" + pos.y + "}", "scroll");
    // gantt.render();
    this.tideFunctionality(); //   TIDE FUNCTIONALITY
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      child.repaint(true); //  CHILD REPAINT
    }

  },
  addBaselineLayer: function () {
  }
});
//##############################################################################
ysy.view.GanttTasks = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttTasksWidget";
  ysy.view.ganttTasks = this;
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttTasks, {
  _selectChildren: function () {
    var issues = this.model.getArray();
    var milestones = ysy.data.milestones.getArray();
    var projects = ysy.data.projects.getArray();
    return issues.concat(milestones,projects);
  },
  _updateChildren: function () {
    var combined = this._selectChildren();
    //var combined=issues.concat(milestones);
    var i, model, task;
    if (this.children.length === 0) {
      for (i = 0; i < combined.length; i++) {
        model = combined[i];
        task = new ysy.view.GanttTask();
        task.init(model);
        task.parent = this;
        task.order = i + 1;
        this.children.push(task);
      }
    } else {
      var narr = [];
      var temp = {};
      for (i = 0; i < this.children.length; i++) {
        var child = this.children[i];
        temp[child.model.getID()] = child;
      }
      for (i = 0; i < combined.length; i++) {
        model = combined[i];
        task = temp[model.getID()];
        if (!task) {
          task = new ysy.view.GanttTask();
          task.init(model);
          task.parent = this;
        } else {
          delete temp[model.getID()];
        }
        task.order = i + 1;
        narr.push(task);
      }
      for (var key in temp) {
        if (temp.hasOwnProperty(key)) {
          temp[key].destroy(true);
        }
      }
      //var narr = [];
      this.children = narr;
    }
    ysy.log.log("-- " + this.children.length + " Children updated in " + this.name);
  },
  _repaintCore: function () {
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      //this.setChildTarget(child, i); //   SET CHILD TARGET
      child.repaint(true); //  CHILD REPAINT
    }
    gantt._sync_links();
    gantt.reconstructTree();
    gantt.sort(gantt._sort && gantt._sort.criteria);
    //window.initInlineEditForContainer($("#gantt_cont")); // TODO
  }
});
//##############################################################################
ysy.view.GanttTask = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttTaskWidget";
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttTask, {
  _repaintCore: function () {
    var issue = this.model;
    var gantt_issue = this._constructDhData(issue);
    if (gantt._pull[gantt_issue.id]) {
      if (this.dhdata.parent != gantt_issue.realParent) {
        gantt.silentMoveTask(this.dhdata, gantt_issue.realParent);
        delete gantt_issue.realParent;
      }
      $.extend(this.dhdata, gantt_issue);
      gantt.refreshTask(gantt_issue.id);
    } else {
      this.destroyDhData();
      this.dhdata = gantt_issue;
      ysy.log.debug("addTaskNoDraw()", "load");
      gantt.addTaskFaster(gantt_issue);
    }
    //window.initInlineEditForContainer($("#gantt_cont"));  // TODO
  },
  destroyDhData: function (silent) {
    if (!this.dhdata) return;
    this.dhdata.deleted = true;
    if (gantt.isTaskExists(this.dhdata.id)) {
      gantt._deleteTask(this.dhdata.id, silent);
    }
    this.dhdata = null;
    ysy.log.debug("Destroy for " + this.name, "widget_destroy");
  },
  destroy: function (silent) {
    this.destroyDhData(silent);
    this.deleted = true;
  },
  _constructDhData: function (issue) {
    // var parent = issue.getParent() || 0;
    var gantt_issue = {
      id: issue.getID(),
      real_id: issue.id,
      text: issue.name,
      css: (issue.css || '') + (issue.closed ? ' closed' : ''),
      //model:issue,
      widget: this,
      order: this.order,
      open: issue.isOpened(),
      start_date: issue.start_date ? moment(issue.start_date) : undefined,
      $ignore: issue._ignore || false,
      columns: issue.columns,
      readonly: !issue.isEditable(),
      realParent: issue.getParent() || 0,
      type: issue.ganttType
    };
    gantt_issue.$open = gantt_issue.open;
    if (issue.isProject) {
      //  -- PROJECT --
      $.extend(gantt_issue, {
        progress: issue.getProgress(),
        maximal_start: issue.start_date,
        minimal_end: issue.end_date,
        start_date: issue.start_date,
        end_date: issue.end_date
      });
    } else if (issue.isIssue) {
      //   -- ISSUE --
      var end_date = moment(issue._end_date);
      //if (!issue._end_date.isValid()) {
      //  console.error("_end_date is not valid");
      //  end_date = moment(issue._start_date).add(1, "d");
      //}
      end_date._isEndDate = true;
      $.extend(gantt_issue, {
        start_date: moment(issue._start_date),
        end_date: end_date,
        progress: (issue.done_ratio || 0) / 100.0,
        //duration: issue.end_date.diff(issue.start_date, 'days'),
        assigned_to: issue.assigned_to,
        estimated: issue.estimated_hours || 0,
        soonest_start: issue.soonest_start,
        latest_due: issue.latest_due
      });
    } else if (issue.milestone) {
      //  -- MILESTONE --
      gantt_issue.end_date = moment(gantt_issue.start_date);
      gantt_issue.end_date._isEndDate = true;
    } else {
      //  -- ASSIGNEE --
    }
    ysy.proManager.fireEvent("extendGanttTask", issue, gantt_issue);
    return gantt_issue;
  },
  update: function (item, keys) {
    var obj;
    if (item.type === "milestone") {
      this.model.set({
        name: item.text,
        start_date: moment(item.start_date)
      });
    } else if (item.type === "project") {
      obj = {
        start_date: moment(item.start_date),
        end_date: moment(item.end_date),
        _shift: item.start_date.diff(this.model.start_date, "days") + (this.model._shift || 0)
      };
      obj.end_date._isEndDate = true;
      this.model.set(obj);
    } else {
      var fullObj = {
        name: item.text,
        //assignedto: item.assignee,
        estimated_hours: item.estimated,
        done_ratio: Math.round(item.progress * 10) * 10,
        start_date: moment(item.start_date),
        end_date: moment(item.end_date)
      };
      fullObj.end_date._isEndDate = true;
      if (item._parentChanged) {
        $.extend(fullObj, this._constructParentUpdate(item.parent));
        item._parentChanged = false;
      }
      obj = fullObj;
      if (keys !== undefined) {
        obj = {};
        for (var i = 0; i < keys.length; i++) {
          var key = keys[i];
          if (key === "fixed_version_id") {
            if (typeof item.parent === "string") {
              obj.fixed_version_id = parseInt(item.parent.substring(1));
            } else {
              obj.parent = item.parent;  // TODO subtask žížaly musí mít parent nebo něco
            }
            //this.parent.requestRepaint();
          } else {
            obj[key] = fullObj[key];
          }
        }
      }
      this.model.set(obj);
    }
    this.requestRepaint();
  },
  _constructParentUpdate: function (parentId) {
    if (typeof parentId !== "string") {
      var parent = gantt._pull[parentId];
      if (!parent) return {};
      var parentModel = parent.widget.model;
      if (!parentModel) return {};
      if (parentModel.fixed_version_id) {
        return {
          parent_issue_id: parentId,
          fixed_version_id: parentModel.fixed_version_id,
          project_id: parentModel.project_id
        };
      } else {
        return {parent_issue_id: parentId, project_id: parentModel.project_id};
      }
    } else if (ysy.main.startsWith(parentId, "p")) {
      return {
        parent_issue_id: null, project_id: parseInt(parentId.substring(1)), fixed_version_id: null
      };
    } else if (ysy.main.startsWith(parentId, "m")) {
      return {
        parent_issue_id: null, fixed_version_id: parseInt(parentId.substring(1))
      };
    } else if (parentId === "empty") {
      return {
        parent_issue_id: null, project_id: ysy.settings.projectID, fixed_version_id: null
      };
    } else return null;
  }
});
//##############################################################################
ysy.view.GanttLinks = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttLinksWidget";
  ysy.view.ganttLinks = this;
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttLinks, {
  _updateChildren: function () {
    var rela, link, i;
    var model = this.model.getArray();
    if (this.children.length === 0) {
      for (i = 0; i < model.length; i++) {
        rela = model[i];
        if (rela.isHalfLink()) continue;
        link = new ysy.view.GanttLink();
        link.init(rela);
        this.children.push(link);
      }
    } else {
      var narr = [];
      var temp = {};
      for (i = 0; i < this.children.length; i++) {
        var child = this.children[i];
        temp[child.model.id] = child;
      }
      for (i = 0; i < model.length; i++) {
        rela = model[i];
        if (rela.isHalfLink()) continue;
        link = temp[rela.id];
        if (!link) {
          link = new ysy.view.GanttLink();
          link.init(rela);
        } else {
          delete temp[rela.id];
        }
        narr.push(link);
      }
      for (var key in temp) {
        if (temp.hasOwnProperty(key)) {
          temp[key].destroy(true);
        }
      }
      this.children = narr;
    }
    ysy.log.log("-- " + this.children.length + " Children updated in " + this.name);
  },
  _repaintCore: function () {
    //this._updateTaskInGantt();
    for (var i = 0; i < this.children.length; i++) {
      var child = this.children[i];
      //this.setChildTarget(child, i); //   SET CHILD TARGET
      child.repaint(true); //  CHILD REPAINT
    }
    //gantt.refreshData();
  }
});
//##############################################################################
ysy.view.GanttLink = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttLinkWidget";
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttLink, {
  _repaintCore: function () {
    var rela = this.model;
    var link = this._constructDhData(rela);
    if (gantt._lpull[link.id]) {
      $.extend(this.dhdata, link);
      gantt.refreshLink(link.id);
      gantt.refreshTask(link.source);
      gantt.refreshTask(link.target);
    } else {
      this.dhdata = link;
      gantt.addLink(link);
    }
    //gantt.sort();
  },
  destroy: function (silent) {
    if (this.dhdata) {
      this.dhdata.deleted = true;
      if (gantt.isLinkExists(this.model.id)) {
        gantt._deleteLink(this.model.id, silent);
      }
      this.dhdata = null;
      ysy.log.debug("Destroy for " + this.name, "widget_destroy");
    }
    this.deleted = true;
  },
  _constructDhData: function (model) {
    return {
      id: model.id,
      source: model.source_id,
      target: model.target_id,
      type: model.isSimple ? "start_to_start" : model.type,
      isSimple: model.isSimple,
      unlocked: model.unlocked,
      delay: model.delay,
      readonly: !model.isEditable(),
      widget: this
    };
  },
  update: function (item) {
    ysy.history.openBrack();
    this.model.set({
      // name: item.text,
      // source_id: item.source,
      // target_id: item.target,
      type: this.model.type || item.type,
      delay: item.delay
    });
    var allRequests = {};
    this.model.sendMoveRequest(allRequests);
    gantt.applyMoveRequests(allRequests);
    ysy.history.closeBrack();
  }

});
//##############################################################################
ysy.view.GanttRefresher = function () {
  ysy.view.Widget.call(this);
  this.name = "GanttRefresherWidget";
  this.all = false;
  this.data = false;
  this.tasks = [];
  this.links = [];
};
ysy.main.extender(ysy.view.Widget, ysy.view.GanttRefresher, {
  _postInit: function () {
    this.model.refresher = this;
  },
  _register: function () {
  },
  renderAll: function () {
    this.all = true;
    this.requestRepaint();
  },
  renderData: function () {
    this.data = true;
    this.requestRepaint();
  },
  refreshTask: function (taskId) {
    for (var i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i] == taskId) return;
    }
    this.tasks.push(taskId);
    this.requestRepaint();
  },
  refreshLink: function (linkId) {
    for (var i = 0; i < this.links.length; i++) {
      if (this.links[i] == linkId) return;
    }
    this.links.push(linkId);
    this.requestRepaint();
  },
  _repaintCore: function () {
    if (this.all) {
      ysy.log.debug("---- Refresher: _renderAll", "refresher");
      var visibleDate = gantt.getShowDate();
      if (!visibleDate) {
        visibleDate = ysy.data.limits.zoomDate;
      }
      gantt._backgroundRenderer.forceRender = false;
      this.model._render();
      gantt._backgroundRenderer.forceRender = true;
      //ysy.log.debug(moment(visibleDate).toISOString(), "refresher");
      gantt.showDate(visibleDate);
      delete gantt._backgroundRenderer.forceRender;
      ysy.view.affix.requestRepaint();
    } else if (this.data) {
      ysy.log.debug("---- Refresher: _renderData", "refresher");
      this.model._render_data();
      if (this.all) return true;
    } else {
      ysy.log.debug("---- Refresher: _render for " + this.tasks.length + " tasks and " + this.links.length + " links", "refresher");
      for (var i = 0; i < this.tasks.length; i++) {
        var taskId = this.tasks[i];
        this.model._refreshTask(taskId);
        if (this.all || this.data) return true;
      }
      for (i = 0; i < this.links.length; i++) {
        var linkId = this.links[i];
        this.model._refreshLink(linkId);
        if (this.all || this.data) return true;
      }
    }
    this.all = false;
    this.data = false;
    this.tasks = [];
    this.links = [];
  }

});
