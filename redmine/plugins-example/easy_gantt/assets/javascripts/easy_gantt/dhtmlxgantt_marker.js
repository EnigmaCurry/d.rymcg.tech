/*
@license

dhtmlxGantt v.3.2.1 Stardard
This software is covered by GPL license. You also can obtain Commercial or Enterprise license to use it in non-GPL project - please contact sales@dhtmlx.com. Usage without proper license is prohibited.

(c) Dinamenta, UAB.
*/

if(!gantt._markers)
	gantt._markers = {};

gantt.config.show_markers = true;

gantt.attachEvent("onClear", function(){
	gantt._markers = {};
});

gantt.attachEvent("onGanttReady", function(){
	/*if(!gantt.$marker_area){  //   HOSEK
		var markerArea=$(".gantt_marker_area");
		if(markerArea.length===0){
			markerArea = document.createElement("div");
			markerArea.className = "gantt_marker_area";
			gantt.$task_data.appendChild(markerArea);
		}else{
			markerArea=markerArea[0];
		}
		gantt.$marker_area = markerArea;
	}*/    //  HOSEK

	//gantt._markerRenderer = gantt._task_renderer("markers", render_marker, gantt.$marker_area, null);
	gantt._markerRenderer = gantt._task_renderer({id:"markers",renderer: render_marker,container: gantt.$marker_area,filter: null});

	function render_marker(marker){
		if(!gantt.config.show_markers)
			return false;

		if(!marker.start_date)
			return false;

		var state = gantt.getState();
		if(+marker.start_date > +state.max_date)
			return;
		if(+marker.end_date && +marker.end_date < +state.min_date || +marker.start_date < +state.min_date)
			return;

		var div = document.createElement("div");

		div.setAttribute("marker_id", marker.id);

		var css = "gantt_marker";
		if(gantt.templates.marker_class)
			css += " " + gantt.templates.marker_class(marker);

		if(marker.css){
			css += " " + marker.css;
		}

		if(marker.title){
			div.title = marker.title;
		}
		div.className = css;

		var start = gantt.posFromDate(marker.start_date);
		div.style.left = start + "px";
		div.style.height = Math.max(gantt._y_from_ind(gantt._order.length), 0) + "px";
		if(marker.end_date){
			var end = gantt.posFromDate(marker.end_date);
			div.style.width = Math.max((end - start), 0) + "px";

		}

		if(marker.text){
			div.innerHTML = "<div class='gantt_marker_content' >" + marker.text + "</div>";
		}

		return div;
	}
});


gantt.attachEvent("onDataRender", function(){
	gantt.renderMarkers();
});

gantt.getMarker = function(id){
	if(!this._markers) return null;

	return this._markers[id];
};

gantt.addMarker = function(marker){
	marker.id = marker.id || dhtmlx.uid();

	this._markers[marker.id] = marker;

	return marker.id;
};

gantt.deleteMarker = function(id){
	if(!this._markers || !this._markers[id])
		return false;

	delete this._markers[id];
	return true;
};
gantt.updateMarker = function(id){
	if(this._markerRenderer)
		this._markerRenderer.render_item(id);
};
gantt.renderMarkers = function(){
	if(!this._markers)
		return false;

	if(!this._markerRenderer)
		return false;

	var to_render = [];

	for(var id in this._markers)
		to_render.push(this._markers[id]);

	this._markerRenderer.render_items(to_render);

	return true;
};