L.Control.Coordinates = L.Control.extend({
	options: {
		position: 'bottomleft'
	},

	onAdd: function (map) {
		var name = 'control-coordinates',
		    container = L.DomUtil.create('div', name + ' webmap-control');
	
		container.innerHTML = "Mouse pos: - N / - E<br/>Last click: - N / - E"
		L.DomEvent.on (container, 'mousemove', L.DomEvent.stopPropagation);

		this._map = map;
		this._div = container;

		map.on('mousemove', this._onMouseMove, this);
		map.on('mouseout', this._onMouseOut, this);
		map.on('click', this._onClick, this);

		return container;
	},

	onRemove: function (map) {
	},

	_onMouseMove: function (e) {
		this.lastPos = e.latlng;
		this._updateText ();
	},
	
	_onMouseOut: function (e) {
		this.lastPos = false;
		this._updateText ();
	},

	_onClick: function (e) {
		this.lastClick = e.latlng;
		this._updateText ();
	},
	
	_updateText: function (e) {
		this._div.innerHTML = "Mouse pos: " + this._formatCoord(this.lastPos) + "<br/>" +
				"Last click: " + this._formatCoord(this.lastClick);
	},

	_formatCoord: function(latlng) {
		if (latlng == false)
			return "- N / - E";
		else
			return "" +
				Math.abs(latlng.lng).toFixed(0) + (latlng.lng>=0 ? " N" : " S") + " / " +
				Math.abs(latlng.lat).toFixed(0) + (latlng.lat>=0 ? " E" : " W");
	},
	
	lastPos: false,
	lastClick: false

});

