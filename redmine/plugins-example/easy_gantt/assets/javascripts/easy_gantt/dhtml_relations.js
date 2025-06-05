/* dhtml_relations.js */
/* global ysy */
window.ysy = window.ysy || {};
ysy.pro = ysy.pro || {};
ysy.pro.relations = {
  patch: function () {
    if (ysy.settings.fixedRelations) {
      ysy.pro.relations = null;
      return;
    }
    var patch = function () {
      gantt.multiStop = function (task, start_date, end_date, previous) {
        var diff;
        var sumMove = 0;
        if (!previous) {
          previous = {
            visitedLinks: [],
            visitedParents: [],
            alreadyMoved: []
          };
          // ysy.log.debug("previous created");
        }
        if (task.soonest_start && start_date && start_date.isBefore(task.soonest_start)) {
          diff = task.soonest_start.diff(start_date, "seconds");
          start_date.add(diff, "seconds");
          if (end_date) end_date.add(diff, "seconds");
          sumMove += diff;
          ysy.log.debug("AscStop(): soonest_start task=" + task.text + " diff=" + diff, "asc");
        }
        if (task.latest_due && end_date && end_date.isAfter(task.latest_due)) {
          diff = task.latest_due.diff(end_date, "seconds");
          end_date.add(diff, "seconds");
          if (start_date) start_date.add(diff, "seconds");
          sumMove += diff;
          ysy.log.debug("AscStop(): latest_end task=" + task.text + " diff=" + diff, "asc");
        }
        if (end_date) {
          if (ysy.settings.milestonePush) {
            var newStartDate = gantt.descStartByMilestone(task, +start_date, +end_date);
            if (newStartDate) {
              ysy.log.debug("AscStop(): milePush task=" + task.text + " start_date=" + newStartDate.format("YYYY-MM-DD"), "asc");
              var newEndDate = gantt._working_time_helper.add_worktime(newStartDate, task.duration, "day", true);
              var mileDiff = (newEndDate - end_date) / 1000;
              end_date.add(mileDiff, "seconds");
              if (start_date) {
                mileDiff = (newStartDate - start_date) / 1000;
                start_date.add(mileDiff, "seconds");
              }
              ysy.log.debug("task=" + task.text + " mileDiff=" + (mileDiff / 86400), "task_drag_milestone");
              sumMove += mileDiff;
            }
          }
        }
        //  ####################
        sumMove += gantt.ascStop(task, start_date, end_date, previous);
        var parentId = gantt.getParent(task.id);
        var parent = gantt._pull[parentId];
        if (parent && gantt._get_safe_type(parent.type) === "task") {
          // if(parent.start_date.isAfter(start_date) || parent.end_date.isAfter(end_date)){
          var branch = gantt._branches[parent.id];
          if (branch && branch.length > 0) {
            var minDate = start_date;
            var maxDate = end_date;
            for (var i = 0; i < branch.length; i++) {
              var childId = branch[i];
              var child = gantt.getTask(childId);
              if (child.id === task.id) continue;

              if (!minDate || minDate.isAfter(child.start_date)) {
                minDate = child.start_date;
              }
              if (!maxDate || maxDate.isBefore(child.end_date)) {
                maxDate = child.end_date;
              }
            }
          }
          var parentSumMove = gantt.multiStop(parent, moment(minDate), moment(maxDate));
          if (start_date) {
            start_date.add(parentSumMove, "seconds");
            if (end_date) {
              var new_end = gantt._working_time_helper.add_worktime(start_date, task.duration, "day", true); //< HOSEKP
              end_date.add(new_end - end_date, "milliseconds");
            }
          } else {
            end_date.add(parentSumMove, "seconds");
          }
          if (parentSumMove > sumMove) {
            ysy.log.debug("AscStop(): parent task=" + task.text + " diff=" + parentSumMove, "asc");
            sumMove = parentSumMove;
          }
          // }
        }
        return sumMove;
      };
      gantt.ascStop = function (task, start_date, end_date, previous) {
        var shortestDiff;
        var diff, sumMove = 0;
        for (var i = 0; i < task.$target.length; i++) {
          var lid = task.$target[i];
          if (previous.visitedLinks.indexOf(lid) > -1) continue; // skip link sourcing moved parent
          var link = gantt._lpull[lid];
          if (link.isSimple) continue;
          var targetDate;
          if (link.type === "precedes" || link.type === "start_to_start") {
            if (!start_date) continue;
            targetDate = start_date;
          } else if (link.type === "finish_to_finish" || link.type === "start_to_finish") {
            if (!end_date) continue;
            targetDate = end_date;
          } else continue;
          var source = gantt._pull[link.source];
          var sourceDate = gantt.getLinkSourceDate(source, link.type);
          diff = -targetDate.diff(sourceDate, "seconds") + gantt.getLinkCorrection(link.type) * 24 * 60 * 60;
          if (!link.unlocked) {
            diff += link.delay * 24 * 60 * 60;
            if (diff <= 0) {
              if (shortestDiff === undefined || shortestDiff < diff) {
                shortestDiff = diff;
              }
            }
          }
          if (diff > 0) {
            sumMove += diff;
            ysy.log.debug("AscStop(): relDiff<0 task=" + task.text + " diff=" + diff, "asc");
            if (start_date) {
              start_date.add(diff, "seconds");
            }
            if (end_date) {
              var new_end = gantt._working_time_helper.add_worktime(start_date, task.duration, "day", true); //< HOSEKP
              end_date.add(new_end - end_date, "milliseconds");
              // end_date.add(diff, "seconds");
            }
            shortestDiff = 0;
          }
        }
        if (shortestDiff) {
          sumMove += shortestDiff;
          ysy.log.debug("AscStop(): shortest_diff task=" + task.text + " diff=" + shortestDiff, "asc");
          if (start_date) {
            start_date.add(shortestDiff, "seconds");
          }
          if (end_date) {
            new_end = gantt._working_time_helper.add_worktime(start_date, task.duration, "day", true); //< HOSEKP
            end_date.add(new_end - end_date, "milliseconds");
            // end_date.add(shortestDiff, "seconds");
          }
        }
        return sumMove;
      };
      /**
       *
       * @param task
       * @param {{[old_start]:{},[old_end]:{},[fromParent]:boolean,[fromChild]:boolean,[asc]:boolean}} options
       * @param previous
       * @return {number}
       */
      gantt.moveDesc = function (task, options, previous/*, resizing*/) {
        // runs after task dates are already modified.
        if (!previous) {
          previous = {
            visitedLinks: [],
            visitedParents: [],
            alreadyMovedFrom: {},
            central: task,
            parentsToRecalculate: []
          };
          previous.alreadyMovedFrom[task.id] = options.old_start;
          // ysy.log.debug("previous created");
        }
        if (!options.old_start) {
          options.old_start = previous.alreadyMovedFrom[task.id];
        }
        var shouldMove = gantt.shouldMoveChildren(task);
        if (!options.fromChild && shouldMove.move) {
          var children = gantt.moveChildren(task, $.extend({}, options, {fromParent: true}), previous);
        } else if (shouldMove.milestoneMove) {
          this.moveMilestoneChildren(task, {old_start: options.old_start}, previous);
        }
        if (shouldMove.adjust) {
          if (!children) {
            var branch = gantt._branches[task.id];
            if (branch && branch.length !== 0) {
              children = [];
              for (i = 0; i < branch.length; i++) {
                children.push(gantt.getTask(branch[i]));
              }
            }
          }
          if (children && children.length) {
            var dates = {start_date: null, end_date: null};
            for (i = 0; i < children.length; i++) {
              var child = children[i];
              if (dates.start_date === null || dates.start_date.isAfter(child.start_date)) {
                dates.start_date = child.start_date;
              }
              if (dates.end_date === null || dates.end_date.isBefore(child.end_date)) {
                dates.end_date = child.end_date;
              }
            }
            task.start_date.add(dates.start_date - task.start_date, "milliseconds");
            task.end_date.add(dates.end_date - task.end_date, "milliseconds");
          }
        }

        var start_date = +task.start_date;
        var end_date = +task.end_date;
        if (!options.asc) {
          /** DESCENDANTS */
          for (var i = 0; i < task.$source.length; i++) {
            var lid = task.$source[i];
            var link = gantt._lpull[lid];
            if (previous.visitedLinks.indexOf(lid) > -1) continue;
            previous.visitedLinks.push(lid);
            if (link.isSimple) continue;
            var desc = gantt._pull[link.target];
            // var isTargetingEnd = link.type === "finish_to_finish" || link.type === "start_to_finish";
            if (!link.unlocked) {
              var descDates = this.getDescDates(link, start_date, end_date);
              // var diff = gantt.getFreeDelay(link, desc, start_date, end_date);
              if (descDates.end_date) {
                debugger
              } else {
                gantt.safeMoveToStartDate(desc, descDates.start_date, previous);
              }
              //ysy.log.debug("pushing "+desc.text+" by freeDelay "+diff);
              gantt.moveDesc(desc, {}, previous);
            } else {
              descDates = this.getDescDates(link, start_date, end_date);
              // var descDiff = gantt.getFreeDelay(link, desc, start_date, end_date);
              // if (descDiff <= 0) continue;
              // console.log("OVER");
              if (descDates.start_date && descDates.start_date.isAfter(desc.start_date)) {
                gantt.safeMoveToStartDate(desc, descDates.start_date, previous);
              }
              if (descDates.end_date && descDates.end_date.isAfter(desc.end_date)) {
                debugger;
                gantt.safeMoveToStartDate(desc, descDates.start_date, previous);
              }
              // ysy.log.debug("desc=" + desc.text +" diff="+diff+" descDiff="+descDiff);
              gantt.moveDesc(desc, {}, previous);
            }
          }
        } else {
          /** ASCENDANTS */
          for (i = 0; i < task.$target.length; i++) {
            lid = task.$target[i];
            link = gantt._lpull[lid];
            if (previous.visitedLinks.indexOf(lid) > -1) continue;
            previous.visitedLinks.push(lid);
            if (link.isSimple) continue;
            var asc = gantt._pull[link.source];
            // var isTargetingEnd = link.type === "finish_to_finish" || link.type === "start_to_finish";
            if (!link.unlocked) {
              var ascDates = this.getAscDates(link, start_date, end_date);
              // var diff = gantt.getFreeDelay(link, desc, start_date, end_date);
              if (ascDates.end_date) {
                debugger
              } else {
                gantt.safeMoveToStartDate(asc, ascDates.start_date, previous);
              }
              //ysy.log.debug("pushing "+desc.text+" by freeDelay "+diff);
              gantt.moveDesc(asc, {asc: true}, previous);
            } else {
              var ascDiff = gantt.getFreeDelay(link, task, asc.start_date, asc.end_date);
              if (ascDiff <= 0) continue;
              // ysy.log.debug("desc=" + desc.text +" diff="+diff+" descDiff="+descDiff);
              gantt.moveDesc(asc, {asc: true}, previous);
            }
          }
        }
        if (!options.fromParent) {
          gantt.moveParent(task, {}, previous);
        }
      };

      gantt.moveChildren = function (task, options, previous) {
        var branch = gantt._branches[task.id];
        if (!branch || branch.length === 0) return null;
        var children = [];
        for (var i = 0; i < branch.length; i++) {
          var childId = branch[i];
          //if(gantt.isTaskVisible(childId)){continue;}
          var child = gantt.getTask(childId);
          if (!child._parent_offset) {
            child._parent_offset = gantt._working_time_helper.get_work_units_between(options.old_start, child.start_date, "day");
          }
          children.push(child);
          if (previous.alreadyMovedFrom[childId]) continue;
          var childOldStart = previous.alreadyMovedFrom[childId] || child.start_date;
          var childNewStart = gantt._working_time_helper.add_worktime(task.start_date, child._parent_offset, "day", false);
          gantt.safeMoveToStartDate(child, childNewStart, previous);
          // child.start_date.add(childNewStart - child.start_date, "milliseconds");
          child._changed = gantt.config.drag_mode.move;
          gantt.moveDesc(child, {old_start: childOldStart, fromParent: options.fromParent}, previous);
          gantt.refreshTask(childId);
        }
        // gantt._update_parents(task.id);
        return children;
      };
      gantt.shouldMoveChildren = function (task) {
        if (task.type === "milestone") return {milestoneMove: true};
        if (gantt._get_safe_type(task.type) === "task" && ysy.settings.parentIssueDates) return {
          move: true,
          adjust: true
        };
        if (task.$open && gantt.isTaskVisible(task.id)) return {move: true};
        return false;
      };
      gantt.safeMoveToStartDate = function (task, start_date, previous) {
        if (task.start_date.isSame(start_date)) {
          previous.alreadyMovedFrom[task.id] = moment(start_date);
          return 0;
        }
        previous.alreadyMovedFrom[task.id] = moment(task.start_date);
        if (task.start_date.isAfter(start_date)) {
          // moved forward
          var end_date = gantt._working_time_helper.add_worktime(start_date, task.duration, "day", true);
          task.start_date.add(start_date - task.start_date, "milliseconds");
          task.end_date.add(end_date - task.end_date, "milliseconds");
          task._changed = gantt.config.drag_mode.move;
          gantt.refreshTask(task.id);
          return 0;
        } else {
          // moved backward
          end_date = gantt._working_time_helper.add_worktime(start_date, task.duration, "day", true);
          task.start_date.add(start_date - task.start_date, "milliseconds");
          task.end_date.add(end_date - task.end_date, "milliseconds");
          task._changed = gantt.config.drag_mode.move;
          gantt.refreshTask(task.id);
          var ascDiff = gantt.ascStop(task, task.start_date, task.end_date, previous);
          if (ascDiff !== 0) {
            // ysy.log.debug("diff=" + diff + " ascStopDiff=" + ascDiff);
            return ascDiff;
          }
        }
      };
      gantt.moveMilestoneChildren = function (milestone, options, previous) {
        var branch = gantt._branches[milestone.id];
        if (!branch || branch.length === 0) return 0;
        // ysy.log.debug("Shift children of \"" + milestone.text + "\" by " + shift + " seconds", "parent");
        ysy.log.debug("moveChildren():  of \"" + milestone.text + "\"(" + milestone.end_date.toISOString() + ") from " + options.old_start.toISOString(), "task_drag");
        // var milestoneEndDate=moment(milestone.end_date).add(shift,"seconds");
        // milestoneEndDate._isEndDate=true;
        for (var i = 0; i < branch.length; i++) {
          var childId = branch[i];
          var child = gantt.getTask(childId);
          if (child.end_date.isAfter(milestone.end_date)) {
            // var shift = milestone.end_date.diff(child.end_date, "seconds");
            // child.start_date.add(shift, 'seconds');
            var startDateValue = +child.start_date;
            // child.end_date = moment(milestone.end_date);
            // child.end_date._isEndDate = true;
            child.end_date.add(milestone.end_date - child.end_date, "milliseconds");
            var childNewStart = gantt._working_time_helper.add_worktime(child.end_date, -child.duration, "day", false);
            var childOldStart = moment(child.start_date);
            child.start_date.add(childNewStart - child.start_date, "milliseconds");
            // ysy.log.debug(child.start_date.toISOString()+"  "+child.end_date.toISOString());
            child._changed = gantt.config.drag_mode.move;
            gantt.refreshTask(child.id);
            previous.alreadyMovedFrom[child.id] = previous.alreadyMovedFrom[child.id] || childOldStart;
            gantt.moveDesc(child, {old_date: moment(startDateValue), asc: true}, previous);
          }
        }
        return 0;
      };
      gantt.moveParent = function (child, option, previous) {
        if (!ysy.settings.parentIssueDates) return;
        var parentId = gantt.getParent(child.id);
        if (previous.central.id === parentId) {
          parent = previous.central;
        } else {
          var parent = gantt._pull[parentId];
        }
        if (gantt._get_safe_type(parent.type) !== "task") return 0;
        // previous.visitedParents.push(parent.id);
        // if (parent.end_date.isBefore(child.end_date)) {
        //   parent.end_date.add(child.end_date - parent.end_date, "milliseconds");
        //   parent._changed = gantt.config.drag_mode.move;
        //   gantt.refreshTask(parent.id);
        //   // if(option.skipParent)
        // }
        gantt.moveDesc(parent, {fromChild: true/*old_start:moment(parent.start_date)*/}, previous);
      };
      gantt.startByMilestone = function (task, end_date) {
        var issue = task.widget && task.widget.model;
        if (!issue) return 0;
        var milestone = ysy.data.milestones.getByID(issue.fixed_version_id);
        if (!milestone) return 0;
        var ganttMilestone = gantt._pull[milestone.getID()];
        if (ganttMilestone) {
          var milestoneDate = ganttMilestone.end_date;
        } else {
          milestoneDate = milestone.start_date;
        }
        if (milestoneDate.isBefore(end_date)) {
          ysy.log.debug("milestoneStop() for " + task.text +
              " at " + milestone.start_date.format("YYYY-MM-DD"), "task_drag_milestone");
          return gantt._working_time_helper.toMoment(
              gantt._working_time_helper.add_worktime(milestoneDate, -task.duration, "day", false)
          );
        }
        return null;
      };
      gantt.descStartByMilestone = function (task, start_date, end_date) {
        var newStartDate = gantt.startByMilestone(task, end_date);
        // var start_date = +task.start_date / 1000 + diff;
        // var end_date = +task.end_date / 1000 + diff;
        for (var i = 0; i < task.$source.length; i++) {
          var lid = task.$source[i];
          var link = gantt._lpull[lid];
          if (link.isSimple) continue;
          var desc = gantt._pull[link.target];
          var descDiff = gantt.getFreeDelay(link, desc, start_date, end_date);
          if (descDiff <= 0) continue;
          var descEndDate = gantt._working_time_helper.add_worktime(desc.start_date + descDiff * 1000, desc.duration, "day", true);
          var correctedDescStartDate = gantt.descStartByMilestone(desc, desc.start_date + descDiff * 1000, descEndDate);
          if (!correctedDescStartDate) continue;
          switch (link.type) {
            case "precedes":
              if (!link.unlocked) {
                correctedDescStartDate.subtract(link.delay, "days");
              }
              var correctedStartDate = gantt._working_time_helper.add_worktime(correctedDescStartDate, -task.duration, "day", false);
              break;
            default:
              debugger;
          }
          if (!newStartDate || (correctedStartDate && correctedStartDate.isBefore(newStartDate))) {
            newStartDate = correctedStartDate;
          }
        }
        var childrenStartDate = gantt.childrenStartByMilestone(task, (newStartDate ? newStartDate : start_date) - task.start_date);
        if (childrenStartDate) {
          newStartDate = childrenStartDate;
        }
        if (newStartDate) {
          ysy.log.debug("milestoneDescStop(): task " + task.text + " start set to " + newStartDate.format("YYYY-MM-DD"), "task_drag_milestone");
        }
        return newStartDate;
      };
      gantt.childrenStartByMilestone = function (task, diff) {
        if (task.type === "milestone") return null;
        var branch = gantt._branches[task.id];
        if (!branch || branch.length === 0) return 0;
        var newStartDate;
        for (var i = 0; i < branch.length; i++) {
          var childId = branch[i];
          //if(gantt.isTaskVisible(childId)){continue;}
          var child = gantt.getTask(childId);
          var childEndDate = gantt._working_time_helper.add_worktime(child.start_date + diff, child.duration, "day", true);
          var correctedStartDate = gantt.descStartByMilestone(child, child.start_date + diff, childEndDate);
          if (!newStartDate || (correctedStartDate && correctedStartDate.isBefore(newStartDate))) {
            newStartDate = correctedStartDate;
          }
        }
        if (newStartDate) {
          ysy.log.debug("milestoneChildrenStop():  \"" + task.text + "\" start_date set to " + newStartDate.format("YYYY-MM-DD"), "task_drag");
        }
        return newStartDate;
      };
      gantt.getLinkSourceDate = function (source, type) {
        if (type === "precedes") return source.end_date;
        if (type === "finish_to_finish") return source.end_date;
        if (type === "start_to_start") return source.start_date;
        if (type === "start_to_finish") return source.start_date;
        return null;
      };
      gantt.getLinkTargetDate = function (target, type) {
        if (type === "precedes") return target.start_date;
        if (type === "finish_to_finish") return target.end_date;
        if (type === "start_to_start") return target.start_date;
        if (type === "start_to_finish") return target.end_date;
        return null;
      };
      gantt.getLinkCorrection = function (type) {
        if (type === "precedes") return 1;
        if (type === "start_to_finish") return -1;
        return 0;
      };
      /**
       * How much can be distance between two task shortened
       * @param link - gantt link
       * @param desc - gantt task
       * @param {number} ascStartDate - number of milliseconds since epoch
       * @param {number} ascEndDate - number of milliseconds since epoch
       * @return {number} - number of seconds
       */
      gantt.getFreeDelay = function (link, desc, ascStartDate, ascEndDate) {
        if (!desc) desc = gantt._pull[link.target];
        var sourceDate;
        var daysToSeconds = 60 * 60 * 24;
        if (!ascStartDate) {
          var asc = gantt._pull[link.source];
          ascStartDate = +asc.start_date;
          ascEndDate = +asc.end_date;
        }
        if (link.type === "precedes" || link.type === "finish_to_finish") {
          if (!ascEndDate) return 0;
          sourceDate = ascEndDate;
        } else if (link.type === "start_to_finish" || link.type === "start_to_start") {
          if (!ascStartDate) return 0;
          sourceDate = ascStartDate;
        } else return 0;
        var targetDate = +gantt.getLinkTargetDate(desc, link.type);
        var correction = gantt.getLinkCorrection(link.type);
        var delay = (targetDate - sourceDate) / daysToSeconds / 1000;
        return ((link.unlocked ? 0 : link.delay) + correction - delay) * daysToSeconds;
      };
      /**
       *
       * @param {{type:String,delay:int,source:int,target:int,unlocked:boolean}} link
       * @param {int} ascStartDate
       * @param {int} ascEndDate
       * @return {{[start_date]:Object,[end_date]:Object}}
       */
      gantt.getDescDates = function (link, ascStartDate, ascEndDate) {
        //if (!desc) desc = gantt._pull[link.target];
        var sourceDate;
        if (!ascStartDate) {
          var asc = gantt._pull[link.source];
          ascStartDate = +asc.start_date;
          ascEndDate = +asc.end_date;
        }
        if (link.type === "precedes" || link.type === "finish_to_finish") {
          if (!ascEndDate) return {};
          sourceDate = ascEndDate;
        } else if (link.type === "start_to_finish" || link.type === "start_to_start") {
          if (!ascStartDate) return {};
          sourceDate = ascStartDate;
        } else return {};
        var correction = gantt.getLinkCorrection(link.type);
        if (link.type === "finish_to_finish" || link.type === "start_to_finish") {
          var descEndDate = moment(sourceDate).add((link.unlocked ? 0 : link.delay) + correction, "days");
          descEndDate._isEndDate = true;
          var descSafeEnd = gantt._working_time_helper.get_closest_worktime({
            dir: "future",
            date: descEndDate
          });
          return {end_date: descSafeEnd};
        } else {
          var descStartDate = moment(sourceDate).add((link.unlocked ? 0 : link.delay) + correction, "days");
          var descSafeStart = gantt._working_time_helper.get_closest_worktime({
            dir: "future",
            date: descStartDate
          });
          return {start_date: descSafeStart};
        }
      };
      /**
       *
       * @param {{type:String,delay:int,source:int,target:int,unlocked:boolean}} link
       * @param {int} descStartDate
       * @param {int} descEndDate
       * @return {{[start_date]:moment,[end_date]:moment}}
       */
      gantt.getAscDates = function (link, descStartDate, descEndDate) {
        var targetDate;
        if (!descStartDate) {
          var desc = gantt._pull[link.target];
          descStartDate = +desc.start_date;
          descEndDate = +desc.end_date;
        }
        if (link.type === "start_to_finish" || link.type === "finish_to_finish") {
          if (!descEndDate) return {};
          targetDate = descEndDate;
        } else if (link.type === "precedes" || link.type === "start_to_start") {
          if (!descStartDate) return {};
          targetDate = descStartDate;
        } else return {};
        var correction = gantt.getLinkCorrection(link.type);
        if (link.type === "finish_to_finish" || link.type === "start_to_finish") {
          var ascEndDate = moment(targetDate).subtract((link.unlocked ? 0 : link.delay) + correction, "days");
          ascEndDate._isEndDate = true;
          var ascSafeEnd = gantt._working_time_helper.get_closest_worktime({
            dir: "past",
            date: ascEndDate
          });
          return {end_date: ascSafeEnd};
        } else {
          var ascStartDate = moment(targetDate).subtract((link.unlocked ? 0 : link.delay) + correction, "days");
          var ascSafeStart = gantt._working_time_helper.get_closest_worktime({
            dir: "past",
            date: ascStartDate
          });
          return {start_date: ascSafeStart};
        }
      };
      //##################################################################################################################
      gantt.attachEvent("onLinkClick", function (id, mouseEvent) {
        // if (!gantt.config.drag_links) return;
        ysy.log.debug("LinkClick on " + id, "link_config");
        var link = gantt.getLink(id);
        if (gantt._is_readonly(link)) return;
        var source = gantt._pull[link.source];
        if (!source) return;
        var target = gantt._pull[link.target];
        if (!target) return;
        if (source.readonly && target.readonly) return;
        var relation = link.widget.model;
        var isUnlocked = relation.unlocked;
        relation.set({unlocked: !isUnlocked, delay: isUnlocked ? relation.getActDelay() : 0});
        return false;
      });
      gantt.attachEvent("onContextMenu", function (taskId, id /*, mouseEvent*/) {
        if (taskId) return;
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
      });
    };
    patch();
  }
};
