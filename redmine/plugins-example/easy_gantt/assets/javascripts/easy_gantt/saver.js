/* saver.js */
/* global ysy */
window.ysy = window.ysy || {};
if (!ysy.gateway) ysy.gateway = {};
$.extend(ysy.gateway, {
  requestsGroups: {},
  temp: {
    retry: false,
    superSuccess: null,
    superFail: null,
    fails: 0
  },
  sendIssue: function (method, issueID, data, callback) {
    var priority = 3;
    if (method === "REPAIR") {
      method = "PUT";
      priority = 9;
    }
    var urlTemplate = ysy.settings.paths["issue" + method];
    if (!urlTemplate) return;
    //var url=urlTemplate+(method==="POST"?"":"/"+issueID)+".json";
    var url = urlTemplate.replace(":issueID", issueID);
    //var url = Mustache.render(urlTemplate, {issueID: issueID, apiKey: this.getApiKey()});
    this.prepare({
      priority: priority,
      method: method,
      url: url,
      data: data,
      callback: callback,
      issueID: issueID
    });
  },
  sendRelation: function (method, rela, data, callback) {
    var urlTemplate = ysy.settings.paths["relation" + method];
    if (!urlTemplate) return;
    //var url = Mustache.render(urlTemplate, $.extend(this.getBasicParams(), {
    //  relaID: rela.id,
    //  sourceID: rela.source_id
    //}));
    var url = urlTemplate.replace(":issueID", rela.source_id).replace(":projectID", rela.getSource().project_id).replace(":relaID", rela.id);
    var priorities = {DELETE: 1, POST: 6, PUT: 6};
    this.prepare({
      priority: priorities[method],
      method: method,
      url: url,
      data: data,
      callback: callback,
      relation: rela
    });
  },
  sendMilestone: function (method, mile, data, callback) {
    var urlTemplate = ysy.settings.paths["version" + method];
    if (!urlTemplate) return;
    //var url = Mustache.render(urlTemplate, $.extend(this.getBasicParams(), {versionID: mile.id}));
    var url = urlTemplate.replace(":versionID", mile.id).replace(":projectID", mile.project_id);
    this.prepare({priority: 2, method: method, url: url, data: data, callback: callback, milestone: mile});
  },
  sendProject: function (method, project, data, callback) {
    var urlTemplate = ysy.settings.paths["project" + method];
    if (!urlTemplate) return;
    var url = urlTemplate.replace(":projectID", project.id);
    this.prepare({priority: 10, method: method, url: url, data: data, callback: callback, project: project});
  },
  prepare: function (packet) {
    if (!this.requestsGroups) {
      this.requestsGroups = {};
    }
    var priority = packet.priority;
    if (!this.requestsGroups[priority]) {
      this.requestsGroups[priority] = [];
    }
    this.requestsGroups[priority].push(packet);
    ysy.log.debug("prepared " + packet.method + " " + packet.url, "supersend");
  },
  send: function (request) {
    ysy.log.debug(request.method + " " + request.url + " " + JSON.stringify(request.data), "send");
    var xhr = $.ajax({
      url: request.url,
      type: request.method,
      dataType: "text",
      data: request.data
    });
    xhr.done(function (message) {
      if (request.callback) {
        request.callback(message);
      }
      var temp = ysy.gateway.temp;
      temp.successes++;
      request.passed = true;
      temp.retry = true;
      return true;
    }).fail(function (response) {
      var temp = ysy.gateway.temp;
      temp.allOk = false;
      temp.fails++;
      if (response.responseText) {
        try {
          var json = JSON.parse(response.responseText);
          if (json.errors.length) {
            request.errorMessage = json.errors[0];
          }
        } catch (e) {
          request.errorMessage = response.responseText;
        }
      }
      request.errorStatus = response.statusText;
    }).always(ysy.gateway._process);
    //pending.push(xhr);
    return xhr;
  },
  fireSend: function (success, fail) {
    var requestList = [];
    var keys = Object.getOwnPropertyNames(this.requestsGroups);
    if (keys.length === 0) {
      success();
      return;
    }
    var sortedKeys = [];
    for (var i = 0; i < keys.length; i++) {
      sortedKeys.push(parseFloat(keys[i]));
    }
    sortedKeys.sort();

    for (i = 0; i < sortedKeys.length; i++) {
      requestList = requestList.concat(this.requestsGroups[sortedKeys[i]]);
    }
    ysy.log.debug("_fireSend() ", "supersend");
    this.temp = {
      requestList: requestList,
      superSuccess: success,
      superFail: fail,
      retry: true
    };
    this._fireRetry();
  },
  _fireRetry: function () {
    var temp = ysy.gateway.temp;
    if (temp.allOk) {
      ysy.log.debug("superSuccess triggered", "supersend");
      if (temp.superSuccess) {
        temp.superSuccess();
      }
      this.requestsGroups = {};
      return;
    }
    if (!temp.retry) {
      ysy.log.debug("superFail triggered", "supersend");
      if (temp.superFail) {
        temp.superFail(this.gatherErrors());
      }
      this.requestsGroups = {};
      return;
    }
    ysy.log.debug("_fireRetry() ", "supersend");
    $.extend(temp, {
      pointer: 0,
      fails: 0,
      successes: 0,
      retry: false,
      allOk: true
    });
    this._fireOne();

  },
  _fireOne: function () {
    var temp = this.temp;
    if (temp.pointer >= temp.requestList.length) {
      this._fireRetry();
      return;
    }
    var req = temp.requestList[temp.pointer];
    temp.pointer++;
    if (req && !req.passed) {
      this.send(req);
    } else {
      this._fireOne();
    }
  },
  _process: function (hrx) {
    var temp = ysy.gateway.temp;
    ysy.log.debug("AJAX _process (p=" + temp.pointer + ",s=" + temp.successes + ",f=" + temp.fails + ")", "supersend");
    ysy.gateway._fireOne();
  },
  gatherErrors: function () {
    var errors = [];
    var temp = this.temp;
    var reqList = temp.requestList;
    if (!reqList || reqList.length === 0)return;
    for (var j = 0; j < reqList.length; j++) {
      var request = reqList[j];
      if (request.passed) continue;
      var error, name, entityType = null;
      if (request.issueID || (request.data && request.data.issue)) {
        entityType = "issue";
        var issue = ysy.data.issues.getByID(request.issueID);
        if (issue) {
          name = '"' + issue.name + '"';
        } else if (request.data && request.data.issue) {
          name = '"' + request.data.issue.subject + '"';
        } else {
          name = "#" + request.issueID;
        }
      } else if (request.project) {
        entityType = "project";
        name = '"' + request.project.name + '"';
      } else if (request.milestone) {
        entityType = "milestone";
        name = '"' + request.milestone.name + '"';
      } else if (request.relation) {
        entityType = "relation";
        var source = request.relation.getSource();
        var target = request.relation.getTarget();
        name = '"' + source.name + '" - "' + target.name + '"';
      }
      if (entityType) {
        error = ysy.settings.labels.gateway.entitySaveFailed.replace("%{entityName}", name).replace("%{entityType}", ysy.settings.labels.types[entityType]);
      } else {
        error = request.method + " " + request.url.substr(0, request.url.indexOf('?')) + " - " + request.errorStatus;
      }
      if (request.errorMessage) {
        error += ": " + request.errorMessage;
      } else if (entityType) {
        error += ": " + request.errorStatus;
      }
      errors.push(error);
    }
    return errors;
  },
  polymorficGet: function (url, data, callback, fail) {
    if (!url) return;
    $.get(url, data)
        .done(callback)
        .fail(fail);
  },
  polymorficGetJSON: function (url, data, callback, fail) {
    if (!url) return;
    $.getJSON(url, data)
        .done(callback)
        .fail(fail);
  },
  polymorficPostJSON: function (url, data, callback, fail) {
    if (!url) return;
    $.ajax({
      url: url,
      type: "POST",
      data: data,
      dataType: "json"
    }).done(callback).fail(fail);
  },
  polymorficPost: function (url, obj, data, callback, fail) {
    if (!url) return;
    $.ajax({
      url: url,
      type: "POST",
      data: data,
      dataType: "text"
    }).done(callback).fail(fail);
  },
  polymorficPut: function (url, obj, data, callback, fail) {
    if (!url) return;
    $.ajax({
      url: url,
      type: "PUT",
      data: JSON.stringify(data),
      contentType: "application/json",
      dataType: "text"
    }).done(callback).fail(fail);
  },
  polymorficDelete: function (url, obj, callback, fail) {
    if (!url) return;
    $.ajax({
      url: url,
      type: "DELETE",
      dataType: "json"
    }).done(callback).fail(fail);
  }


});

ysy.data = ysy.data || {};
ysy.data.save = function () {
  ysy.data.saver.sendIssues();
  ysy.data.saver.sendRelations();
  ysy.data.saver.sendMilestones();
  ysy.data.saver.sendProjects();
  ysy.gateway.fireSend(
      ysy.data.saver.afterSaveSuccess,
      ysy.data.saver.afterSaveFail,
      true
  );
};
ysy.data.saver = {
  _name:"Saver",
  sendIssues: function () {
    var j, data;
    var issues = ysy.data.issues.array;
    for (j = 0; j < issues.length; j++) {
      var issue = issues[j];
      if (!issue._changed) continue;
      if (issue._deleted && issue._created) continue;
      if (issue._deleted) {
        ysy.gateway.sendIssue("DELETE", issue.id, null, callbackBuilder(issue));
      } else if (issue._created) {
        data = {issue: {}};
        for (var key in issue) {
          if (!issue.hasOwnProperty(key)) continue;
          if (ysy.main.startsWith(key, "_"))continue;
          data.issue[key] = issue[key];
        }
        delete data.issue["name"];
        delete data.issue["id"];
        delete data.issue["end_date"];
        $.extend(data.issue, {
          subject: issue.name,
          start_date: issue.start_date ? issue.start_date.format("YYYY-MM-DD") : undefined,
          due_date: issue.end_date ? issue.end_date.format("YYYY-MM-DD") : undefined
        });
        var parents = ysy.data.saver.constructParentData(issue);
        $.extend(data.issue, parents);
        ysy.gateway.sendIssue("POST", null, data, this.callbackBuilder(issue));
        //ysy.log.error("Issue "+issue.id+" cannot be created - not implemented");
      } else {
        data = {};
        for (key in issue) {
          if (!issue.hasOwnProperty(key)) continue;
          if (ysy.main.startsWith(key, "_"))continue;
          data[key] = issue[key];
        }
        delete data["end_date"];
        delete data["columns"];
        $.extend(data, {
          start_date: issue.start_date ? issue.start_date.format("YYYY-MM-DD") : undefined,
          due_date: issue.end_date ? issue.end_date.format("YYYY-MM-DD") : undefined
        });
        // parents = ysy.data.saver.constructParentData(issue);
        // $.extend(data, parents);
        ysy.proManager.fireEvent("beforeSaveIssue", data);
        data = issue.getDiff(data);
        if (data === null) {
          this.callbackBuilder(issue)();
          continue;
        }
        ysy.gateway.sendIssue("PUT", issue.id, {issue: data}, this.callbackBuilder(issue));
        //console.log("Issue "+issue.id);
      }
    }
  },
  sendRelations: function () {
    var j, data;
    var relas = ysy.data.relations.array;
    var repairedIssues = {};
    for (j = 0; j < relas.length; j++) {
      var rela = relas[j];
      if (ysy.settings.fixedRelations) {
        rela.makeDelayFixedForSave();
      }
      if (!rela._changed) continue;
      if (rela._deleted && rela._created) continue;
      //var callback=$.proxy(function(){this._changed=false;},rela);
      if (rela._deleted) {
        ysy.gateway.sendRelation("DELETE", rela, null, this.callbackBuilder(rela));
      } else {
        //if(rela.delay>0){data.relation.delay=rela.delay;}
        if (rela._created) {
          data = {
            relation: {
              issue_to_id: rela.target_id,
              relation_type: rela.type,
              delay: rela.delay
            },
            project_id: rela.getTarget().project_id
          };
          ysy.gateway.sendRelation("POST", rela, data, this.callbackBuilder(rela));
        } else {
          data = {delay: rela.delay};
          ysy.gateway.sendRelation("PUT", rela, data, this.callbackBuilder(rela));
        }
        var targetIssue = rela.getTarget();
        repairedIssues[targetIssue.id] = targetIssue;
      }
    }
    for (var id in repairedIssues) {
      if (!repairedIssues.hasOwnProperty(id)) continue;
      targetIssue = repairedIssues[id];
      var targetData = {
        issue: {
          start_date: targetIssue.start_date ? targetIssue.start_date.format("YYYY-MM-DD") : undefined,
          due_date: targetIssue.end_date ? targetIssue.end_date.format("YYYY-MM-DD") : undefined
        }
      };
      ysy.gateway.sendIssue("REPAIR", targetIssue.id, targetData, null);
    }
  },
  sendMilestones: function () {
    var j, data;
    var miles = ysy.data.milestones.array;
    for (j = 0; j < miles.length; j++) {
      var mile = miles[j];
      if (!mile._changed) continue;
      if (mile._deleted && mile._created) continue;
      //var callback=$.proxy(function(){this._changed=false;},mile);
      if (mile._deleted) {
        ysy.gateway.sendMilestone("DELETE", mile, null, this.callbackBuilder(mile));
      } else if (mile._created) {
        data = {
          version: {
            name: mile.name,
            //status: the status of the version in: open (default), locked, closed
            //sharing: the version sharing in: none (default), descendants, hierarchy, tree, system
            description: mile.description,
            due_date: mile.start_date.format("YYYY-MM-DD")
          }
        };
        ysy.gateway.sendMilestone("POST", mile, data, this.callbackBuilder(mile));
        //ysy.log.error("Milestone "+mile.id+" cannot be created - not implemented");
        //ysy.gateway.sendIssue("POST",issue.id,null,callback);
        //console.log("Issue "+issue.id+" created");
      } else {
        data = {
          version: {
            due_date: mile.start_date.format("YYYY-MM-DD")
          }
        };
        ysy.gateway.sendMilestone("PUT", mile, data, this.callbackBuilder(mile));
      }
    }
  },
  sendProjects: function () {
  },
  callbackBuilder: function (item) {
    return function (response) {
      var message = (item.name || item._name);
      //dhtmlx.message(message,"success");
      ysy.log.debug(message + " sended", "send");
      if (response) {
        try {
          var parsedResponse = JSON.parse(response);
        } catch (e) {
        }
        if (parsedResponse) {
          var model = parsedResponse.issue
              || parsedResponse.project
              || parsedResponse.version
              || parsedResponse.relation;
          if (model) {
            item.setSilent({
              id: model.id,
              _created: false
            });
            item._fireChanges(ysy.data.saver, "afterPOST set");
          }
        }
      }
      item._changed = false;
    }
  },
  constructParentData: function (issue) {
    var data = {
      parent_issue_id: null,
      fixed_version_id: null,
      project_id: issue.project_id
    };
    var parent;
    if (issue.parent_issue_id) {
      data.parent_issue_id = issue.parent_issue_id;
      parent = ysy.data.issues.getByID(issue.parent_issue_id);
      if (parent) {
        data.fixed_version_id = parent.fixed_version_id;
        //data.project_id = parent.project_id;
      }
    } else if (issue.fixed_version_id) {
      data.fixed_version_id = issue.fixed_version_id;
      //parent = ysy.data.milestones.getByID(issue.fixed_version_id);
      //if (parent) {
      //  data.project_id = parent.project_id;
      //}
    }
    return data;
  },
  afterSaveSuccess: function () {
    dhtmlx.message(ysy.view.getLabel("gateway", "allSended"), "notice", 2000);
    ysy.data.loader.load();
  },
  afterSaveFail: function (errors) {
    var string = "<p>" + ysy.view.getLabel("gateway", "sendFailed") + "</p><ul>";
    for (var i = 0; i < errors.length; i++) {
      string += "<li>" + errors[i] + "</li>";
    }
    dhtmlx.message(string + "</ul>", "error",5000);
    //for(var i=0;i<errors.length;i++){
    //  showFlashMessage("error",errors[i])
    //}
    // ysy.data.saver.openReloadModal(errors);
    ysy.data.loader.load();
  }
  // openReloadModal: function (errors) {
  //   var $target = ysy.main.getModal("form-modal", "50%");
  //   var template = ysy.view.getTemplate("reloadModal");
  //   //var obj = $.extend({}, ysy.view.getLabel("reloadModal"),{errors:errors});
  //   var rendered = Mustache.render(template, {errors: errors});
  //   $target.html(rendered);
  //   showModal("form-modal");
  //   $target.dialog({
  //     buttons: [
  //       {
  //         id: "reload_modal_yes",
  //         text: ysy.settings.labels.buttons.button_yes,
  //         class: "gantt-reload-modal-button button-1",
  //         click: function () {
  //           $target.dialog("close");
  //           $(".flash").remove();
  //           ysy.data.loader.load();
  //         }
  //       },
  //       {
  //         id: "reload_modal_no",
  //         text: ysy.settings.labels.buttons.button_no,
  //         class: "gantt-reload-modal-button button-2",
  //         click: function () {
  //           $target.dialog("close");
  //         }
  //       }
  //     ]
  //   });
  //   $("#reload_modal_yes").focus();
  // }
};

