var L, _, turf, turfGetCoords, turfKinks, turfLineIntersect, turfLineSlice, turfMeta, turfNearestPointOnLine, turfRewind, turfTruncate, turfinside,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  slice = [].slice;

L = require('leaflet');

_ = require('lodash');

turf = require('@turf/helpers');

turfLineSlice = require('@turf/line-slice');

turfRewind = require('@turf/rewind');

turfinside = require('@turf/inside');

turfKinks = require('@turf/kinks');

turfMeta = require('@turf/meta');

turfNearestPointOnLine = require('@turf/nearest-point-on-line');

turfLineIntersect = require('@turf/line-intersect');

turfTruncate = require('@turf/truncate');

turfGetCoords = require('@turf/invariant').getCoords;

require('leaflet-geometryutil');

L.Cutting = {};

L.Cutting.Polyline = {};

L.Cutting.Polyline.Event = {};

L.Cutting.Polyline.Event.START = "cut:polyline:start";

L.Cutting.Polyline.Event.STOP = "cut:polyline:stop";

L.Cutting.Polyline.Event.SELECT = "cut:polyline:select";

L.Cutting.Polyline.Event.UNSELECT = "cut:polyline:unselect";

L.Cutting.Polyline.Event.CREATED = "cut:polyline:created";

L.Cutting.Polyline.Event.UPDATED = "cut:polyline:updated";

L.Cutting.Polyline.Event.SAVED = "cut:polyline:saved";

L.Cut.Polyline = (function(superClass) {
  extend(Polyline, superClass);

  Polyline.TYPE = 'cut-polyline';

  function Polyline(map, options) {
    this._constraintSnap = bind(this._constraintSnap, this);
    this._glue_on_click = bind(this._glue_on_click, this);
    this._disable_on_mouseup = bind(this._disable_on_mouseup, this);
    this._glue_on_enabled = bind(this._glue_on_enabled, this);
    this.glueMarker = bind(this.glueMarker, this);
    this.type = this.constructor.TYPE;
    this._map = map;
    Polyline.__super__.constructor.call(this, map);
    this.options = _.merge(this.options, options);
    this._featureGroup = options.featureGroup;
    this._uneditedLayerProps = [];
    if (!(this._featureGroup instanceof L.FeatureGroup)) {
      throw new Error('options.featureGroup must be a L.FeatureGroup');
    }
  }

  Polyline.prototype.enable = function() {
    if (this._enabled || !this._featureGroup.getLayers().length) {
      return;
    }
    this._availableLayers = new L.GeoJSON([], {
      style: function(feature) {
        return {
          color: feature.properties.color
        };
      }
    });
    this._activeLayer = void 0;
    this.fire('enabled', {
      handler: this.type
    });
    this._map.fire(L.Cutting.Polyline.Event.START, {
      handler: this.type
    });
    this._availableLayers.addTo(this._map);
    this._availableLayers.on('layeradd', this._enableLayer, this);
    this._availableLayers.on('layerremove', this._disableLayer, this);
    this._map.on(L.Cutting.Polyline.Event.SELECT, this._cutMode, this);
    this._map.on('zoomend moveend', this.refreshAvailableLayers, this);
    this._map.on('mousemove', this._selectLayer, this);
    this._map.on('mousemove', this._cutMode, this);
    return Polyline.__super__.enable.apply(this, arguments);
  };

  Polyline.prototype.disable = function() {
    if (!this._enabled) {
      return;
    }
    this._availableLayers.off('layeradd', this._enableLayer, this);
    this._availableLayers.off('layerremove', this._disableLayer, this);
    Polyline.__super__.disable.apply(this, arguments);
    this._map.fire(L.Cutting.Polyline.Event.STOP, {
      handler: this.type
    });
    this._map.off(L.Cutting.Polyline.Event.SELECT, this._startCutDrawing, this);
    if (this._activeLayer && this._activeLayer.cutting) {
      this._activeLayer.cutting.disable();
      if (this._activeLayer && this._activeLayer.cutting._poly) {
        this._map.removeLayer(this._activeLayer.cutting._poly);
        delete this._activeLayer.cutting._poly;
      }
      delete this._activeLayer.cutting;
    }
    if (this._activeLayer && this._activeLayer.editing) {
      this._activeLayer.editing.disable();
      if (this._activeLayer && this._activeLayer.editing._poly) {
        this._map.removeLayer(this._activeLayer.editing._poly);
      }
    }
    if (this._activeLayer && this._activeLayer._polys) {
      this._activeLayer._polys.clearLayers();
      delete this._activeLayer._polys;
      delete this._activeLayer.editing;
      delete this._activeLayer.glue;
    }
    if (!this._featureGroup._map) {
      this._map.addLayer(this._featureGroup);
    }
    this._availableLayers.eachLayer((function(_this) {
      return function(l) {
        return _this._map.removeLayer(l);
      };
    })(this));
    this._availableLayers.length = 0;
    this._startPoint = null;
    this._activeLayer = null;
    this._map.off(L.Draw.Event.DRAWVERTEX, this._finishDrawing, this);
    this._map.off('click', this._finishDrawing, this);
    this._map.off('mousemove', this._selectLayer, this);
    this._map.off('mousemove', this._cutMode, this);
    this._map.off('zoomend moveend', this.refreshAvailableLayers, this);
    this.fire('disabled', {
      handler: this.type
    });
  };

  Polyline.prototype.addHooks = function() {
    this.refreshAvailableLayers();
    return this._map.removeLayer(this._featureGroup);
  };

  Polyline.prototype.refreshAvailableLayers = function() {
    var addList, geojson, j, k, l, len, len1, newLayers, removeList;
    this._featureGroup.addTo(this._map);
    if (!this._featureGroup.getLayers().length) {
      return;
    }
    if (typeof this._featureGroup.search === 'function') {
      newLayers = new L.FeatureGroup(this._featureGroup.search(this._map.getBounds()));
      removeList = this._availableLayers.getLayers().filter(function(layer) {
        return !newLayers.hasLayer(layer);
      });
      if (removeList.length) {
        for (j = 0, len = removeList.length; j < len; j++) {
          l = removeList[j];
          this._availableLayers.removeLayer(l);
        }
      }
      addList = newLayers.getLayers().filter((function(_this) {
        return function(layer) {
          return !_this._availableLayers.hasUUIDLayer(layer);
        };
      })(this));
      if (addList.length) {
        for (k = 0, len1 = addList.length; k < len1; k++) {
          l = addList[k];
          if (!this._availableLayers.hasUUIDLayer(l)) {
            geojson = l.toGeoJSON();
            geojson.properties.color = l.options.color;
            this._availableLayers.addData(geojson);
          }
        }
      }
    } else {
      this._availableLayers = this._featureGroup;
    }
    return this._map.removeLayer(this._featureGroup);
  };

  Polyline.prototype.removeHooks = function() {
    return this._availableLayers.eachLayer(this._disableLayer, this);
  };

  Polyline.prototype.save = function() {
    var newLayers;
    newLayers = [];
    this._map.addLayer(this._featureGroup);
    if (this._activeLayer._polys) {
      this._activeLayer._polys.eachLayer((function(_this) {
        return function(l) {
          return _this._featureGroup.addData(l.toGeoJSON());
        };
      })(this));
      this._activeLayer._polys.clearLayers();
      delete this._activeLayer._polys;
      newLayers = this._featureGroup.getLayers().slice(-2);
      this._map.fire(L.Cutting.Polyline.Event.SAVED, {
        oldLayer: {
          uuid: this._activeLayer.feature.properties.uuid,
          type: this._activeLayer.feature.properties.type
        },
        layers: newLayers
      });
      this._map.removeLayer(this._activeLayer);
    }
  };

  Polyline.prototype._enableLayer = function(e) {
    var layer, pathOptions;
    layer = e.layer || e.target || e;
    layer.options.original = L.extend({}, layer.options);
    if (this.options.disabledPathOptions) {
      pathOptions = L.Util.extend({}, this.options.disabledPathOptions);
      if (pathOptions.maintainColor) {
        pathOptions.color = layer.options.color;
        pathOptions.fillColor = layer.options.fillColor;
      }
      layer.options.disabled = pathOptions;
    }
    if (this.options.selectedPathOptions) {
      pathOptions = L.Util.extend({}, this.options.selectedPathOptions);
      if (pathOptions.maintainColor) {
        pathOptions.color = layer.options.color;
        pathOptions.fillColor = layer.options.fillColor || pathOptions.color;
      }
      pathOptions.fillOpacity = layer.options.fillOpacity || pathOptions.fillOpacity;
      layer.options.selected = pathOptions;
    }
    return layer.setStyle(layer.options.disabled);
  };

  Polyline.prototype._selectLayer = function(e) {
    var found, mouseLatLng;
    mouseLatLng = e.latlng;
    found = false;
    this._availableLayers.eachLayer((function(_this) {
      return function(layer) {
        var mousePoint, polygon;
        mousePoint = mouseLatLng.toTurfFeature();
        polygon = layer.toTurfFeature();
        if (turfinside["default"](mousePoint, polygon)) {
          if (layer !== _this._activeLayer) {
            _this._activate(layer, mouseLatLng);
          }
          found = true;
        }
      };
    })(this));
    if (found) {
      return;
    }
    if (this._activeLayer && !this._activeLayer.glue) {
      return this._unselectLayer(this._activeLayer);
    }
  };

  Polyline.prototype._unselectLayer = function(e) {
    var layer;
    layer = e.layer || e.target || e;
    layer.selected = false;
    if (this.options.selectedPathOptions) {
      layer.setStyle(layer.options.disabled);
    }
    if (layer.cutting) {
      layer.cutting.disable();
      delete layer.cutting;
    }
    this._map.on('mousemove', this._selectLayer, this);
    return this._activeLayer = null;
  };

  Polyline.prototype._disableLayer = function(e) {
    var layer;
    layer = e.layer || e.target || e;
    layer.selected = false;
    if (this.options.selectedPathOptions) {
      layer.setStyle(layer.options.original);
    }
    delete layer.options.disabled;
    delete layer.options.selected;
    return delete layer.options.original;
  };

  Polyline.prototype._activate = function(e, latlng) {
    var layer;
    layer = e.target || e.layer || e;
    if (!layer.selected) {
      layer.selected = true;
      layer.setStyle(layer.options.selected);
      if (this._activeLayer) {
        this._unselectLayer(this._activeLayer);
      }
      this._activeLayer = layer;
      return this._map.fire(L.Cutting.Polyline.Event.SELECT, {
        layer: this._activeLayer,
        latlng: latlng
      });
    } else {
      layer.selected = false;
      layer.setStyle(layer.options.disabled);
      this._activeLayer.cutting.disable();
      delete this._activeLayer.cutting;
      this._activeLayer = null;
      return this._map.fire(L.Cutting.Polyline.Event.UNSELECT, {
        layer: layer
      });
    }
  };

  Polyline.prototype._cutMode = function() {
    var opts, pathOptions;
    if (!this._activeLayer) {
      return;
    }
    if (!this._activeLayer.cutting) {
      this._activeLayer.cutting = new L.Draw.Polyline(this._map);
      opts = _.merge(this.options.snap, {
        guideLayers: [this._activeLayer]
      });
      this._activeLayer.cutting.setOptions(opts);
      if (this.options.cuttingPathOptions) {
        pathOptions = L.Util.extend({}, this.options.cuttingPathOptions);
        if (pathOptions.maintainColor) {
          pathOptions.color = this._activeLayer.options.color;
          pathOptions.fillColor = this._activeLayer.options.fillColor;
        }
        pathOptions.fillOpacity = 0.5;
        this._activeLayer.options.cutting = pathOptions;
      }
      this._activeLayer.cutting.enable();
    }
    if (!this._startPoint) {
      this._activeLayer.cutting._mouseMarker.on('move', this.glueMarker, this);
      return this._activeLayer.cutting._mouseMarker.on('snap', this._glue_on_enabled, this);
    }
  };

  Polyline.prototype.glueMarker = function(e) {
    var closest, marker;
    marker = e.target || this._activeLayer.cutting._mouseMarker;
    marker.glue = true;
    closest = L.GeometryUtil.closest(this._map, this._activeLayer, e.latlng, false);
    marker._latlng = L.latLng(closest.lat, closest.lng);
    return marker.update();
  };

  Polyline.prototype._glue_on_enabled = function() {
    this._activeLayer.glue = true;
    this._activeLayer.cutting._snapper.unwatchMarker(this._activeLayer.cutting._mouseMarker);
    this._activeLayer.cutting._mouseMarker.on('mousedown', this._glue_on_click, this);
    return this._map.on('click', this._glue_on_click, this);
  };

  Polyline.prototype._disable_on_mouseup = function(e) {
    this._activeLayer.cutting._enableNewMarkers();
    this._activeLayer.cutting._clickHandled = null;
    return L.DomEvent.stopPropagation(e);
  };

  Polyline.prototype._glue_on_click = function(e) {
    var latlngs, marker, markerCount, poly, snapPoint;
    if (!this._activeLayer.cutting._mouseDownOrigin && !this._activeLayer.cutting._markers.length) {
      this._activeLayer.cutting._mouseMarker;
      this._activeLayer.cutting.addVertex(this._activeLayer.cutting._mouseMarker._latlng);
    }
    if (this._activeLayer.cutting._markers) {
      markerCount = this._activeLayer.cutting._markers.length;
      marker = this._activeLayer.cutting._markers[markerCount - 1];
      if (markerCount === 1) {
        this._activeLayer.cutting._snapper.addOrigin(this._activeLayer.cutting._markers[0]);
        L.DomUtil.addClass(this._activeLayer.cutting._markers[0]._icon, 'marker-origin');
      }
      if (marker) {
        L.DomUtil.addClass(marker._icon, 'marker-snapped');
        marker.setLatLng(this._activeLayer.cutting._mouseMarker._latlng);
        poly = this._activeLayer.cutting._poly;
        latlngs = poly.getLatLngs();
        latlngs.splice(-1, 1);
        this._activeLayer.cutting._poly.setLatLngs(latlngs);
        this._activeLayer.cutting._poly.addLatLng(this._activeLayer.cutting._mouseMarker._latlng);
        snapPoint = this._map.latLngToLayerPoint(marker._latlng);
        this._activeLayer.cutting._updateGuide(snapPoint);
        this._activeLayer.setStyle(this._activeLayer.options.cutting);
        this._activeLayer.glue = false;
        marker.on('mouseup', this._disable_on_mouseup, this);
        this._map.off('mousemove', this._selectLayer, this);
        this._startPoint = marker;
        this._activeLayer.cutting._mouseMarker.off('move', this.glueMarker, this);
        this._activeLayer.cutting._mouseMarker.off('mousedown', this._glue_on_click, this);
        this._map.off('click', this._glue_on_click, this);
        this._activeLayer.cutting._snapper.watchMarker(this._activeLayer.cutting._mouseMarker);
        this._activeLayer.cutting._mouseMarker.off('snap', this._glue_on_enabled, this);
        this._activeLayer.cutting._mouseMarker.on('snap', (function(_this) {
          return function(e) {
            _this._map.on(L.Draw.Event.DRAWVERTEX, _this._finishDrawing, _this);
            _this._map.on('click', _this._finishDrawing, _this);
            return _this._activeLayer.cutting._mouseMarker.off('move', _this._constraintSnap, _this);
          };
        })(this));
        return this._activeLayer.cutting._mouseMarker.on('unsnap', (function(_this) {
          return function(e) {
            _this._activeLayer.cutting._mouseMarker.on('move', _this._constraintSnap, _this);
            _this._map.off(L.Draw.Event.DRAWVERTEX, _this._finishDrawing, _this);
            return _this._map.off('click', _this._finishDrawing, _this);
          };
        })(this));
      }
    }
  };

  Polyline.prototype._constraintSnap = function(e) {
    var marker, markerPoint, polygon, snapPoint;
    marker = this._activeLayer.cutting._mouseMarker;
    markerPoint = marker._latlng.toTurfFeature();
    polygon = this._activeLayer.toTurfFeature();
    if (!turfinside["default"](markerPoint, polygon, {
      ignoreBoundary: true
    })) {
      this.glueMarker({
        target: this._activeLayer.cutting._mouseMarker,
        latlng: this._activeLayer.cutting._mouseMarker._latlng
      });
      snapPoint = this._map.latLngToLayerPoint(marker._latlng);
      this._activeLayer.cutting._updateGuide(snapPoint);
      return this._map.on('click', this._finishDrawing, this);
    }
  };

  Polyline.prototype._finishDrawing = function(e) {
    var lastMarker, latlng, latlngs, marker, markerCount, poly;
    markerCount = this._activeLayer.cutting._markers.length;
    marker = this._activeLayer.cutting._markers[markerCount - 1];
    if (L.Browser.touch) {
      lastMarker = this._activeLayer.cutting._markers.pop();
      poly = this._activeLayer.cutting._poly;
      latlngs = poly.getLatLngs();
      latlng = latlngs.splice(-1, 1)[0];
      this._activeLayer.cutting._poly.setLatLngs(latlngs);
    }
    if (!e.layers || L.Browser.touch) {
      this._activeLayer.cutting._markers.push(this._activeLayer.cutting._createMarker(this._activeLayer.cutting._mouseMarker._latlng));
      this._activeLayer.cutting._poly.addLatLng(this._activeLayer.cutting._mouseMarker._latlng);
    }
    return this._stopCutDrawing();
  };

  Polyline.prototype._cut = function(layer, polyline) {
    var c, firstPoint, firstSegment, firstVertex, i, intersect, intersectingPoints, j, k, kinks, lastPoint, lastSegment, lastVertex, len, lineString1, lineString2, m, outerRing, outerRingCoords, polygon1, polygon2, polylineSplitter, ref, ref1, ref2, removingCoords, s1, s2, segmentSplit, simpleFirstVertex, simpleLastVertex, slice1, slice2, slice2Coords, sliceIndex, splitter, splitterCoords, startIndex, toRemove;
    outerRing = layer.outerRingAsTurfLineString();
    ref = polyline.getLatLngs(), firstPoint = ref[0], lastPoint = ref[ref.length - 1];
    slice1 = turfLineSlice(firstPoint.toTurfFeature(), lastPoint.toTurfFeature(), outerRing);
    slice1 = turfRewind(slice1, true);
    ref1 = slice1.geometry.coordinates, firstVertex = ref1[0], removingCoords = 3 <= ref1.length ? slice.call(ref1, 1, j = ref1.length - 1) : (j = 1, []), lastVertex = ref1[j++];
    i = 0;
    startIndex = null;
    outerRingCoords = turfGetCoords(outerRing).slice(0);
    slice2Coords = [[]];
    sliceIndex = 0;
    if (!removingCoords.length) {
      firstSegment = turfNearestPointOnLine["default"](outerRing, turf.point(firstVertex));
      lastSegment = turfNearestPointOnLine["default"](outerRing, turf.point(lastVertex));
      if (firstSegment.properties.index === lastSegment.properties.index) {
        segmentSplit = null;
        turfMeta.segmentEach(outerRing, function(currentSegment, featureIndex, multiFeatureIndex, geometryIndex, segmentIndex) {
          if (segmentIndex === firstSegment.properties.index) {
            return segmentSplit = turfGetCoords(currentSegment);
          }
        });
      }
    }
    for (k = 0, len = outerRingCoords.length; k < len; k++) {
      c = outerRingCoords[k];
      toRemove = removingCoords.filter(function(coord) {
        return coord[0] === c[0] && coord[1] === c[1];
      });
      if (toRemove.length === 1) {
        if (sliceIndex === 0) {
          sliceIndex++;
          slice2Coords.push([]);
        }
        continue;
      }
      if ((segmentSplit != null) && segmentSplit[0][0] === c[0] && segmentSplit[0][1] === c[1]) {
        slice2Coords[sliceIndex].push(c);
        if (sliceIndex === 0) {
          sliceIndex++;
          slice2Coords.push([]);
        }
        continue;
      }
      slice2Coords[sliceIndex].push(c);
    }
    splitter = polyline.toTurfFeature();
    splitter = turfRewind(splitter);
    ref2 = splitter.geometry.coordinates, s1 = ref2[0], splitterCoords = 3 <= ref2.length ? slice.call(ref2, 1, m = ref2.length - 1) : (m = 1, []), s2 = ref2[m++];
    splitterCoords.unshift(lastVertex);
    splitterCoords.push(firstVertex);
    splitter = turf.lineString(splitterCoords);
    intersectingPoints = turfTruncate["default"](turfLineIntersect["default"](splitter, outerRing), {
      precision: 3
    });
    if (intersectingPoints.features.length > 0) {
      simpleFirstVertex = turfGetCoords(turfTruncate["default"](firstPoint.toTurfFeature(), {
        precision: 3
      }));
      simpleLastVertex = turfGetCoords(turfTruncate["default"](lastPoint.toTurfFeature(), {
        precision: 3
      }));
      intersect = intersectingPoints.features.filter(function(feature) {
        var coord;
        coord = turfGetCoords(feature);
        return !(coord[0] === simpleFirstVertex[0] && coord[1] === simpleFirstVertex[1]) && !(coord[0] === simpleLastVertex[0] && coord[1] === simpleLastVertex[1]);
      });
      if (intersect.length > 0) {
        throw new Error("kinks");
      }
    }
    lineString1 = this.turfLineMerge(slice1, splitter);
    kinks = turfKinks["default"](lineString1);
    if (kinks.features.length > 0) {
      throw new Error("kinks");
    }
    slice2 = slice2Coords.map(function(part) {
      if (!part.length) {
        return;
      }
      if (part.length === 1) {
        return turf.point(part[0]);
      } else {
        return turf.lineString(part);
      }
    }).filter(function(vertex) {
      return vertex;
    });
    slice2.splice(1, 0, splitter);
    lineString2 = this.turfLineMerge.apply(this, slice2);
    kinks = turfKinks["default"](lineString2);
    if (kinks.features.length > 0) {
      splitter = turfRewind(splitter, true);
      slice2.splice(1, 1, splitter);
      lineString2 = this.turfLineMerge.apply(this, slice2);
    }
    polygon1 = new L.polygon([], {
      fillColor: '#FFC107',
      fillOpacity: 0.9,
      opacity: 1,
      weight: 1,
      color: 'black'
    });
    polygon1.fromTurfFeature(lineString1);
    polygon2 = new L.polygon([], {
      fillColor: '#009688',
      fillOpacity: 0.9,
      opacity: 1,
      weight: 1,
      color: 'black'
    });
    polygon2.fromTurfFeature(lineString2);
    polylineSplitter = new L.Polyline([]);
    polylineSplitter.fromTurfFeature(splitter);
    return [polygon1, polygon2, polylineSplitter];
  };

  Polyline.prototype._stopCutDrawing = function() {
    var drawnPolyline, e, polygon1, polygon2, ref, splitter;
    drawnPolyline = this._activeLayer.cutting._poly;
    try {
      ref = this._cut(this._activeLayer, drawnPolyline), polygon1 = ref[0], polygon2 = ref[1], splitter = ref[2];
      this._activeLayer.cutting.disable();
      this._map.removeLayer(this._activeLayer);
      this._activeLayer._polys = new L.LayerGroup();
      this._activeLayer._polys.addTo(this._map);
      this._activeLayer._polys.addLayer(polygon1);
      this._activeLayer._polys.addLayer(polygon2);
      this._map.fire(L.Cutting.Polyline.Event.CREATED, {
        layers: [polygon1, polygon2]
      });
      this._activeLayer.editing = new L.Edit.Poly(splitter);
      this._activeLayer.editing._poly.options.editing = {
        color: '#fe57a1',
        dashArray: '10, 10'
      };
      this._activeLayer.editing._poly.addTo(this._map);
      this._activeLayer.editing.enable();
      this._activeLayer.editing._poly.on('editstart', (function(_this) {
        return function(e) {
          var j, len, marker, ref1, results;
          ref1 = _this._activeLayer.editing._verticesHandlers[0]._markers;
          results = [];
          for (j = 0, len = ref1.length; j < len; j++) {
            marker = ref1[j];
            marker.off('move', _this._moveMarker, _this);
            if (L.stamp(marker) === L.stamp(_this._activeLayer.editing._verticesHandlers[0]._markers[0]) || L.stamp(marker) === L.stamp(_this._activeLayer.editing._verticesHandlers[0]._markers.slice(0).pop())) {
              marker.on('move', _this.glueMarker, _this);
            }
            results.push(marker.on('move', _this._moveMarker, _this));
          }
          return results;
        };
      })(this));
      return this._map.off('click', this._finishDrawing, this);
    } catch (_error) {
      e = _error;
      if (e.message === "kinks") {
        this._activeLayer.cutting.disable();
        return this._unselectLayer(this._activeLayer);
      }
    }
  };

  Polyline.prototype._moveMarker = function(e) {
    var drawnPolyline, latlng, marker, markerPoint, polygon, polygon1, polygon2, ref;
    marker = e.marker || e.target || e;
    drawnPolyline = this._activeLayer.editing._poly;
    if (!marker.glue) {
      latlng = marker._latlng;
      markerPoint = latlng.toTurfFeature();
      polygon = this._activeLayer.toTurfFeature();
      if (!turfinside["default"](markerPoint, polygon, {
        ignoreBoundary: true
      }) && marker._oldLatLng) {
        marker._latlng = marker._oldLatLng;
        marker.update();
      }
    }
    try {
      ref = this._cut(this._activeLayer, drawnPolyline), polygon1 = ref[0], polygon2 = ref[1];
      marker._oldLatLng = marker._latlng;
      this._activeLayer._polys.clearLayers();
      this._map.removeLayer(this._activeLayer);
      polygon1.addTo(this._map);
      if (polygon2 !== void 0) {
        polygon2.addTo(this._map);
        this._activeLayer._polys.addLayer(polygon2);
        this._activeLayer._polys.addLayer(polygon1);
        this._activeLayer.editing._poly.bringToFront();
        return this._map.fire(L.Cutting.Polyline.Event.UPDATED, {
          layers: [polygon1, polygon2]
        });
      }
    } catch (_error) {}
  };

  Polyline.prototype._hasAvailableLayers = function() {
    return this._availableLayers.length !== 0;
  };

  Polyline.prototype.turfLineMerge = function() {
    var coord, coords, firstVertex, j, k, lastCoord, lastVertex, len, len1, lineString, lineStringCoords, lineStrings;
    lineStrings = 1 <= arguments.length ? slice.call(arguments, 0) : [];
    coords = [];
    for (j = 0, len = lineStrings.length; j < len; j++) {
      lineString = lineStrings[j];
      if (!(lineString.type === 'Feature' && lineString.type === 'Feature')) {
        throw new Error('inputs must be LineString Features');
      }
      lineStringCoords = turfGetCoords(lineString).slice(0);
      if (lineString.geometry.type === 'Point') {
        lineStringCoords = [lineStringCoords];
      }
      for (k = 0, len1 = lineStringCoords.length; k < len1; k++) {
        coord = lineStringCoords[k];
        lastCoord = coords.slice(0).pop();
        if (!(lastCoord && lastCoord[0] === coord[0] && lastCoord[1] === coord[1])) {
          coords.push(coord);
        }
      }
    }
    firstVertex = coords.slice(0).shift();
    lastVertex = coords.slice(0).pop();
    if (!(firstVertex[0] === lastVertex[0] && firstVertex[1] === lastVertex[1])) {
      coords.push(firstVertex);
    }
    return turf.lineString(coords);
  };

  return Polyline;

})(L.Handler);

L.Cut.Polyline.include(L.Mixin.Events);

// ---
// generated by coffee-script 1.9.2
