/* dhtml_modif.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};
ysy.view.initGantt = function () {
  var toMomentFormat = function (rubyFormat) {
    switch (rubyFormat) {
      case '%Y-%m-%d':
        return 'YYYY-MM-DD';
      case '%Y/%m/%d':
        return 'YYYY/MM/DD';
      case '%d/%m/%Y':
        return 'DD/MM/YYYY';
      case '%d.%m.%Y':
        return 'DD.MM.YYYY';
      case '%d-%m-%Y':
        return 'DD-MM-YYYY';
      case '%m/%d/%Y':
        return 'MM/DD/YYYY';
      case '%d %b %Y':
        return 'DD MMM YYYY';
      case '%d %B %Y':
        return 'DD MMMM YYYY';
      case '%b %d, %Y':
        return 'MMM DD, YYYY';
      case '%B %d, %Y':
        return 'MMMM DD, YYYY';
      default:
        return 'D. M. YYYY';
    }
  };

  function getERUISassValue(varName, defaultValue) {
    if (window.ERUI && ERUI.sassData !== undefined && ERUI.sassData[varName] !== undefined) {
      return parseInt(ERUI.sassData[varName]);
    }
    return defaultValue;
  }

  $.extend(gantt.config, {
    //xml_date: "%Y-%m-%d",
    //scale_unit: "week",
    //date_scale: "Week #%W",
    //autosize:"y",
    details_on_dblclick: false,
    readonly_project: true,
    //autofit:true,
    drag_empty: true,
    work_time: true,
    //min_duration:24*60*60*1000, // 1*24*60*60*1000s = 1 day
    correct_work_time: true,
    //date_grid: "%j %M %Y",
    date_format: toMomentFormat(ysy.settings.dateFormat),
    date_grid: "%j.%n.%Y",
    links: {
      finish_to_start: "precedes",
      start_to_start: "start_to_start",
      start_to_finish: "start_to_finish",
      finish_to_finish: "finish_to_finish"
    },
    step: 1,
    duration_unit: "day",
    fit_tasks: true,
    row_height: getERUISassValue('gantt-row-height', 25),
    task_height: getERUISassValue('gantt-task-height', 20),
    min_column_width: 36,
    autosize: "y",
    link_line_width: 0,
    scale_height: 60,
    start_on_monday: true,
    order_branch: true,
    rearrange_branch: true,
    grid_resize: true,
    grid_width: ysy.data.limits.columnsWidth.grid_width,
    task_scroll_offset: 250,
    controls_task: {progress: true, resize: true, links: true},
    controls_milestone: {},
    start_date: ysy.data.limits.start_date,
    end_date: ysy.data.limits.end_date,
    controls_project: {show_progress: true, resize: false},
    allowedParent_task: ["project", "milestone", "empty"],
    allowedParent_task_global: ["project", "milestone"],
    allowedParent_milestone: ["project"],
    allowedParent_project: ["empty"]
  });
  gantt.config.columns = ysy.view.leftGrid.constructColumns(ysy.data.columns);
  ysy.proManager.fireEvent("ganttConfig", gantt.config);
  gantt._pull["empty"] = {
    type: "empty",
    id: "empty",
    $target: [],
    $source: [],
    columns: {},
    text: "",
    start_date: moment()
  };
};
ysy.view.applyGanttPatch = function () {
  ysy.view.leftGrid.patch();
  gantt.locale.date = ysy.settings.labels.date;
  $.extend(gantt.templates, {
    task_cell_class: function (item, date) {
      if (gantt.config.scale_unit === "day") {
        //var css="";
        if (moment(date).date() === 1) {
          return true;
          //  css+=" first-date";
        }
        //return css;
      }
      return false;
    },
    scale_cell_class: function (date) {
      if (gantt.config.scale_unit === "day") {
        var css = "";
        if (!gantt._working_time_helper.is_working_day(date)) {
          css += " weekend";
        }
        //if(date.getDate()===1){
        if (moment(date).date() === 1) {
          css += " first-date";
        }
        return css;
      }
    },
    task_text: function (start, end, task) {
      return "";
    },
    task_class: function (start, end, task) {
      var css = "";
      if (task.css) {
        css = task.css;
      }
      css += " " + (task.type || "task") + "-type";
      if (task.widget && task.widget.model) {
        var problems = task.widget.model.getProblems();
        if (problems) {
          css += " wrong";
        }
      }
      return css;
    },
    grid_row_class: function (start, end, task) {
      var ret = "";
      if (task.css) {
        ret = task.css;
      }
      if (task.widget && task.widget.model) {
        var problems = task.widget.model.getProblems();
        if (problems) {
          ret += " wrong";
        }
      }
      ret += " " + (task.type || "task") + "-type";
      return ret;//+'" data-url="/issues/'+task.id+' data-none="';
      //return task.css+" "+task.type+"-type";
    },
    /*grid_file: function (item) {
     return "";
     //return "<div class='gantt_tree_icon gantt_file'></div>";
     },*/
    link_class: function (link) {
      var css = "type-" + link.type;
      if (link.widget) {
        var relation = link.widget.model;
        if (relation) {
          if (!relation.checkDelay()) {
            css += " wrong";
          }
          if (relation.isSimple) {
            css += " gantt-relation-simple";
          }
          if (link.unlocked) {
            css += " gantt-relation-unlocked";
          }
        }
      }
      return css;
    },
    drag_link: function (from, from_start, to, to_start) {
      var labels = ysy.view.getLabel("links");
      if (!gantt._get_link_type(from_start, to_start)) {
        var reason = "unsupported_link_type";
      } else if (from === to) {
        reason = "loop_link";
      } else if (to && to.length > 12) {
        reason = "link_target_new";
      } else if (to && gantt.getTask(to).readonly) {
        reason = "link_target_readonly";
      } else {
        reason = "other";
      }
      var obj = {
        errorReason: ysy.view.getLabel("errors2")[reason],
        from: gantt.getTask(from).text
      };
      if (to) {
        obj.to = gantt.getTask(to).text;
        var ganttLinkType = (from_start ? "start" : "finish") + "_to_" + (to_start ? "start" : "finish");
        obj.type = labels[gantt.config.links[ganttLinkType]];
      }
      return Mustache.render(ysy.view.templates.linkDragModal, obj);
    },
    scale_row_class: function (scale) {
      return scale.className || "";
    }
  });

  gantt.attachEvent("onRowDragStart", function (id /*, elem*/) {
    //$(".gantt_grid_data").addClass("dragging");
    var task = gantt.getTask(id);
    $(".gantt_row").each(function () {
      var target = gantt._pull[$(this).attr("task_id")];
      if (!target) return;
      if (gantt.allowedParent(task, target)) {
        $(this).addClass("gantt_drag_to_allowed");
      }
    });
    return true;
  });
  gantt.attachEvent("onRowDragEnd", function (id, elem) {
    //$(".gantt_grid_data").removeClass("dragging");
    $(".gantt_drag_to_allowed").removeClass("gantt_drag_to_allowed");
  });

  // Funkce pro vytvoření a posunování Today markeru
  function initTodayMarker() {
    var date_to_str = gantt.date.date_to_str(gantt.config.task_date);
    var id = gantt.addMarker({start_date: new Date(), css: "today", title: date_to_str(new Date())});
    setInterval(function () {
      var today = gantt.getMarker(id);
      today.start_date = new Date();
      today.title = date_to_str(today.start_date);
      gantt.updateMarker(id);
    }, 1000 * 60 * 60);
  }

  initTodayMarker();

  //gantt.initProjectMarker=function initProjectMarker(start,end) {
  //    if(start&&start.isValid()){
  //        var startMarker = gantt.addMarker({start_date: start.toDate(), css: "start", title: "Project start"});
  //    }
  //    if(end&&end.isValid()){
  //        var endMarker = gantt.addMarker({start_date: end.toDate(), css: "end", title: "Project due time"});
  //    }
  //};
  //initProjectMarker();

//##################################################################################
  if (!ysy.settings.fixedRelations) {
    gantt.attachEvent("onLinkClick", function (id, mouseEvent) {
      if (!gantt.config.drag_links) return;
      ysy.log.debug("LinkClick on " + id, "link_config");
      var link = gantt.getLink(id);
      if (gantt._is_readonly(link)) return;
      var source = gantt._pull[link.source];
      if (!source) return;
      var target = gantt._pull[link.target];
      if (!target) return;
      if (source.readonly && target.readonly) return;

      var linkConfigWidget = new ysy.view.LinkPopup().init(link.widget.model, link);
      linkConfigWidget.$target = $("#ajax-modal");//$dialog;
      linkConfigWidget.repaint();
      showModal("ajax-modal", "auto");
      return false;
    });
  }
  gantt.attachEvent("onAfterLinkDelete", function (id, elem) {
    if (elem.deleted) return;
    if (!elem.widget.model._deleted) {
      elem.widget.model.remove();
    }
  });
  gantt.attachEvent("onBeforeLinkAdd", function (id, link) {
    if (link.widget) return true;
    var relations = ysy.data.relations;
    var data;
    data = {
      id: id,
      source_id: parseInt(link.source),
      target_id: parseInt(link.target),
      delay: 0,
      unlocked: true,
      permissions: {
        editable: true
      },
      type: link.type
    };
    var relArray = relations.getArray();
    for (var i = 0; i < relArray.length; i++) {
      var relation = relArray[i];
      if (relation.source_id === data.source_id && relation.target_id === data.target_id) {
        dhtmlx.message(ysy.view.getLabel("errors2", "duplicate_link"), "error");
        return false;
      }
    }
    var rel = new ysy.data.Relation();
    rel.init(data, relations);
    //rel.delay=rel.getActDelay();  // created link have maximal delay
    if (!gantt.checkLoopedLink(rel.getTarget(), rel.source_id)) {
      dhtmlx.message(ysy.view.getLabel("errors2", "loop_link"), "error");
      return false;
    }

    ysy.history.openBrack();
    relations.push(rel);
    var allRequests = {};
    rel.sendMoveRequest(allRequests);
    gantt.applyMoveRequests(allRequests);
    ysy.history.closeBrack();
    return false;
  });

  ysy.view.taskTooltip.taskTooltipInit();

  dhtmlx.message = function (msg, type, delay) {
    if (!type) {
      type = msg.type;
      msg = msg.text;
      delay = msg.delay;
    }
    window.showFlashMessage(type, msg, delay && delay > 0 ? delay : undefined);
    //if (type !== "notice") {
    //  var flashElement = $("#content").children(".flash")[0];
    //  var adjust = -10;
    //  if (ysy.settings.easyRedmine) {
    //    $(document).scrollTop(flashElement.offsetTop + adjust + "px");
    //    //window.scrollTo(".flash",adjust);
    //  } else {
    //    window.scrollTo(0, flashElement.offsetTop + adjust);
    //  }
    //}
  };

  if (!window.showFlashMessage) {
    window.showFlashMessage = function (type, message) {
      var $content = $("#content");
      $content.find(".flash").remove();
      var template = '<div class="flash {{type}}"><a href="javascript:void(0)" class="close-icon close_button" style="float:right"></a><span>{{{message}}}</span></div>';
      var closeFunction = function (event) {
        $(this)
            .closest('.flash')
            .fadeOut(500, function () {
              $(this).remove();
            })
      };
      var rendered = Mustache.render(template, {message: message, type: type});
      $content.prepend($(rendered));
      $content.find(".close_button").click(closeFunction);
    }
  }
  if (!dhtmlx.dragScroll) {
    dhtmlx.dragScroll = function () {
      var $background = $(".gantt_task_bg");
      if (!$background.hasClass("inited")) {
        $background.addClass("inited");
        var dnd = new dhtmlxDnD($background[0], {});
        var lastScroll = null;
        dnd.attachEvent("onDragStart", function () {
          lastScroll = gantt.getCachedScroll();
        });
        dnd.attachEvent("onDragMove", function () {
          var diff = dnd.getDiff();
          gantt.scrollTo(lastScroll.x - diff.x, undefined);
        });
      }
    };
  }
  gantt.attachEvent("onTaskOpened", function (id) {
    ysy.data.limits.openings[id] = true;
    var task = gantt._pull[id];
    if (!task || !task.widget) return true;
    var entity = task.widget.model;
    if (entity.needLoad) {
      entity.needLoad = false;
      ysy.data.loader.loadSubEntity(task.type, entity.id);
    }
  });
  gantt.attachEvent("onTaskClosed", function (id) {
    ysy.data.limits.openings[id] = false;
  });
  gantt.attachEvent("onTaskSelected", function (id) {
    var data = gantt._get_tasks_data();
    gantt._backgroundRenderer.render_items(data);
  });
  gantt.attachEvent("onTaskUnselected", function (id, ignore) {
    if (ignore) return;
    var data = gantt._get_tasks_data();
    gantt._backgroundRenderer.render_items(data);
  });
  gantt.attachEvent("onLinkValidation", function (link) {
    if (link.source.length > 12) return false;
    if (link.target.length > 12) return false;
    var source = gantt.getTask(link.source);
    var target = gantt.getTask(link.target);
    if (source.readonly && target.readonly) return false;
    var parentId = source.id;
    while (parentId !== 0) {
      var parent = gantt.getTask(parentId);
      if (parent === target) return false;
      parentId = parent.parent;
    }
    parentId = target.id;
    while (parentId !== 0) {
      parent = gantt.getTask(parentId);
      if (parent === source) return false;
      parentId = parent.parent;
    }
    return true;
  });
  gantt.attachEvent("onAfterTaskMove", function (sid, parent, tindex) {
    this.open(parent);
    return true;
  });
  gantt._filter_task = function (id, task) {
    // commented out because pushing task out of bounds removed the task and its project
    //var min = null, max = null;
    //if(this.config.start_date && this.config.end_date){
    //  min = this.config.start_date.valueOf();
    //  max = this.config.end_date.valueOf();
    //
    //  if(+task.start_date > max || +task.end_date < +min)
    //    return false;
    //}
    return ysy.proManager.eventFilterTask(id, task);
  };
  //var oldPosFromDate = gantt.posFromDate;
  //gantt.posFromDate = function(date){
  //  ysy.log.debug("old: "+oldPosFromDate.call(gantt,date)+" new: "+gantt.posFromDate2(date));
  //  return gantt.posFromDate2(date);
  //};
  gantt.posFromDate = function (date) {
    var scale = this._tasks;
    if (typeof date === "string") {
      date = moment(date);
    }

    var tdate = date.valueOf();
    var units = {
      day: 86400000, // 24 * 60 * 60 * 1000
      week: 604800000, // 7 * 24 * 60 * 60 * 1000
      //month: 2592000000  // 30 * 24 * 60 * 60 * 1000
      month: 2629800000,  // 30.4375 * 24 * 60 * 60 * 1000
      quarter: 7889400000,  // 3 * 30.4375 * 24 * 60 * 60 * 1000
      year: 31557600000  // 12 * 30.4375 * 24 * 60 * 60 * 1000
    };
    if (date._isEndDate) {
      tdate += units.day;
    }

    if (tdate <= this._min_date)
      return 0;

    if (tdate >= this._max_date)
      return scale.full_width;

    var unitRatio = (tdate - scale.trace_x[0]) / units[scale.unit];
    var index = Math.floor(unitRatio);
    index = Math.min(scale.count - 1, Math.max(0, index));
    if (scale.count === index + 1) {
      return scale.left[index]
          + scale.width[index]
          * (tdate - scale.trace_x[index])
          / (gantt._max_date - scale.trace_x[index]);
    }
    if (tdate > scale.trace_x[index + 1]) {
      index++;
      if (scale.count === index + 1) {
        return scale.left[index]
            + scale.width[index]
            * (tdate - scale.trace_x[index])
            / (gantt._max_date - scale.trace_x[index]);
      }
    } else {
      while (index !== 0 && tdate < scale.trace_x[index]) index--;
    }
    var restRatio = (tdate - scale.trace_x[index]) / (scale.trace_x[index + 1] - scale.trace_x[index]);
    return scale.left[index] + scale.width[index] * restRatio;
  };
  gantt.dateFromPos2 = function (x) {
    // TODO tasks ends
    var scale = this._tasks;
    if (x < 0 || x > scale.full_width || !scale.full_width) {
      scale.needRescale = true;
      ysy.log.debug("needRescale", "outer");
    }
    if (!scale.trace_x.length) {
      return 0;
    }
    // var units = {
    //   day: 86400000, // 24 * 60 * 60 * 1000
    //   week: 604800000, // 7 * 24 * 60 * 60 * 1000
    //   //month: 2592000000  // 30 * 24 * 60 * 60 * 1000
    //   month: 2629800000  // 30.4375 * 24 * 60 * 60 * 1000
    // };
    var unitRatio = x / (scale.full_width / scale.count);
    var index = Math.floor(unitRatio);
    index = Math.min(scale.count - 1, Math.max(0, index));
    if (index === scale.count - 1) {
      return gantt.date.Date(
          scale.trace_x[index].valueOf()
          + (gantt._max_date - scale.trace_x[index])
          * (x - scale.left[index])
          / scale.width[index]);
    }
    if (x > scale.left[index + 1]) {
      index++;
      if (index === scale.count - 1) {
        return gantt.date.Date(
            scale.trace_x[index].valueOf()
            + (gantt._max_date - scale.trace_x[index])
            * (x - scale.left[index])
            / scale.width[index]);
      }
    }
    return gantt.date.Date(
        scale.trace_x[index].valueOf()
        + (scale.trace_x[index + 1] - scale.trace_x[index])
        * (x - scale.left[index])
        / scale.width[index]);
  };
  ysy.view.bars.registerRenderer("task", function (task, next) {
    var $div = $(next().call(this, task, next));
    if (this.hasChild(task.id) || $div.hasClass("parent")) {
      $div.addClass("gantt_parent_task-subtype");
      var $ticks = $("<div class='gantt_task_ticks'></div>");
      var width = $div.width();
      if (width < 20) {
        $ticks.css({borderLeftWidth: width / 2, borderRightWidth: width / 2});
      }
      $div.append($ticks);


    }
    if (task.latest_due) {
      var stop_x = this.posFromDate(task.widget.model.latest_due);
      var issue_x = this.posFromDate(task.start_date);
      var pos_x = stop_x - issue_x;
      var $preStop = $(ysy.view.templates.endBlocker.replace("{{pos_x}}", pos_x.toString()));
      $div.prepend($preStop);
    }
    if (task.soonest_start) {
      var stop_x = this.posFromDate(task.widget.model.soonest_start);
      var issue_x = this.posFromDate(task.start_date);
      var pos_x = stop_x - issue_x;
      var $preStop = $(ysy.view.templates.preBlocker.replace("{{pos_x}}", pos_x.toString()));
      $div.prepend($preStop);
    }
    return $div[0];
  });
  // var progressRenderer = gantt._render_task_progress;
  // gantt._render_task_progress = function (task, element, maxWidth) {
  //   var width = progressRenderer.call(this, task, element, maxWidth);
  //   if (task.type !== "project") return width;
  //   var pos = gantt.posFromDate(task.start_date);
  //   var todayPos = gantt.posFromDate(moment());
  //   if (task.progress < 1 && pos + width < todayPos) {
  //     element.className += " gantt-project-overdue";
  //   }
  //   return width;
  // };
  gantt._default_task_date = function (item, parent_id) {
    return moment();
  };
  gantt.attachEvent("onScrollTo", function (x, y) {
    var renderer = gantt._backgroundRenderer;
    var needRender = renderer.isScrolledOut(x, y);
    if (needRender) {
      //ysy.log.debug("render_one_canvas on [" + x + "," + y + "]", "scrollRender");
      renderer.render_items();
    }
  });
  var ganttOffsetTop;
  $(document).add("#content").on("scroll", function (e) {
    if (!ganttOffsetTop) {
      if (!gantt.$task) return;
      ganttOffsetTop = $(gantt.$task).offset().top;
    }
    var scroll = $(this).scrollTop();
    gantt.scrollTo(undefined, scroll - ganttOffsetTop);
  });
  gantt.showTask = function (id) {
    var el = this.getTaskNode(id);
    if (!el) return;
    var left = Math.max(el.offsetLeft - this.config.task_scroll_offset, 0);
    var top = $(el).offset().top - 200;
    $(window).scrollTop(top);
    this.scrollTo(left, top);
  };
  gantt.getScrollState = function () {
    if (!this.$task || !this.$task_data) return null;
    return {x: this.$task.scrollLeft, y: $(window).scrollTop()};
  };
  gantt._path_builder.get_endpoint = function (link) {
    var types = gantt.config.links;
    var from_start = false, to_start = false;

    if (link.type == types.start_to_start) {
      from_start = to_start = true;
    } else if (link.type == types.finish_to_finish) {
      from_start = to_start = false;
    } else if (link.type == types.finish_to_start) {
      from_start = false;
      to_start = true;
    } else if (link.type == types.start_to_finish) {
      from_start = true;
      to_start = false;
    } else {
      dhtmlx.assert(false, "Invalid link type");
    }
    var source = gantt._pull[link.source];
    var target = gantt._pull[link.target];
    var sourceShift = 0, targetShift = 0;
    var fromMount = from_start ? source.$startMount : source.$endMount;
    var toMount = to_start ? target.$startMount : target.$endMount;
    if (fromMount.length > 1) {
      for (var i = 0; i < fromMount.length; i++) {
        if (link.id == fromMount[i]) break;
      }
      sourceShift = (i * 2) / (fromMount.length - 1) * 6 - 6;
    }
    if (toMount.length > 1) {
      for (i = 0; i < toMount.length; i++) {
        if (link.id == toMount[i]) break;
      }
      targetShift = (i * 2) / (toMount.length - 1) * 6 - 6;
    }
    var from = gantt._get_task_visible_pos(gantt._pull[link.source], from_start);
    var to = gantt._get_task_visible_pos(gantt._pull[link.target], to_start);

    return {
      x: from.x,
      e_x: to.x,
      y: from.y + sourceShift,
      e_y: to.y + targetShift
    };
  };
  gantt._sync_links = function () {
    for (var id in this._pull) {
      if (!this._pull.hasOwnProperty(id)) continue;
      var task = this._pull[id];
      task.$source = [];
      task.$target = [];
      task.$startMount = [];
      task.$endMount = [];
    }
    for (id in this._lpull) {
      if (!this._lpull.hasOwnProperty(id)) continue;
      var link = this._lpull[id];
      var types = gantt.config.links;
      if (this._pull[link.source]) {
        this._pull[link.source].$source.push(id);
        if (link.type == types.start_to_start || link.type == types.start_to_finish) {
          this._pull[link.source].$startMount.push(id);
        } else {
          this._pull[link.source].$endMount.push(id);
        }
      }
      if (this._pull[link.target]) {
        this._pull[link.target].$target.push(id);
        if (link.type == types.start_to_start || link.type == types.finish_to_start) {
          this._pull[link.target].$startMount.push(id);
        } else {
          this._pull[link.target].$endMount.push(id);
        }
      }
    }
  };
  gantt._has_children = function (id) {
    var item = gantt._pull[id];
    if (item.widget && item.widget.model && item.widget.model.needLoad) {
      return true;
    }
    return this.getChildren(id).length > 0;
  };
  gantt.setParent = function (task, new_pid) {
    if (ysy.settings.parentIssueDates) {
      var parentTask = this._pull[new_pid];
      if (parentTask && gantt._get_safe_type(parentTask.type) === "task") {
        parentTask.$no_start = true;
        parentTask.$no_end = true;
      }
    }
    task.parent = new_pid;
  };
  gantt.attachEvent("onAfterTaskMove", function (taskId) {
    var task = gantt._pull[taskId];
    if (!task) return;
    task._parentChanged = true;
  });
  $("#main").on("resize", function () {
    gantt.render();
  });
};
