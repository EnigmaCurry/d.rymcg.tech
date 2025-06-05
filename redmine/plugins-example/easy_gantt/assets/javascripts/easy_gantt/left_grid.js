/* left_grid.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.view = ysy.view || {};
ysy.view.leftGrid = ysy.view.leftGrid || {};
$.extend(ysy.view.leftGrid, {
  columnsWidth: {
    id: 60,
    subject: 200,
    name: 200,
    project: 140,
    other: 70,
    updated_on: 85,
    assigned_to: 100,
    grid_width: 400
  },
  patch: function () {
    ysy.data.limits.columnsWidth = $.extend({}, this.columnsWidth);
    ysy.view.columnBuilders = ysy.view.columnBuilders || {};
    $.extend(ysy.view.columnBuilders, {
      id: function (obj) {
        if (obj.id > 1000000000000) return '';
        var path = ysy.settings.paths.rootPath + "issues/";
        return "<a href='" + path + obj.id + "' title='" + ysy.main.escapeText(obj.text) + "' target='_blank'>#" + obj.id + "</a>";
      },
      updated_on: function (obj) {
        if (!obj.columns)return "";
        var value = obj.columns.updated_on;
        if (value) {
          return moment.utc(value, 'YYYY-MM-DD HH:mm:ss ZZ').fromNow();
        } else {
          return "";
        }
      },
      done_ratio: function (obj) {
        if (!obj.columns)return "";
        //return '<span class="multieditable">'+Math.round(obj.progress*10)*10+'</span>';
        return '<span >' + Math.round(obj.progress * 10) * 10 + '</span>';
      },
      estimated_hours: function (obj) {
        if (!obj.columns)return "";
        return '<span >' + obj.estimated + '</span>';
      },
      subject: function (obj) {
        var id = parseInt(obj.real_id);
        var text = ysy.main.escapeText(obj.text);
        if (isNaN(id) || id > 1000000000000) return text;
        var path = ysy.settings.paths.rootPath + "issues/";
        if (obj.type === "milestone") {
          path = ysy.settings.paths.rootPath + "versions/"
        } else if (obj.type === "project") {
          path = ysy.settings.paths.rootPath + "projects/"
        } else if (obj.type === "assignee") {
          if (obj.subtype === "group") {
            path = ysy.settings.paths.rootPath + "groups/"
          } else {
            path = ysy.settings.paths.rootPath + "users/"
          }
        }
        return "<a href='" + path + id + "' title='" + text + "' target='_blank'>" + text + "</a>";
      },
      _default: function (col) {
        return function (obj) {
          if (!obj.columns) return "";
          if (col.dont_escape) return obj.columns[col.name];
          return ysy.main.escapeText(obj.columns[col.name] || "");
        };
      }

    });
    gantt._render_grid_superitem = function (item) {
      var subjectColumn = ysy.view.columnBuilders.subject;

      var tree = "";
      for (var j = 0; j < item.$level; j++)
        tree += this.templates.grid_indent(item);
      var has_child = this._has_children(item.id);
      if (has_child) {
        tree += this.templates.grid_open(item);
        tree += this.templates.grid_folder(item);
      } else {
        tree += this.templates.grid_blank(item);
        tree += this.templates.grid_file(item);
      }
      var afterText = this.templates.superitem_after_text(item, has_child);

      var odd = item.$index % 2 === 0;
      var style = "";//"width:" + (col.width - (last ? 1 : 0)) + "px;";
      var cell = "<div class='gantt_grid_superitem' style='" + style + "'>" + tree + subjectColumn(item) + afterText + "</div>";

      var css = odd ? " odd" : "";
      if (this.templates.grid_row_class) {
        var css_template = this.templates.grid_row_class.call(this, item.start_date, item.end_date, item);
        if (css_template)
          css += " " + css_template;
      }

      if (this.getState().selected_task == item.id) {
        css += " gantt_selected";
      }
      var el = document.createElement("div");
      el.className = "gantt_row" + css;
      //el.setAttribute("data-url","/issues/"+item.id+".json");  // HOSEK
      el.style.height = this.config.row_height + "px";
      el.style.lineHeight = (gantt.config.row_height) + "px";
      el.setAttribute(this.config.task_attribute, item.id);
      el.innerHTML = cell;
      return el;
    };
    $.extend(gantt.templates, {
      grid_open:function(item) {
        return "<div class='gantt_tree_icon gantt_" + (item.$open ? "close" : "open") + " easy-gantt__icon easy-gantt__icon--" + (item.$open ? "close" : "open") + "'></div>";
      },
      grid_folder: function (item) {
        /// = HAS CHILDREN
        if (this["grid_bullet_" + gantt._get_safe_type(item.type)]) {
          return this["grid_bullet_" + gantt._get_safe_type(item.type)](item, true);
        }
        // default fallback
        if (item.$open || gantt._get_safe_type(item.type) !== gantt.config.types.task) {
          return "<div class='gantt_tree_icon gantt_folder_" + (item.$open ? "open" : "closed") + "'></div>";
        } else {
          return "<div class='gantt_tree_icon'><div class='gantt_drag_handle gantt_subtask_arrow'></div></div>";
        }
      },
      grid_file: function (item) {
        // = HAS NO CHILDREN
        if (this["grid_bullet_" + gantt._get_safe_type(item.type)]) {
          return this["grid_bullet_" + gantt._get_safe_type(item.type)](item, false);
        }
        // default fallback
        if (gantt._get_safe_type(item.type) === gantt.config.types.task)
          return "<div class='gantt_tree_icon'><div class='gantt_drag_handle gantt_subtask_arrow'></div></div>";
        return "<div class='gantt_tree_icon gantt_folder_open'></div>";
      },
      grid_bullet_milestone: function (item, has_children) {
        var rearrangable = false;
        return "<div class='gantt_tree_icon " + (rearrangable ? "gantt_drag_handle" : "") + "'>" +
            "<div class='gantt-milestone-icon gantt-grid-milestone-bullet" + (rearrangable ? " gantt-bullet-hover-hide" : "") + "'></div></div>";
      },
      grid_bullet_project: function (item, has_children) {
        if (item.$open || !has_children) {
          return "<div class='gantt_tree_icon gantt_folder_open'></div>";
        } else {
          return "<div class='gantt_tree_icon gantt_folder_closed'></div>";
        }
      },
      grid_bullet_task: function (item, has_children) {
        if (has_children) {
          return "<div class='gantt_tree_icon gantt_drag_handle gantt_folder_" + (item.$open ? "open" : "closed") + "'></div>";
        } else {
          return "<div class='gantt_tree_icon'><div class='gantt_drag_handle gantt_subtask_arrow'></div></div>";
        }
      },
      superitem_after_text: function (item, has_children) {
        if (this["superitem_after_" + gantt._get_safe_type(item.type)]) {
          return this["superitem_after_" + gantt._get_safe_type(item.type)](item, has_children);
        }
        return "";
      }
    });
    gantt._render_grid_header = function () {
      var columns = this.getGridColumns();
      var cells = [];
      var width = 0,
          labels = this.locale.labels;

      var lineHeigth = this.config.scale_height - 2;
      var resizes = [];

      for (var i = 0; i < columns.length; i++) {
        var last = i === columns.length - 1;
        var col = columns[i];
        if (last && this._get_grid_width() > width + col.width)
          col.width = this._get_grid_width() - width;
        width += col.width;
        var sort = (this._sort && col.name === this._sort.name) ? ("<div class='gantt_sort gantt_" + this._sort.direction + "'></div>") : "";
        if (col.tree) {
          if (!this._sort) sort = '<div class="gantt_sort gantt_none"></div>';
          if (ysy.pro.collapsor) {
            sort += ysy.pro.collapsor.templateHtml;
          }
        }
        var cssClass = ["gantt_grid_head_cell",
          ("gantt_grid_head_" + col.name),
          (last ? "gantt_last_cell" : ""),
          this.templates.grid_header_class(col.name, col)].join(" ");

        var style = "width:" + (col.width - (last ? 1 : 0)) + "px;";
        var label = (col.label || labels["column_" + col.name]);
        label = label || "";
        var cell = "<div class='" + cssClass + "' style='" + style + "' column_id='" + col.name + "'><div class='gantt-grid-header-multi'>" + label + sort + "</div></div>";
        if (!last) {
          resizes.push("<div style='left:" + (width - 6) + "px' class='gantt_grid_column_resize_wrap' data-column_id='" + col.name + "'></div>");
        }
        cells.push(cell);
        //var resize='<div style="height:100%;background-color:red;width:10px;cursor: col-resize;position: absolute;left:'+(width-5)+'px;z-index:1"></div>';
        /*var resize = '<div class="gantt_grid_column_resize_wrap" style="height:100%;left:' + (width - 7) + 'px;z-index:1" column-index="' + i + '">\
         <div class="gantt_grid_column_resize"></div></div>';
         resizes.push(resize);*/
      }
      //var resize = '<div class="gantt_grid_column_resize_wrap" style="height:100%;left:' + (this._get_grid_width() - 10) + 'px;z-index:1" >\
      //<div class="gantt_grid_column_resize"></div></div>';
      this.$grid_resize.style.left = (this._get_grid_width() - 6) + "px";
      this.$grid_scale.style.height = (this.config.scale_height - 1) + "px";
      this.$grid_scale.style.lineHeight = lineHeigth + "px";
      this.$grid_scale.style.width = (width - 1) + "px";
      this.$grid_scale.style.position = "relative";
      this.$grid_scale.innerHTML = cells.join("") + resizes.join("");
      ysy.view.leftGrid.resizeTable();
      if (ysy.view.collapsors) {
        ysy.view.collapsors.requestRepaint();
      }
      //resizeColumns();
    };
    gantt._calc_grid_width = function () {
      var i;
      var columns = this.getGridColumns();
      var cols_width = 0;
      var width = [];

      for (i = 0; i < columns.length; i++) {
        var v = parseInt(columns[i].min_width, 10);
        width[i] = v;
        cols_width += v;
      }

      var diff = this._get_grid_width() - cols_width;
      if (this.config.autofit || diff > 0) {
        var delta = Math.ceil(diff / (columns.length ? columns.length : 1));
        //var ratio=1+diff/(cols_width?cols_width:1);
        for (i = 0; i < width.length; i++) {
          columns[i].width = columns[i].min_width + delta;//*ratio;
        }
      } else {
        for (i = 0; i < columns.length; i++) {
          columns[i].width = columns[i].min_width;
        }
        //this.config.grid_width = cols_width;
      }
    };
  },
  constructColumns: function (columns) {
    var dcolumns = [];
    var columnBuilders = ysy.view.columnBuilders;
    var getBuilder = function (col) {
      if (columnBuilders[col.name]) {
        return columnBuilders[col.name];
      } else if (columnBuilders[col.name + "Builder"]) {
        return columnBuilders[col.name + "Builder"](col);
      }
      else return columnBuilders._default(col);
    };
    for (var i = 0; i < columns.length; i++) {
      var col = columns[i];
      var isMainColumn = col.name === "subject" || col.name === "name";
      if (col.name === "id" && !ysy.settings.easyRedmine) continue;
      var css = "gantt_grid_body_" + col.name;
      if (col.name !== "") {
        var width = ysy.data.limits.columnsWidth[col.name] || ysy.data.limits.columnsWidth["other"];
        var dcolumn = {
          name: col.name,
          label: col.title,
          min_width: width,
          width: width,
          tree: isMainColumn,
          align: isMainColumn ? "left" : "center",
          template: getBuilder(col),
          css: css
        };
        if (isMainColumn) {
          dcolumns.unshift(dcolumn);
        } else {
          dcolumns.push(dcolumn);
        }
      }
    }
    return dcolumns;
  },
  resizeTable: function () {
    var $resizes = $(".gantt_grid_column_resize_wrap:not(inited)");
    var colWidths = ysy.data.limits.columnsWidth;
    var $gantt_grid = $(".gantt_grid");
    var $gantt_grid_data = $(".gantt_grid_data");
    var $gantt_grid_scale = $(".gantt_grid_scale");
    $resizes.each(function (index, el) {
      var config = {};
      var $el = $(el);
      var column = $el.data("column_id");
      var dhtmlxDrag = new dhtmlxDnD(el, config);
      var minWidth,
          realWidth,
          resizePos,
          gridWidth;
      dhtmlxDrag.attachEvent("onDragStart", function () {
        if (this.config.started) return;
        minWidth = colWidths[column] || colWidths.other;
        realWidth = $gantt_grid.find(".gantt_grid_head_" + column).width();
        gridWidth = $gantt_grid.width();
        resizePos = $el.offset();
      });
      dhtmlxDrag.attachEvent("onDragMove", function (target, event) {
        //var diff=Math.floor(event.pageX-lastPos);
        var diff = Math.floor(dhtmlxDrag.getDiff().x);
        ysy.log.debug("moveDrag diff=" + diff + "px width=" + realWidth + "px", "grid_resize");

        $gantt_grid.width(gridWidth + diff);
        $gantt_grid_data.width(gridWidth + diff);
        $gantt_grid_scale.width(gridWidth + diff);
        $el.offset({top: resizePos.top, left: resizePos.left + diff});
        colWidths[column] = minWidth + diff;
        var columns = gantt.config.columns;
        if (index < columns.length - 1) {
          gantt.config.columns[index].min_width = minWidth + diff;
          gantt.config.columns[index].width = realWidth + diff + 1;
          $gantt_grid.find(".gantt_grid_head_" + column + ", .gantt_grid_body_" + column).width(realWidth + diff + "px");
        }
        gantt.config.grid_width = gridWidth + diff;
        colWidths.grid_width = gridWidth + diff;
      });
      dhtmlxDrag.attachEvent("onDragEnd", function (target, event) {
        gantt.render();
        //gantt._render_grid();
        //var data = gantt._get_tasks_data();
        //gantt._gridRenderer.render_items(data);
        //ysy.view.ganttTasks.requestRepaint();
      });
    });
    $resizes.addClass("inited");
  }
});
