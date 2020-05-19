L.Control.ReloadTiles = L.Control.extend({
	options: {
		position: 'bottomleft',
		autoreload_enable: true,
		autoreload_minInterval: 30,
		autoreload_interval: 120,
		autoreload_defaultOn: false,
		layers: []
	},

	onAdd: function (map) {
		var name = 'control-reloadtiles',
		    container = L.DomUtil.create('div', name + ' webmap-control');

		var stop = L.DomEvent.stopPropagation;
		L.DomEvent
		    .on (container, 'mousemove', stop)
		    .on (container, 'click', stop)
		    .on (container, 'mousedown', stop)
		    .on (container, 'dblclick', stop);

		this._map = map;
		
		this._reloadbutton = $("<a>")
			.addClass (name+"-btn")
			.text ("Reload tiles now")
			.attr ("href", "#")
			.attr ("title", "Reload tiles now")
			.on ("click.action", null, this, this._reload);
		$(container).append (this._reloadbutton);

		if (this.options.autoreload_enable) {
			$(container).append ("<br>");
		
			this._autocheck = $("<input>")
				.addClass (name + "-chk")
				.attr ("type", "checkbox")
				.attr ("name", "map_reloadtiles_autoreload")
				.attr ("id", "map_reloadtiles_autoreload")
				.attr ("value", "1")
				.on ("change", null, this, this._selectreload);
			if (this.options.autoreload_defaultOn) {
				this._autocheck.attr ("checked", "checked");
				this._timeout = window.setTimeout ($.proxy (this._reloadTilesEvent, this), this.options.autoreload_interval*1000);
			}
			$(container).append (this._autocheck);
		
			var label1 = $("<label>")
				.attr ("for", "map_reloadtiles_autoreload");
			label1.append ("Reload every ");
			$(container).append (label1);
		
			this._reloadinterval = $("<input>")
				.addClass (name + "-txt")
				.attr ("name", "map_reloadtiles_autoreload_time")
				.attr ("type", "text")
				.attr ("size", "4")
				.attr ("maxlength", "5")
				.attr ("value", this.options.autoreload_interval)
				.on ("input", null, this, this._verifyinterval);
			$(container).append (this._reloadinterval);

			var label2 = $("<label>")
				.attr ("for", "map_reloadtiles_autoreload");
			label2.append (" seconds");
			$(container).append (label2);
		}
		
		return container;
	},

	onRemove: function (map) {
	},
	
	_selectreload: function (e) {
		if (e.data._autocheck.prop ("checked")) {
			e.data._timeout = window.setTimeout ($.proxy (e.data._reloadTilesEvent, e.data), e.data.options.autoreload_interval*1000);
		} else {
			window.clearTimeout (e.data._timeout);
		}
	},
	
	_verifyinterval: function (e) {
		var val = e.data._reloadinterval.val ();
		if (/^[\d]+$/.test (val)) {
			if (val >= e.data.options.autoreload_minInterval) {
				e.data._reloadinterval.removeClass ("invalidinput");
				e.data.options.autoreload_interval = val;
				if (e.data._autocheck.prop ("checked")) {
					window.clearTimeout (e.data._timeout);
					e.data._timeout = window.setTimeout ($.proxy (e.data._reloadTilesEvent, e.data), e.data.options.autoreload_interval*1000);
				}
			} else {
				e.data._reloadinterval.addClass ("invalidinput");
			}
		} else {
			e.data._reloadinterval.addClass ("invalidinput");
		}
	},

	_reload: function (e) {
		var newTileTime = new Date().getTime();
		
		for (var i = 0; i < e.data.options.layers.length; i++) {
			e.data.options.layers [i].options.time = newTileTime;
			e.data.options.layers [i].redraw ();
		}
	},

	_reloadTilesEvent: function() {
		var div = this._div;
		this._reload ({data: this});
		this._timeout = window.setTimeout ($.proxy (this._reloadTilesEvent, this), this.options.autoreload_interval*1000);
	},

});

