/* background.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};
ysy.view.getGanttBackground = function () {
  var colors = ysy.settings.styles.backgrounds;

  function getBackgroundColor() {
    var defaultColor = "rgba(200, 200, 200, 0.25)";
    if (!window.getComputedStyle) return defaultColor;
    var styles = window.getComputedStyle(document.getElementsByTagName('body')[0]);
    var colorString = styles.getPropertyValue('background-color') || "";
    if (!colorString.match(/rgba?\([0-9, ]+\)/)) return defaultColor;
    var colorSplit = colorString.replace(/^rgba?\(|\s+|\)$/g,'').split(',');
    var colorArray = [parseInt(colorSplit[0]), parseInt(colorSplit[1]), parseInt(colorSplit[2])];
    var strongColorArray = [];
    var stronger = 3;
    for (var i = 0; i < 3; i++) {
      var component = colorArray[i];
      if (component > 255 * (stronger - 1) / stronger) {
        strongColorArray.push(255 - (255 - component) * stronger);
      } else {
        strongColorArray.push(Math.floor(component / stronger));
      }
    }
    return "rgba(" + strongColorArray.join(", ") + ", 0.15)";
  }

  var backgroundColor = getBackgroundColor();
  return {
    fullCanvasRender: false,
    container: gantt.$task_bg,
    renderer: true,
    filter: gantt._create_filter(['_filter_task', '_is_chart_visible', '_is_std_background']),
    lastItems: null,
    lastPos: null,
    svg: null,
    lastElements: {},
    _render_bg_canvas: function (svg, items, limits) {
      var rowHeight = gantt.config.row_height;
      var cfg = gantt._tasks;
      var widths = cfg.width;
      var fullHeight = rowHeight * (limits.toY - limits.fromY);
      var fullWidth = 0;
      var width;
      var partWidth;
      for (var i = limits.fromX; i < limits.toX; i++) {
        fullWidth += widths[i];
      }
      svg.size(fullWidth, fullHeight);
      svg.node.style.left = cfg.left[limits.fromX] + "px";
      svg.node.style.top = rowHeight * limits.fromY + "px";
      //  -- CLEARING --
      svg.clear();
      //  -- SELECTED --
      for (i = limits.fromY; i < limits.toY; i++) {
        if (gantt.getState().selected_task == items[i].id) {
          svg.rect(fullWidth, rowHeight).x(0).y((i - limits.fromY) * rowHeight).attr('fill', colors.selected);
          break;
        }
      }
      //  -- HORIZONTAL LINES --
      var commands = [];
      var lineCmd = "l " + fullWidth + " 0";
      for (i = 1; i <= limits.toY - limits.fromY; i++) {
        commands.push("M 0 " + (i * rowHeight - 0.5));
        commands.push(lineCmd);
      }
      //  -- VERTICAL LINES --
      partWidth = -0.5;
      lineCmd = "l 0 " + fullHeight;
      for (i = limits.fromX; i < limits.toX; i++) {
        width = widths[i];
        if (width <= 0) continue; //do not render skipped columns
        partWidth += width;
        commands.push("M " + partWidth + " 0");
        commands.push(lineCmd);
      }
      svg.path(commands.join("")).attr("stroke", colors.line);

      if (gantt.config.scale_unit === "day") {
        var weekendGroup = svg.group().attr('fill', backgroundColor);
        if (ysy.settings.resource.open) {
          //  -- USER WEEKENDS BACKGROUND --
          partWidth = 0;

          for (i = limits.fromX; i < limits.toX; i++) {
            width = widths[i];
            var top = 0;
            var mDate = moment(cfg.trace_x[i]);
            var iDate = mDate.format("YYYY-MM-DD");
            var lastWeekend = false;
            var firstEntity = items[limits.fromY];
            if (firstEntity.type !== "assignee") {
              var assignee = ysy.data.assignees.getByID(firstEntity.widget.model.assigned_to_id || "unassigned");
              if (assignee) {
                lastWeekend = assignee.getMaxHours(iDate, mDate) === 0;
              }
            }
            for (var j = limits.fromY; j < limits.toY; j++) {
              if (items[j].type !== "assignee") continue;
              var hours = items[j].widget.model.getMaxHours(iDate, mDate);
              if ((hours === 0) === lastWeekend) continue;
              if (lastWeekend) {
                weekendGroup.rect(width, (j - limits.fromY) * rowHeight - top).x(partWidth).y(top);
              } else {
                top = (j - limits.fromY) * rowHeight;
              }
              lastWeekend = !lastWeekend;
            }
            if (lastWeekend) {
              weekendGroup.rect(width, (limits.toY + 1) * rowHeight).x(partWidth).y(top);
            }
            partWidth += width;
          }
        } else {
          //  -- WEEKENDS BACKGROUND --
          if (!cfg.weekends) {
            cfg.weekends = [];
            for (var d = 0; d < cfg.trace_x.length; d++) {
              cfg.weekends.push(!gantt._working_time_helper.is_working_day(cfg.trace_x[d]));
            }
          }
          partWidth = 0;
          for (i = limits.fromX; i < limits.toX; i++) {
            width = widths[i];
            if (cfg.weekends[i]) {
              weekendGroup.rect(width, fullHeight).x(partWidth);
            }
            partWidth += width;
          }

        }
      }
      if (ysy.settings.resource.open) {
        //  -- ASSIGNEE BACKGROUND --
        var assigneeGroup = svg.group().attr('fill', backgroundColor);
        for (i = limits.fromY; i < limits.toY; i++) {
          if (items[i].type === "assignee") {
            assigneeGroup.rect(fullWidth, rowHeight).y((i - limits.fromY) * rowHeight);
          }
        }
        //  -- DARK LIMITS --
        var darkLimitGroup = svg.group().attr('fill', backgroundColor.replace("0.2)", "0.3)"));
        var ganttLimits = ysy.data.limits;
        if (ganttLimits.start_date) {
          var left = gantt.posFromDate(ganttLimits.start_date) - gantt.posFromDate(cfg.trace_x[limits.fromX]);
          if (left > 0) {
            darkLimitGroup.rect(left, fullHeight);
          }
        }
        if (ganttLimits.end_date) {
          var right = gantt.posFromDate(ganttLimits.end_date) - gantt.posFromDate(cfg.trace_x[limits.fromX]);
          if (right > 0 && right < fullWidth) {
            darkLimitGroup.rect(fullWidth - right, fullHeight).x(right);
          }
        }
      }
      //  -- BLUE LINE --
      if (gantt.config.scale_unit === "day") {
        partWidth = -0.5;
        commands = [];
        lineCmd = "l 0 " + fullHeight;
        for (i = limits.fromX; i < limits.toX; i++) {
          width = cfg.width[i];
          var first = moment(cfg.trace_x[i]).date() === 1;
          if (first) {
            commands.push("M " + partWidth + " 0");
            commands.push(lineCmd);
          }
          partWidth += width;
        }
        svg.path(commands.join("")).attr("stroke", colors.line_month);
      }
    },
    render_bg_line: function (canvas, index, item) {

    },
    render_item: function (item, container) {
      ysy.log.debug("render_item BG", "canvas_bg");
    },
    render_items: function (items, container) {
      ysy.log.debug("render_items FULL BG", "canvas_bg");
      container = container || this.node;
      if (items) {
        this.lastItems = items;
      } else {
        items = this.lastItems;
        if (!items) return;
      }
      if (this.fullCanvasRender) {
        this.render_full_svg(items, container);
      } else {
        this.render_shrunken_svg(items, container);
      }
      var fullHeight = gantt.config.row_height * items.length;
      container.style.height = fullHeight + "px";
      var lastEvent;
      $(container)
          .off("mousedown.bg")
          .on("mousedown.bg", function (e) {
            lastEvent = e;
          })
          .off("click.bg")
          .on("click.bg", function (e) {
            if (!lastEvent) return;
            if (Math.abs(lastEvent.pageX - e.pageX) > 2 || Math.abs(lastEvent.pageY - e.pageY) > 2) return;
            var order = gantt._order;
            var offsetTop = $(container).offset().top;
            var index = Math.floor((e.pageY - offsetTop) / gantt.config.row_height);
            if (index < 0 || index >= order.length) return;
            var taskId = order[index];
            if (!gantt.isTaskExists(taskId)) return;
            if (gantt._selected_task == taskId) {
              gantt.unselectTask();
            } else {
              gantt.selectTask(taskId);
            }
          })
    },
    render_shrunken_svg: function (items, container) {
      var cfg = gantt._tasks;
      var scrollPos = gantt.getCachedScroll();
      // var nodeWidth = this.node.innerWidth;
      // if(scrollPos.x > Math.max(nodeWidth - window.innerWidth, 0)){
      //   scrollPos.x = gantt.$task.scrollLeft;
      // }
      this.lastPos = scrollPos;
      //ysy.log.debug("render_one_canvas ["+scrollPos.x+","+scrollPos.y+"]","canvas_bg");
      var rowHeight = gantt.config.row_height;
      var colWidth = cfg.col_width;
      var countX = cfg.count;
      var countY = items.length;
      var limits = this.getCanvasLimits();
      var partCountX = Math.ceil(limits.x / colWidth),
          partCountY = Math.ceil(limits.y / rowHeight);
      var startX = Math.max(scrollPos.x - (limits.x - window.innerWidth) / 2, 0);
      var startY = Math.max(scrollPos.y - (limits.y - window.innerHeight) / 2, 0);
      var startCountX = Math.floor(startX / colWidth);
      var startCountY = Math.floor(startY / rowHeight);
      if (startCountX + partCountX > countX) {
        startCountX = countX - partCountX;
      }
      if (startCountY + partCountY > countY) {
        startCountY = countY - partCountY;
      }
      var svg = this.svg;
      if (!svg) {
        svg = this._createSvg(container);
      }
      this._render_bg_canvas(svg, items, {
        fromX: Math.max(startCountX, 0),
        toX: startCountX + partCountX,
        fromY: Math.max(startCountY, 0),
        toY: startCountY + partCountY
      });
    },
    render_full_svg: function (items, container) {
      ysy.log.debug("render_items FULL BG", "canvas_bg");
      var cfg = gantt._tasks;
      var countX = cfg.count;
      var countY = items.length;
      var svg = this.svg;
      if (!svg) {
        svg = this._createSvg(container);
      }
      this._render_bg_canvas(svg, items, {
        fromX: 0,
        toX: countX,
        fromY: 0,
        toY: countY
      });
    },
    _createSvg: function (container) {
      var svg = SVG(container);
      $(svg.node).css({position: "absolute"});
      this.svg = svg;
      return svg;
    },
    switchFullRender: function (fullRender) {
      if (this.fullCanvasRender === fullRender) return;
      this.fullCanvasRender = fullRender;
      this.render_items();
    },
    isScrolledOut: function (x, y) {
      if (this.fullCanvasRender) return false;
      if (this.forceRender) return true;
      var lastPos = this.lastPos;
      if (!lastPos) return true;
      var limits = this.getCanvasLimits();
      if (x !== undefined) {
        var bufferX = (limits.x - window.innerWidth) / 2;
        if (Math.abs(x - lastPos.x) > bufferX) return true;
      }
      if (y !== undefined) {
        var bufferY = (limits.y - window.innerHeight) / 2;
        if (Math.abs(y - lastPos.y) > bufferY) return true;
      }
    },
    getCanvasLimits: function () {
      return {x: window.innerWidth + 600, y: window.innerHeight + 600};
    }
  };
};
