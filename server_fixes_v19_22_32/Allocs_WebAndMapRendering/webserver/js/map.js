var mapinfo = {
	regionsize: 512,
	chunksize: 16,
	tilesize: 128,
	maxzoom: 4
}

function InitMap() {
	// ===============================================================================================
	// 7dtd coordinate transformations

	SDTD_Projection = {
		project: function (latlng) {
			return new L.Point(
				(latlng.lat) / Math.pow(2, mapinfo.maxzoom),
				(latlng.lng) / Math.pow(2, mapinfo.maxzoom) );
		},
		
		unproject: function (point) {
			return new L.LatLng(
				point.x * Math.pow(2, mapinfo.maxzoom),
				point.y * Math.pow(2, mapinfo.maxzoom) );
		}
	};

	SDTD_CRS = L.extend({}, L.CRS.Simple, {
		projection: SDTD_Projection,
		transformation: new L.Transformation(1, 0, -1, 0),

		scale: function (zoom) {
			return Math.pow(2, zoom);
		}
	});

	// ===============================================================================================
	// Map and basic tile layers

	map = L.map('tab_map', {
		zoomControl: false, // Added by Zoomslider
		zoomsliderControl: true,
		attributionControl: false,
		crs: SDTD_CRS
	}).setView([0, 0], Math.max(0, mapinfo.maxzoom - 5));


	var initTime = new Date().getTime();
	var tileLayer = GetSdtdTileLayer (mapinfo, initTime);
	var tileLayerMiniMap = GetSdtdTileLayer (mapinfo, initTime, true);

	// player icon
	var playerIcon = L.icon({
	    iconUrl: '/static/leaflet/images/marker-survivor.png',
	    iconRetinaUrl: '/static/leaflet/images/marker-survivor-2x.png',
	    iconSize: [25, 48],
	    iconAnchor: [12, 24],
	    popupAnchor: [0, -20]
	});
	
	// hostile icon
	var hostileIcon = L.icon({
	    iconUrl: '/static/leaflet/images/marker-zombie.png',
	    iconRetinaUrl: '/static/leaflet/images/marker-zombie-2x.png',
	    iconSize: [25, 33],
	    iconAnchor: [12, 16],
	    popupAnchor: [0, -10]
	});	
	
	// animal icon
	var animalIcon = L.icon({
	    iconUrl: '/static/leaflet/images/marker-animal.png',
	    iconRetinaUrl: '/static/leaflet/images/marker-animal-2x.png',
	    iconSize: [25, 26],
	    iconAnchor: [12, 13],
	    popupAnchor: [0, -10]
	});
	


	// ===============================================================================================
	// Overlays and controls

	var playersOnlineMarkerGroup = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});
	var playersOfflineMarkerGroup = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});
	var hostilesMarkerGroup = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});
	var animalsMarkerGroup = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});

	var densityMismatchMarkerGroupAir = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});
	var densityMismatchMarkerGroupTerrain = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});
	var densityMismatchMarkerGroupNonTerrain = L.markerClusterGroup({
		maxClusterRadius: function(zoom) { return zoom >= mapinfo.maxzoom ? 10 : 50; }
	});


	var layerControl = L.control.layers({
			//"Map": tileLayer
		}, null, {
			collapsed: false
		}
	);
	
	var layerCount = 0;


	tileLayer.addTo(map);

	new L.Control.Coordinates({}).addTo(map);
	
	new L.Control.ReloadTiles({
		autoreload_enable: true,
		autoreload_minInterval: 30,
		autoreload_interval: 120,
		autoreload_defaultOn: false,
		layers: [tileLayer, tileLayerMiniMap]
	}).addTo(map);
	
	layerControl.addOverlay (GetRegionLayer (mapinfo), "Region files");
	layerCount++;
	
	var miniMap = new L.Control.MiniMap(tileLayerMiniMap, {
		zoomLevelOffset: -6,
		toggleDisplay: true
	}).addTo(map);

	var measure = L.control.measure({
		units: {
			sdtdMeters: {
				factor: 0.00001,
				display: 'XMeters',
				decimals: 0
			},
			sdtdSqMeters: {
				factor: 0.000000001,
				display: 'XSqMeters',
				decimals: 0
			}
		},
		primaryLengthUnit: "sdtdMeters",
		primaryAreaUnit: "sdtdSqMeters",
		//activeColor: "#ABE67E",
		//completedColor: "#C8F2BE",
		position: "bottomleft"
	});
	//measure.addTo(map);

	new L.Control.GameTime({}).addTo(map);
	
	if (HasPermission ("webapi.getlandclaims")) {
		layerControl.addOverlay (GetLandClaimsLayer (map, mapinfo), "Land claims");
		layerCount++;
	}
	
	if (HasPermission ("webapi.gethostilelocation")) {
		layerControl.addOverlay (hostilesMarkerGroup, "Hostiles (<span id='mapControlHostileCount'>0</span>)");
		layerCount++;
	}
	
	if (HasPermission ("webapi.getanimalslocation")) {
		layerControl.addOverlay (animalsMarkerGroup, "Animals (<span id='mapControlAnimalsCount'>0</span>)");
		layerCount++;
	}
	
	if (HasPermission ("webapi.getplayerslocation")) {
		layerControl.addOverlay (playersOfflineMarkerGroup, "Players (offline) (<span id='mapControlOfflineCount'>0</span>)");
		layerControl.addOverlay (playersOnlineMarkerGroup, "Players (online) (<span id='mapControlOnlineCount'>0</span>)");
		layerCount++;
	}
	
	if (layerCount > 0) {
		layerControl.addTo(map);
	}




	var hostilesMappingList = {};
	var animalsMappingList = {};
	var playersMappingList = {};

	

	// ===============================================================================================
	// Player markers

	$(".leaflet-popup-pane").on('click.action', '.inventoryButton', function(event) {
		ShowInventoryDialog ($(this).data('steamid'));
	});

	var updatingMarkers = false;


	var setPlayerMarkers = function(data) {
		var onlineIds = [];
		updatingMarkers = true;
		$.each( data, function( key, val ) {
			var marker;
			if (playersMappingList.hasOwnProperty(val.steamid)) {
				marker = playersMappingList[val.steamid].currentPosMarker;
			} else {
				marker = L.marker([val.position.x, val.position.z], {icon: playerIcon}).bindPopup(
					"Player: " + $("<div>").text(val.name).html() +
					(HasPermission ("webapi.getplayerinventory") ?
						"<br/><a class='inventoryButton' data-steamid='"+val.steamid+"'>Show inventory</a>"
						: "")
				);
				marker.on("move", function ( e ) {
					if ( this.isPopupOpen () ) {
						map.flyTo (e.latlng, map.getZoom ());
					}
				});
				playersMappingList[val.steamid] = { online: !val.online };
			}
			
			if (val.online) {
				onlineIds.push (val.steamid);
			}
			
			oldpos = marker.getLatLng ();
			if ( playersMappingList[val.steamid].online != val.online ) {
				if (playersMappingList[val.steamid].online) {
					playersOnlineMarkerGroup.removeLayer(marker);
					playersOfflineMarkerGroup.addLayer(marker);
				} else {
					playersOfflineMarkerGroup.removeLayer(marker);
					playersOnlineMarkerGroup.addLayer(marker);
				}
			}
			if ( oldpos.lat != val.position.x || oldpos.lng != val.position.z ) {
				marker.setLatLng([val.position.x, val.position.z]);
				if (val.online) {
						marker.setOpacity(1.0);
				} else {
						marker.setOpacity(0.5);
				}
			}

			val.currentPosMarker = marker;
			playersMappingList[val.steamid] = val;
		});
		
		var online = 0;
		var offline = 0;
		$.each ( playersMappingList, function ( key, val ) {
			if ( val.online && onlineIds.indexOf (key) < 0 ) {
				var marker = val.currentPosMarker;
				playersOnlineMarkerGroup.removeLayer(marker);
				playersOfflineMarkerGroup.addLayer(marker);
				val.online = false;
			}
			if (val.online) {
				online++;
			} else {
				offline++;
			}
		});
		
		updatingMarkers = false;

		$( "#mapControlOnlineCount" ).text( online );
		$( "#mapControlOfflineCount" ).text( offline );
	}

	var updatePlayerTimeout;
	var playerUpdateCount = -1;
	var updatePlayerEvent = function() {
		playerUpdateCount++;
		
		$.getJSON( "../api/getplayerslocation" + ((playerUpdateCount % 15) == 0 ? "?offline=true" : ""))
		.done(setPlayerMarkers)
		.fail(function(jqxhr, textStatus, error) {
			console.log("Error fetching players list");
		})
		.always(function() {
			updatePlayerTimeout = window.setTimeout(updatePlayerEvent, 4000);
		});
	}

	tabs.on ("tabbedcontenttabopened", function (event, data) {
		if (data.newTab === "#tab_map") {
			if (HasPermission ("webapi.getplayerslocation")) {
				updatePlayerEvent ();
			}
		} else {
			window.clearTimeout (updatePlayerTimeout);
		}
	});
	
	if (tabs.tabbedContent ("isTabOpen", "tab_map")) {
		if (HasPermission ("webapi.getplayerslocation")) {
			updatePlayerEvent ();
		}
	}




	// ===============================================================================================
	// Hostiles markers

	var setHostileMarkers = function(data) {
		updatingMarkersHostile = true;
		
		var hostileCount = 0;

		hostilesMarkerGroup.clearLayers();
		
		$.each( data, function( key, val ) {
			var marker;
			if (hostilesMappingList.hasOwnProperty(val.id)) {
				marker = hostilesMappingList[val.id].currentPosMarker;
			} else {
				marker = L.marker([val.position.x, val.position.z], {icon: hostileIcon}).bindPopup(
					"Hostile: " + val.name
				);
				//hostilesMappingList[val.id] = { };
				hostilesMarkerGroup.addLayer(marker);
			}

			var bAbort = false;
			
			oldpos = marker.getLatLng ();

			//if ( oldpos.lat != val.position.x || oldpos.lng != val.position.z ) {
			//	hostilesMarkerGroup.removeLayer(marker);
				marker.setLatLng([val.position.x, val.position.z]);
				marker.setOpacity(1.0);
				hostilesMarkerGroup.addLayer(marker);
			//}

			val.currentPosMarker = marker;
			hostilesMappingList[val.id] = val;
			
			hostileCount++;
		});
		
		$( "#mapControlHostileCount" ).text( hostileCount );
		
		updatingMarkersHostile = false;
	}

	var updateHostileTimeout;
	var updateHostileEvent = function() {
		$.getJSON( "../api/gethostilelocation")
		.done(setHostileMarkers)
		.fail(function(jqxhr, textStatus, error) {
			console.log("Error fetching hostile list");
		})
		.always(function() {
			updateHostileTimeout = window.setTimeout(updateHostileEvent, 4000);
		});
	}

	tabs.on ("tabbedcontenttabopened", function (event, data) {
		if (data.newTab === "#tab_map") {
			if (HasPermission ("webapi.gethostilelocation")) {
				updateHostileEvent ();
			}
		} else {
			window.clearTimeout (updateHostileTimeout);
		}
	});
	
	if (tabs.tabbedContent ("isTabOpen", "tab_map")) {
		if (HasPermission ("webapi.gethostilelocation")) {
			updateHostileEvent ();
		}
	}



	// ===============================================================================================
	// Animals markers

	var setAnimalMarkers = function(data) {
		updatingMarkersAnimals = true;
		
		var animalsCount = 0;

		animalsMarkerGroup.clearLayers();
		
		$.each( data, function( key, val ) {
			var marker;
			if (animalsMappingList.hasOwnProperty(val.id)) {
				marker = animalsMappingList[val.id].currentPosMarker;
			} else {
				marker = L.marker([val.position.x, val.position.z], {icon: animalIcon}).bindPopup(
					"Animal: " + val.name
				);
				//animalsMappingList[val.id] = { };
				animalsMarkerGroup.addLayer(marker);
			}

			var bAbort = false;
			
			oldpos = marker.getLatLng ();

			//if ( oldpos.lat != val.position.x || oldpos.lng != val.position.z ) {
			//	animalsMarkerGroup.removeLayer(marker);
				marker.setLatLng([val.position.x, val.position.z]);
				marker.setOpacity(1.0);
				animalsMarkerGroup.addLayer(marker);
			//}

			val.currentPosMarker = marker;
			animalsMappingList[val.id] = val;
			
			animalsCount++;
		});
		
		$( "#mapControlAnimalsCount" ).text( animalsCount );
		
		updatingMarkersAnimals = false;
	}

	var updateAnimalsTimeout;
	var updateAnimalsEvent = function() {
		$.getJSON( "../api/getanimalslocation")
		.done(setAnimalMarkers)
		.fail(function(jqxhr, textStatus, error) {
			console.log("Error fetching animals list");
		})
		.always(function() {
			updateAnimalsTimeout = window.setTimeout(updateAnimalsEvent, 4000);
		});
	}

	tabs.on ("tabbedcontenttabopened", function (event, data) {
		if (data.newTab === "#tab_map") {
			if (HasPermission ("webapi.getanimalslocation")) {
				updateAnimalsEvent ();
			}
		} else {
			window.clearTimeout (updateAnimalsTimeout);
		}
	});
	
	if (tabs.tabbedContent ("isTabOpen", "tab_map")) {
		if (HasPermission ("webapi.getanimalslocation")) {
			updateAnimalsEvent ();
		}
	}

	
	
	
	
	
	
	
	
	// ===============================================================================================
	// Density markers

	var setDensityMarkers = function(data) {
		var densityCountAir = 0;
		var densityCountTerrain = 0;
		var densityCountNonTerrain = 0;

		densityMismatchMarkerGroupAir.clearLayers();
		densityMismatchMarkerGroupTerrain.clearLayers();
		densityMismatchMarkerGroupNonTerrain.clearLayers();
		
		
		var downloadCsv = true;
		var downloadJson = false;
		
		if (downloadJson) {
			var jsonAir = [];
			var jsonTerrain = [];
			var jsonNonTerrain = [];
		}
		if (downloadCsv) {
			var csvAir = "x;y;z;Density;IsTerrain;BvType\r\n";
			var csvTerrain = "x;y;z;Density;IsTerrain;BvType\r\n";
			var csvNonTerrain = "x;y;z;Density;IsTerrain;BvType\r\n";
		}
		
		$.each( data, function( key, val ) {
			if (val.bvtype == 0) {
				marker = L.marker([val.x, val.z]).bindPopup(
					"Density Mismatch: <br>Position: " + val.x + " " + val.y + " " + val.z + "<br>Density: " + val.density + "<br>isTerrain: " + val.terrain + "<br>bv.type: " + val.bvtype
				);
				densityMismatchMarkerGroupAir.addLayer(marker);
				densityCountAir++;
				if (downloadJson) {
					jsonAir.push (val);
				}
				if (downloadCsv) {
					csvAir += val.x + ";" + val.y + ";" + val.z + ";" + val.density + ";" + val.terrain + ";" + val.bvtype + "\r\n";
				}
			} else if (val.terrain) {
				marker = L.marker([val.x, val.z]).bindPopup(
					"Density Mismatch: <br>Position: " + val.x + " " + val.y + " " + val.z + "<br>Density: " + val.density + "<br>isTerrain: " + val.terrain + "<br>bv.type: " + val.bvtype
				);
				densityMismatchMarkerGroupTerrain.addLayer(marker);
				densityCountTerrain++;
				if (downloadJson) {
					jsonTerrain.push (val);
				}
				if (downloadCsv) {
					csvTerrain += val.x + ";" + val.y + ";" + val.z + ";" + val.density + ";" + val.terrain + ";" + val.bvtype + "\r\n";
				}
			} else {
				marker = L.marker([val.x, val.z]).bindPopup(
					"Density Mismatch: <br>Position: " + val.x + " " + val.y + " " + val.z + "<br>Density: " + val.density + "<br>isTerrain: " + val.terrain + "<br>bv.type: " + val.bvtype
				);
				densityMismatchMarkerGroupNonTerrain.addLayer(marker);
				densityCountNonTerrain++;
				if (downloadJson) {
					jsonNonTerrain.push (val);
				}
				if (downloadCsv) {
					csvNonTerrain += val.x + ";" + val.y + ";" + val.z + ";" + val.density + ";" + val.terrain + ";" + val.bvtype + "\r\n";
				}
			}
		});

		layerControl.addOverlay (densityMismatchMarkerGroupAir, "Density Mismatches Air (<span id='mapControlDensityCountAir'>0</span>)");
		layerControl.addOverlay (densityMismatchMarkerGroupTerrain, "Density Mismatches Terrain (<span id='mapControlDensityCountTerrain'>0</span>)");
		layerControl.addOverlay (densityMismatchMarkerGroupNonTerrain, "Density Mismatches NonTerrain (<span id='mapControlDensityCountNonTerrain'>0</span>)");

		$( "#mapControlDensityCountAir" ).text( densityCountAir );
		$( "#mapControlDensityCountTerrain" ).text( densityCountTerrain );
		$( "#mapControlDensityCountNonTerrain" ).text( densityCountNonTerrain );
		
		if (downloadJson) {
			download ("air-negative-density.json", JSON.stringify(jsonAir, null, '\t'));
			download ("terrain-positive-density.json", JSON.stringify(jsonTerrain, null, '\t'));
			download ("nonterrain-negative-density.json", JSON.stringify(jsonNonTerrain, null, '\t'));
		}
		if (downloadCsv) {
			download ("air-negative-density.csv", csvAir);
			download ("terrain-positive-density.csv", csvTerrain);
			download ("nonterrain-negative-density.csv", csvNonTerrain);
		}
		
		function download(filename, text) {
			var element = document.createElement('a');
			var file = new Blob([text], {type: 'text/plain'});
			element.href = URL.createObjectURL(file);
			element.download = filename;

			element.style.display = 'none';
			document.body.appendChild(element);

			element.click();

			document.body.removeChild(element);
		}
	}

	$.getJSON("densitymismatch.json")
	.done(setDensityMarkers)
	.fail(function(jqxhr, textStatus, error) {
		console.log("Error fetching density mismatch list");
	});

}





function StartMapModule () {
	$.getJSON( "../map/mapinfo.json")
	.done(function(data) {
		mapinfo.tilesize = data.blockSize;
		mapinfo.maxzoom = data.maxZoom;
	})
	.fail(function(jqxhr, textStatus, error) {
		console.log ("Error fetching map information");
	})
	.always(function() {
		InitMap ();
	});
}


