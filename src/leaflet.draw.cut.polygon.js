var L, _, turf, turfDifference, turfIntersect,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

L = require('leaflet');

_ = require('lodash');

turf = require('@turf/helpers');

turfIntersect = require('@turf/intersect');

turfDifference = require('@turf/difference');

L.Cutting = {};

L.Cutting.Event = {};

L.Cutting.Event.START = "cut:start";

L.Cutting.Event.STOP = "cut:stop";

L.Cutting.Event.SELECT = "cut:select";

L.Cutting.Event.UNSELECT = "cut:unselect";

L.Cut.Polygon = (function(superClass) {
  extend(Polygon, superClass);

  Polygon.TYPE = 'cut-polygon';

  function Polygon(map, options) {
    this.type = this.constructor.TYPE;
    this._map = map;
    Polygon.__super__.constructor.call(this, map);
    this.options = _.merge(this.options, options);
    this._featureGroup = options.featureGroup;
    this._activeLayer = void 0;
    this._uneditedLayerProps = [];
    if (!(this._featureGroup instanceof L.FeatureGroup)) {
      throw new Error('options.featureGroup must be a L.FeatureGroup');
    }
  }

  Polygon.prototype.enable = function() {
    if (this._enabled || !this._hasAvailableLayers()) {
      return;
    }
    this.fire('enabled', {
      handler: this.type
    });
    this._map.fire(L.Cutting.Event.START, {
      handler: this.type
    });
    Polygon.__super__.enable.apply(this, arguments);
    this._featureGroup.on('layeradd', this._enableLayer, this);
    this._featureGroup.on('layerremove', this._disableLayer, this);
    return this._map.on(L.Cutting.Event.SELECT, this._startCutDrawing, this);
  };

  Polygon.prototype.disable = function() {
    if (!this._enabled) {
      return;
    }
    this._featureGroup.off('layeradd', this._enableLayer, this);
    this._featureGroup.off('layerremove', this._disableLayer, this);
    Polygon.__super__.disable.apply(this, arguments);
    this._map.fire(L.Cutting.Event.STOP, {
      handler: this.type
    });
    this._map.off(L.Cutting.Event.SELECT, this._startCutDrawing, this);
    this._map.off(L.Cutting.Event.UNSELECT, this._stopCutDrawing, this);
    this._map.off(L.Draw.Event.CREATED, this._stopCutDrawing, this);
    this.fire('disabled', {
      handler: this.type
    });
  };

  Polygon.prototype.addHooks = function() {
    this._featureGroup.eachLayer(this._enableLayer, this);
    return this._featureGroup.getLayers()[0].fire('click');
  };

  Polygon.prototype._intersect = function(layer1, layer2) {
    var intersection, polygon1, polygon2;
    polygon1 = layer1.toTurfFeature();
    polygon2 = layer2.toTurfFeature();
    intersection = turfIntersect(polygon1, polygon2);
    return L.geoJSON(intersection, {
      style: function() {
        return {
          fill: false,
          color: 'green',
          dashArray: '8, 8',
          opacity: 1
        };
      }
    });
  };

  Polygon.prototype._difference = function(layer1, layer2) {
    var difference, polygon1, polygon2;
    polygon1 = layer1.toTurfFeature();
    polygon2 = layer2.toTurfFeature();
    difference = turfDifference(polygon1, polygon2);
    return L.geoJSON(difference, {
      style: function() {
        return {
          fillColor: 'grey',
          opacity: 0.8
        };
      }
    });
  };

  Polygon.prototype.removeHooks = function() {
    return this._featureGroup.eachLayer(this._disableLayer, this);
  };

  Polygon.prototype.save = function() {
    this._featureGroup.eachLayer((function(_this) {
      return function(l) {
        return _this._map.removeLayer(l);
      };
    })(this));
    this._featureGroup.addLayer(this._activeLayer._poly);
    this._featureGroup.addTo(this._map);
    delete this._activeLayer._poly;
    delete this._activeLayer;
    console.error(this._featureGroup);
  };

  Polygon.prototype._enableLayer = function(e) {
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
        pathOptions.fillColor = layer.options.fillColor;
      }
      layer.options.selected = pathOptions;
    }
    layer.setStyle(layer.options.disabled);
    layer.on('click', this._activate, this);
    return layer.on('touchstart', this._activate, this);
  };

  Polygon.prototype._disableLayer = function(e) {
    var layer;
    layer = e.layer || e.target || e;
    layer.selected = false;
    if (this.options.selectedPathOptions) {
      layer.setStyle(layer.options.original);
    }
    layer.off('click', this._activate, this);
    layer.off('touchstart', this._activate, this);
    delete layer.options.disabled;
    delete layer.options.selected;
    return delete layer.options.original;
  };

  Polygon.prototype._activate = function(e) {
    var layer;
    layer = e.target;
    if (!layer.selected) {
      layer.selected = true;
      layer.setStyle(layer.options.selected);
      if (this._activeLayer) {
        this._activeLayer.selected = false;
        this._activeLayer.setStyle(this._activeLayer.options.disabled);
      }
      this._activeLayer = layer;
      return this._map.fire(L.Cutting.Event.SELECT, {
        layer: this._activeLayer
      });
    } else {
      layer.selected = false;
      layer.setStyle(layer.options.disabled);
      this._activeLayer = null;
      return this._map.fire(L.Cutting.Event.UNSELECT, {
        layer: layer
      });
    }
  };

  Polygon.prototype._startCutDrawing = function(e) {
    var pathOptions;
    this._backupLayer(this._activeLayer);
    this._map.on(L.Draw.Event.CREATED, this._stopCutDrawing, this);
    this._activeLayer.cutting = new L.Draw.Polygon(this._map);
    if (this.options.cuttingPathOptions) {
      pathOptions = L.Util.extend({}, this.options.cuttingPathOptions);
      if (pathOptions.maintainColor) {
        pathOptions.color = layer.options.color;
        pathOptions.fillColor = layer.options.fillColor;
      }
      this._activeLayer.options.cutting = pathOptions;
    }
    return this._activeLayer.cutting.enable();
  };

  Polygon.prototype._stopCutDrawing = function(e) {
    var closestLayer, closestLayers, cuttingShape, editShape, i, intersectShape, len;
    cuttingShape = e.layer;
    this._map.off(L.Draw.Event.CREATED, this._stopCutDrawing, this);
    this._activeLayer.cutting.disable();
    if (this._featureGroup.search === "function") {
      closestLayers = this._featureGroup.search(cuttingShape.getBounds());
    } else {
      closestLayers = this._featureGroup.getLayers();
    }
    for (i = 0, len = closestLayers.length; i < len; i++) {
      closestLayer = closestLayers[i];
      intersectShape = this._intersect(closestLayer, cuttingShape);
      console.error(intersectShape);
      this._map.removeLayer(closestLayer._poly);
      closestLayer._poly = this._difference(closestLayer, intersectShape);
      closestLayer._poly.addTo(this._map);
    }
    console.error(shape.getLayers()[0]);
    editShape = new L.Edit.Poly(shape.getLayers()[0]);
    editShape._poly.addTo(this._map);
    editShape._poly.on('editdrag', this._moveMarker, this);
    editShape.enable();
    return this._moveMarker({
      layer: shape
    });
  };

  Polygon.prototype._moveMarker = function(e) {
    var closestLayer, closestLayers, cuttingShape, i, intersectShape, len, results;
    cuttingShape = e.target || e.layer;
    console.error('move', e);
    console.error(this._featureGroup);
    if (this._featureGroup.search === "function") {
      closestLayers = this._featureGroup.search(cuttingShape.getBounds());
    } else {
      closestLayers = this._featureGroup.getLayers();
    }
    results = [];
    for (i = 0, len = closestLayers.length; i < len; i++) {
      closestLayer = closestLayers[i];
      intersectShape = this._intersect(closestLayer, cuttingShape);
      this._map.removeLayer(closestLayer._poly);
      closestLayer._poly = this._difference(closestLayer, intersectShape);
      results.push(closestLayer._poly.addTo(this._map));
    }
    return results;
  };

  Polygon.prototype._backupLayer = function(layer) {
    var id;
    id = L.Util.stamp(layer);
    if (!this._uneditedLayerProps[id]) {
      if (layer instanceof L.Polyline || layer instanceof L.Polygon || layer instanceof L.Rectangle) {
        return this._uneditedLayerProps[id] = {
          latlngs: L.LatLngUtil.cloneLatLngs(layer.getLatLngs())
        };
      } else if (layer instanceof L.Circle) {
        return this._uneditedLayerProps[id] = {
          latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng()),
          radius: layer.getRadius()
        };
      } else if (layer instanceof L.Marker || layer instanceof L.CircleMarker) {
        return this._uneditedLayerProps[id] = {
          latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())
        };
      }
    }
  };

  Polygon.prototype._hasAvailableLayers = function() {
    return this._featureGroup.getLayers().length !== 0;
  };

  return Polygon;

})(L.Handler);

L.Cut.include(L.Mixin.Events);

// ---
// generated by coffee-script 1.9.2
