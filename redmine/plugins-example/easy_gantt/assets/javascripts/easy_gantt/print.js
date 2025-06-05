/* print.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.print = {
  printPrepared: false,
  printPreparing: false,
  patch: function () {
    var self = this;
    var mediaQueryList = window.matchMedia('print');
    mediaQueryList.addListener(function (mql) {
      if (mql.matches) {
        // self.beforePrint();
      } else {
        self.afterPrint();
      }
    });
    // window.onbeforeprint = $.proxy(this.beforePrint, this);
    window.onafterprint = $.proxy(this.afterPrint, this);

    window.easyModel = window.easyModel || {};
    window.easyModel.print = window.easyModel.print || {};
    window.easyModel.print.functions = window.easyModel.print.functions || [];

    window.easyModel.print.functions.push(this.printToTemplate);
  },
  directPrint: function (buttonWidget) {
    var self = this;
    self.printPreparing = true;
    buttonWidget.forceRepaint();
    setTimeout(function () {
      self.beforePrint();
      self.printPreparing = false;
      buttonWidget.forceRepaint();
      window.print();
      // self.afterPrint();
    }, 30);
  },
  beforePrint: function (stripWidth) {
    var self = ysy.pro.print;
    if (self.printPrepared) return;
    var $wrapper2 = $("#wrapper2");
    var $wrapper3 = $("#wrapper3");
    if (ysy.view.affix.setPosition) {
      ysy.view.affix.setPosition(0);
    }
    $("#print_area").remove();
    var $print = $('<div id="print_area" class="' + (ysy.settings.easyRedmine ? "easy" : "redmine") + ' gantt-print__area"></div>');

    // if (ysy.settings.project) {
    //   var headerText = '<h1 class="gantt-print__header-header gantt-print__header-project">' + ysy.settings.project.name + '</h1>'
    //       + '<h2 class="gantt-print__header-header gantt-print__header-plugin">&nbsp;- '
    //       + (ysy.settings.resource.open ? ysy.settings.labels.titles.title_rm : ysy.settings.labels.titles.easyGantt)
    //       + '</h2>';
    // } else {
    //   headerText = '<h1 class="gantt-print__header-header gantt-print__header-plugin">'
    //       + (ysy.settings.resource.open ? ysy.settings.labels.titles.title_rm : ysy.settings.labels.titles.easyGantt)
    //       + '</h1>';
    // }
    // var $headerCont = $('<div class="gantt-print__header-cont"></div>');
    // $headerCont.html(headerText);

    var $gantt = $('<div class="gantt-print__gantt"></div>');
    $print.append($gantt);
    var fullWidth = gantt._tasks.full_width;
    stripWidth = stripWidth || 490;
    var $grid = self.cloneGrid();
    // $print.prepend($headerCont);
    $gantt.append($grid);
    var gridWidth = $grid.outerWidth();
    for (var p = -gridWidth; p < fullWidth; p += stripWidth) {
      $gantt.append(self.createStrip(p < 0 ? 0 : p, Math.min(p + stripWidth, fullWidth)));
      //p -= 2;
    }
    // $(".gantt-print__strip, .gantt-print__grid").css("margin-top", $headerCont.height() + 5);
    $wrapper3.hide();
    $(".gantt_hor_scroll").hide();
    $wrapper2.append($print);
    $("body").addClass("gantt-print__body");
    self.printPrepared = true;

  },
  afterPrint: function () {
    setTimeout(function () {
      if (!ysy.pro.print.printPrepared) return;
      $("body").removeClass("gantt-print__body");
      $("#print_area").remove();

      $("#wrapper3").show();
      $("#content, #sidebar").removeClass("fake-responsive");

      gantt._scroll_resize();
      ysy.pro.print.printPrepared = false;
    }, 100);
  },
  printToTemplate: function () {
    var printFit = $("#easy_gantt_print_fit_checkbox").is(":checked");
    ysy.pro.print.beforePrint(printFit ? Infinity : undefined);

    var width = $(".gantt_container").width();
    var content = $("#print_area").html() + ysy.view.templates.printIncludes;
    // TODO  add easy_gantt_pro.css
    // TODO  add easy_gantt_resources.css

    if (printFit) {
      content = '<div class="easy-print-page-fitting gantt-print__template--nowrap">' + content + '</div>';
    }

    // window.easyModel.print.tokens['easy_gantt_current_base64'] = $.base64.encode(content);
    window.easyModel.print.tokens['easy_gantt_current'] = content;
    window.easyModel.print.setWidth(width);
    ysy.pro.print.afterPrint();
  },
  cloneGrid: function () {
    var $gantt_cont = $("#gantt_cont");
    var $grid = $gantt_cont.find(".gantt_grid").clone().addClass("gantt-print__grid");
    $grid.find("a").each(function () {
      var $this = $(this);
      $this.parent().append('<span class="' + this.className + '">' + $this.text() + '</span>');
      $this.remove();
    });
    var $gridScale = $grid.find(".gantt_grid_scale");
    $gridScale.css({height: $gridScale.height() + 1 + "px", transform: "none"});
    return $grid;
  },
  createStrip: function (start, end) {
    if (end <= start) return null;
    var $gantt_cont = $("#gantt_cont");
    var $gantt_task = $gantt_cont.find(".gantt_task");
    var $strip = $('<div class="gantt-print__strip" style="width:' + (end - start) + 'px"></div>');
    // SCALE LINE
    $strip.append(this.cloneScales($gantt_task, start, end));

    // DATA AREA
    var $gantt_data_area = $gantt_cont.find(".gantt_data_area");
    var $data = $('<div class="gantt_data_area"></div>').css({
      height: $gantt_data_area.height() + "px",
      width: (end - start) + "px"
    });
    // BACKGROUND
    $data.append(this.cloneSvgBackground($gantt_data_area, start, end));

    // TASKS
    $data.append(this.cloneTasks($gantt_data_area, start, end));
    // LINKS
    $data.append(this.cloneLinks($gantt_data_area, start, end));

    $strip.append($data);

    return $strip;
  },
  cloneScales: function ($source, start, end) {
    var $scale = $(
        '<div class="gantt_task_scale gantt-print__scale"></div>');
    var lines = $source.find(".gantt_scale_line");
    for (var l = 0; l < lines.length; l++) {
      var oldLine = $(lines[l]);
      var cells = oldLine.find(".gantt_scale_cell");
      var $line = $('<div class="gantt_scale_line gantt-print__scale-line"></div>');
      $line[0].style.height = lines[l].style.height;
      $line[0].style.lineHeight = lines[l].style.lineHeight;
      //$line.style.height=oldLine.style.height;
      //$line.style.lineHeight=oldLine.style.lineHeight;
      //$line.height(oldLine.height());
      var leftPointer = 0;
      var first = false;
      for (var i = 0; i < cells.length; i++) {
        var oldCell = $(cells[i]);
        var width = oldCell.outerWidth();
        if (leftPointer < end && leftPointer + width > start) {
          var $cell = oldCell.clone();
          $line.append($cell);
          if (first === false) {
            first = true;
            $cell.css("margin-left", (leftPointer - start) + "px");
          }
        }
        leftPointer += width;
      }
      $line.width(leftPointer);

      $scale.append($line);
    }
    return $scale;
  },
  cloneSvgBackground: function ($source, startX, endX) {
    var $background = $('<div class="gantt_task_bg gantt-print__bg" style="width:' + (endX - startX) + 'px"></div>');
    var svg = SVG($background[0]);
    $(svg.node).css({position: "absolute"});
    var itemIds = gantt._order;
    var items = itemIds.map(function (itemId) {
      return gantt._pull[itemId];
    });


    var cfg = gantt._tasks;
    var fullHeight = itemIds.length * cfg.height;
    var colWidth = cfg.col_width;
    var countX = cfg.count;
    var countY = items.length;
    var endCountX = Math.ceil(endX / colWidth);
    var startCountX = Math.floor(startX / colWidth);
    if (endCountX > countX) {
      endCountX = countX;
    }
    gantt._backgroundRenderer._render_bg_canvas(svg, items, {
      fromX: startCountX,
      toX: endCountX,
      fromY: 0,
      toY: countY
    });
    svg.node.style.left = (cfg.left[startCountX] - startX) + "px";
    return $background.height(fullHeight);
  },
  cloneLinks: function ($source, start, end) {
    var $gantt_links_area = $source.find(".gantt_links_area");
    var $links = $gantt_links_area
        .clone()
        .addClass("gantt-print__links-area")
        .css('left', -start + 'px');
    $links.find(".gantt_task_link > div").filter(function () {
      var left = parseInt(this.style.left);
      var width = parseInt(this.style.width || 10);
      //ysy.log.debug("start: " + (left + width) + "<" + start +
      //    " end: " + left + ">" + end +
      //    "    filtered = " + (left > end || left + width < start));
      return (left > end || left + width < start);
    }).remove();
    return $links;
  },
  cloneTasks: function ($source, start, end) {
    var $gantt_bars_area = $source.find(".gantt_bars_area");
    var $tasks = $($gantt_bars_area[0].cloneNode(false))
        .addClass("gantt-print__bars-area")
        .css('left', -start + 'px');
    var taskArray = $gantt_bars_area.children();
    for (var i = 0; i < taskArray.length; i++) {
      var task = taskArray[i];
      var left = parseInt(task.style.left) - 50;
      var width = task.offsetWidth + 300;
      // ysy.log.debug(JSON.stringify({text: $(task).text(), start: (left + task.offsetWidth) + "<" + start,  end: left + ">" + end}));
      if (left >= end || left + width <= start) continue;
      $tasks.append($(task).clone());
    }
    var sourceCanvases = $gantt_bars_area.find("canvas");
    if (sourceCanvases.length > 0) {
      var clonedCanvases = $tasks.find("canvas");
      for (i = 0; i < clonedCanvases.length; i++) {
        clonedCanvases[i].getContext('2d').drawImage(sourceCanvases[i], 0, 0);
      }
    }
    return $tasks;
  }
};
//######################################################################################################################
ysy.pro = ysy.pro || {};
ysy.pro.pdfPrint = ysy.pro.pdfPrint || {};
$.extend(ysy.pro.pdfPrint, {
  beats: 0,
  targetBeat: 2,
  patch: function () {
    if (!ysy.settings.pdfPrint) return;
    ysy.data.loader.register(function () {
      ysy.view.onRepaint.push($.proxy(this.repaint, this));
    }, this);
  },
  repaint: function () {
    if (this.beats > this.targetBeat) return;
    // skip first few renders
    if (this.beats === this.targetBeat) {
      gantt._backgroundRenderer.switchFullRender(true);
      gantt._unset_sizes();
      // window.print();
    }
    this.beats++;
  }
});
