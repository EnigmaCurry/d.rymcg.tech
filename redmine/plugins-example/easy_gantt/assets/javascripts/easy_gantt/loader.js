/* loader.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.data = ysy.data || {};
ysy.data.loader = ysy.data.loader || {};
$.extend(ysy.data.loader, {
  /*
   * this object is responsible for downloading and preparing data from server
   */
  _name: "Loader",
  loaded: false,
  inited: false,
  issueIdListMap: {},
  _onChange: [],
  init: function () {
    var settings = ysy.settings;
    var data = ysy.data;
    if (settings.paths.rootPath.substr(-1) !== "/") {
      settings.paths.rootPath += "/";
    }
    if (!settings.project) {
      settings.global = true;
    }
    if (settings.project) {
      settings.projectID = parseInt(settings.project.id);
    }
    settings.zoom = new ysy.data.Data();
    settings.zoom.init({zoom: data.storage.getSavedZoom() || ysy.settings.defaultZoom || "day", _name: "Zoom"});
    settings.controls = new ysy.data.Data();
    settings.controls.init({controls: true, _name: "Task controls"});
    settings.baseline = new ysy.data.Data();
    settings.baseline.init({open: false, _name: "Baselines"});
    settings.critical = new ysy.data.Data();
    settings.critical.init({open: false, active: false, _name: "Critical path"});
    settings.addTask = new ysy.data.Data();
    settings.addTask.init({open: false, type: "issue", _name: "Add Task"});
    settings.resource = new ysy.data.Data();
    settings.resource.init({open: false, _name: "Resource Management"});
    settings.sumRow = new ysy.data.Data();
    settings.sumRow.init({_name: "SumRow"});
    settings.sample = new data.Data();
    data.limits = new data.Data();
    data.limits.init({_name: "Limits", openings: {}});
    data.relations = new data.Array().init({_name: "RelationArray"});
    data.issues = new data.Array().init({_name: "IssueArray"});
    data.milestones = new data.Array().init({_name: "MilestoneArray"});
    data.projects = new data.Array().init({_name: "ProjectArray"});
    data.baselines = new data.Array().init({_name: "BaselineArray"});
    ysy.view.patch();
    ysy.proManager.patch();
    settings.sample.init();
    this.inited = true;
  },
  load: function () {
    // second part of program initialization
    this.loaded = false;
    //this.projects=new ysy.data.Array;
    //var data=ysy.availableProjects;
    ysy.log.debug("load()", "load");
    if (ysy.settings.sample.active) {
      ysy.pro.sample.loadSample(ysy.settings.sample.active);
    } else {
      ysy.gateway.loadGanttdata(
          $.proxy(this._handleMainGantt, this),
          function () {
            ysy.log.error("Error: Unable to load data");
          }
      );
    }
  },
  loadSubEntity: function (type, id) {
    if (type === "project") {
      return this.loadProject(id);
    }
  },
  register: function (func, ctx) {
    this._onChange.push({func: func, ctx: ctx});
  },
  /**
   *
   * @param {Array.<{id:int}>} array
   * @param {Array.<int>} oldIds
   * @return {Array.<{id:int}>}
   */
  reorderArray: function (array, oldIds) {
    var newArray = [];
    var arrayPointer = 0;
    for (var i = 0; i < array.length; i++) {
      if (oldIds.length === i || oldIds[i] !== array[i].id) {
        if (i > 0) {
          newArray = array.slice(0, i);
          arrayPointer = i;
          oldIds = oldIds.slice(i);
        }
        break;
      }
    }
    var banned = [];
    for (i = 0; i < oldIds.length; i++) {
      for (var j = arrayPointer; j < array.length; j++) {
        if (array[j].id === oldIds[i]) {
          newArray.push(array[j]);
          banned.push(array[j]);
          break;
        }
      }
    }
    for (i = arrayPointer; i < array.length; i++) {
      if (banned.indexOf(array[i]) > -1) continue;
      newArray.push(array[i]);
    }
    return newArray;
  },
  _fireChanges: function (who, reason) {
    for (var i = 0; i < this._onChange.length; i++) {
      var ctx = this._onChange[i].ctx;
      if (!ctx || ctx.deleted) {
        this._onChange.splice(i, 1);
        continue;
      }
      //this.onChangeNew[i].func();
      ysy.log.log("-- changes to " + (ctx.name ? ctx.name : ctx._name) + " widget");
      $.proxy(this._onChange[i].func, ctx)();
    }
  },
  _handleMainGantt: function (data) {
    if (!data.easy_gantt_data) return;
    var json = data.easy_gantt_data;
    ysy.log.debug("_handleGantt()", "load");
    //  -- LIMITS --
    //ysy.data.limits.set({ // TODO
    //  start_date: moment(json.start_date, "YYYY-MM-DD"),
    //  end_date: moment(json.end_date, "YYYY-MM-DD")
    //});
    //  -- COLUMNS --
    ysy.data.columns = json.columns;
    // ARRAY INITIALIZATION
    //  -- RELATIONS --
    ysy.data.relations.clear();
    //  -- ISSUES --
    ysy.data.issues.clear();
    //  -- MILESTONES --
    ysy.data.milestones.clear();
    //  -- PROJECTS --
    ysy.data.projects.clear();
    // ARRAY FILLING
    //  -- PROJECTS --
    this._loadProjects(json.projects);
    //  -- ISSUES --
    this._loadIssues(json.issues, "root");
    //  -- MILESTONES --
    this._loadMilestones(json.versions); // after issue loading because of shared milestones
    //  -- RELATIONS --
    this._loadRelations(json.relations);

    ysy.log.debug("data loaded", "load");
    ysy.log.message("JSON loaded");
    this._fireChanges();
    ysy.history.clear();
    this.loaded = true;
  },
  _loadIssues: function (json, rootId) {
    if (!json) return;
    if (rootId) {
      if (this.issueIdListMap[rootId]) {
        json = ysy.data.loader.reorderArray(json, this.issueIdListMap[rootId]);
      }
      this.issueIdListMap[rootId] = json.map(function (item) {
        return item.id;
      });
    }
    var issues = ysy.data.issues;
    for (var i = 0; i < json.length; i++) {
      var issue = new ysy.data.Issue();
      issue.init(json[i]);
      issues.pushSilent(issue);
    }
    issues._fireChanges(this, "load");
  },
  _loadRelations: function (json) {
    if (!json) return;
    var relations = ysy.data.relations;
    var allowedTypes = {
      precedes: true,
      finish_to_finish: true,
      start_to_start: true,
      start_to_finish: true
    };
    for (var i = 0; i < json.length; i++) {
      // TODO enable other relation types
      if (allowedTypes[json[i].type]) {
        var rela = new ysy.data.Relation();
      } else {
        rela = new ysy.data.SimpleRelation();
      }
      rela.init(json[i]);
      relations.pushSilent(rela);
    }
    relations._fireChanges(this, "load");
  },
  _loadMilestones: function (json) {
    if (!json) return;
    var milestones = ysy.data.milestones;
    for (var i = 0; i < json.length; i++) {
      var mile = new ysy.data.Milestone();
      mile.init(json[i]);
      milestones.pushSilent(mile);

      var issues = mile.getIssues();
      var projectIds = {};
      for (var j = 0; j < issues.length; j++) {
        projectIds[issues[j].project_id] = true;
      }
      delete projectIds[mile.project_id];
      var sharedForIds = Object.getOwnPropertyNames(projectIds);
      if (sharedForIds.length === 0) continue;
      var realProjectId = json[i].project_id;
      var realProjectName = json[i].project_name;
      delete json[i].project_id;
      for (j = 0; j < sharedForIds.length; j++) {
        var sharedMile = new ysy.data.SharedMilestone();
        $.extend(sharedMile, {
          project_id: parseInt(sharedForIds[j]),
          real_project_id: realProjectId,
          real_project_name: realProjectName,
          real_milestone: milestones.getByID(mile.id)
        });
        sharedMile.init(json[i]);
        milestones.pushSilent(sharedMile);
      }
    }
    milestones._fireChanges(this, "load");
  },
  _loadProjects: function (json) {
    if (!json) return;
    var projects = ysy.data.projects;
    //var main_id = ysy.settings.projectID;
    for (var i = 0; i < json.length; i++) {
      //if (json[i].id === main_id) continue;
      var project = new ysy.data.Project();
      project.init(json[i]);
      projects.pushSilent(project);
    }
    projects._fireChanges(this, "load");
    var openings = ysy.data.limits.openings;
    for (var id in openings) {
      if (!openings.hasOwnProperty(id)) continue;
      if (ysy.main.startsWith(id, "p")) {
        var realId = id.substring(1);
        project = projects.getByID(realId);
        if (!project) continue;
        if (!project.needLoad) continue;
        project.needLoad = false;
        this.loadProject(realId);
      } else if (this.openIssuesOfProject && ysy.main.startsWith(id, "s")) {
        realId = id.substring(1);
        if (!openings["p" + realId]) continue;
        this.openIssuesOfProject(realId);
      }
    }
  },
  _loadHolidays: function (json) {
    if (!json) return;
    ysy.settings.holidays = json;
    ysy.view.initNonworkingDays();
  },
  loadProject: function () {
  }

});
if (!ysy.gateway) ysy.gateway = {};
$.extend(ysy.gateway, {
  loadGanttdata: function (callback, fail) {
    $.getJSON(ysy.settings.paths.mainGantt)
        .done(callback)
        .fail(fail);
  }
});
