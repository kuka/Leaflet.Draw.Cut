L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfIntersect = require '@turf/intersect'
turfDifference = require '@turf/difference'

L.Cutting = {}
L.Cutting.Event = {}
L.Cutting.Event.START = "cut:start"
L.Cutting.Event.STOP = "cut:stop"
L.Cutting.Event.SELECT = "cut:select"
L.Cutting.Event.UNSELECT = "cut:unselect"
# L.Cutting.Event.SELECTED = "layerSelection:selected"

class L.Cut.Polygon extends L.Handler
  @TYPE: 'cut-polygon'

  constructor: (map, options) ->
    @type = @constructor.TYPE
    @_map = map
    super map
    @options = _.merge @options, options

    @_featureGroup = options.featureGroup
    @_activeLayer = undefined
    @_uneditedLayerProps = []

    if !(@_featureGroup instanceof L.FeatureGroup)
      throw new Error('options.featureGroup must be a L.FeatureGroup')

  enable: ->
    if @_enabled or !@_hasAvailableLayers()
      return

    @fire 'enabled', handler: @type

    @_map.fire L.Cutting.Event.START, handler: @type

    super

    @_featureGroup.on 'layeradd', @_enableLayer, @
    @_featureGroup.on 'layerremove', @_disableLayer, @

    @_map.on L.Cutting.Event.SELECT, @_startCutDrawing, @

    # @_map.on L.Cutting.Event.UNSELECT, @_cancelCutDrawing, @
    # @_map.on L.Draw.Event.DRAWSTART, @_stopCutDrawing, @
    # @_map.on L.Draw.Event.CREATED, @_stopCutDrawing, @

  disable: ->
    if !@_enabled
      return
    @_featureGroup.off 'layeradd', @_enableLayer, @
    @_featureGroup.off 'layerremove', @_disableLayer, @

    super

    @_map.fire L.Cutting.Event.STOP, handler: @type

    @_map.off L.Cutting.Event.SELECT, @_startCutDrawing, @
    @_map.off L.Cutting.Event.UNSELECT, @_stopCutDrawing, @
    @_map.off L.Draw.Event.CREATED, @_stopCutDrawing, @


    @fire 'disabled', handler: @type
    return

  addHooks: ->
    @_featureGroup.eachLayer @_enableLayer, @

    #TMP
    @_featureGroup.getLayers()[0].fire 'click'

  # Returns a MultiPolygon
  _intersect: (layer1, layer2) ->

    polygon1 = layer1.toTurfFeature()
    polygon2 = layer2.toTurfFeature()
    intersection = turfIntersect(polygon1, polygon2)

    L.geoJSON intersection,
      style: () ->
        fill: false, color: 'green', dashArray: '8, 8', opacity: 1

  #layer1 - layer2
  _difference: (layer1, layer2) ->

    polygon1 = layer1.toTurfFeature()
    polygon2 = layer2.toTurfFeature()
    difference = turfDifference(polygon1, polygon2)

    L.geoJSON difference,
      style: () ->
        fillColor: 'grey', opacity: 0.8


  removeHooks: ->
    @_featureGroup.eachLayer @_disableLayer, @

  save: ->
    # selectedLayers = new L.LayerGroup
    # @_featureGroup.eachLayer (layer) ->
    #   if layer.selected
    #     selectedLayers.addLayer layer
    #     layer.selected = false
    # @_map.fire L.Cutting.Event.SELECTED, layers: selectedLayers

    #TMP
    @_featureGroup.eachLayer (l) =>
      @_map.removeLayer(l)
    @_featureGroup.addLayer(@_activeLayer._poly)
    @_featureGroup.addTo(@_map)
    # @_map.removeLayer(@_activeLayer._poly)
    delete @_activeLayer._poly
    delete @_activeLayer
    console.error @_featureGroup
    return

  _enableLayer: (e) ->
    layer = e.layer or e.target or e

    layer.options.original = L.extend({}, layer.options)

    if @options.disabledPathOptions
      pathOptions = L.Util.extend {}, @options.disabledPathOptions

      # Use the existing color of the layer
      if pathOptions.maintainColor
        pathOptions.color = layer.options.color
        pathOptions.fillColor = layer.options.fillColor

      layer.options.disabled = pathOptions

    if @options.selectedPathOptions
      pathOptions = L.Util.extend {}, @options.selectedPathOptions

      # Use the existing color of the layer
      if pathOptions.maintainColor
        pathOptions.color = layer.options.color
        pathOptions.fillColor = layer.options.fillColor

      layer.options.selected = pathOptions

    layer.setStyle layer.options.disabled

    layer.on 'click', @_activate, @
    layer.on 'touchstart', @_activate, @

  _disableLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    # Reset layer styles to that of before select
    if @options.selectedPathOptions
      layer.setStyle layer.options.original

    layer.off 'click', @_activate, @
    layer.off 'touchstart', @_activate, @

    delete layer.options.disabled
    delete layer.options.selected
    delete layer.options.original

  _activate: (e) ->
    layer = e.target

    if !layer.selected
      layer.selected = true
      layer.setStyle layer.options.selected

      if @_activeLayer
        @_activeLayer.selected = false
        @_activeLayer.setStyle @_activeLayer.options.disabled

      @_activeLayer = layer

      @_map.fire L.Cutting.Event.SELECT, layer: @_activeLayer
    else
      layer.selected = false
      layer.setStyle(layer.options.disabled)
      @_activeLayer = null
      @_map.fire L.Cutting.Event.UNSELECT, layer: layer

  _startCutDrawing: (e) ->
    @_backupLayer @_activeLayer

    # @_map.on L.Draw.Event.DRAWSTART, @_stopCutDrawing, @

    @_map.on L.Draw.Event.CREATED, @_stopCutDrawing, @

    @_activeLayer.cutting = new L.Draw.Polygon(@_map)

    if @options.cuttingPathOptions
      pathOptions = L.Util.extend {}, @options.cuttingPathOptions

      # Use the existing color of the layer
      if pathOptions.maintainColor
        pathOptions.color = layer.options.color
        pathOptions.fillColor = layer.options.fillColor

      # layer.options.original = L.extend {}, layer.options
      @_activeLayer.options.cutting = pathOptions

    @_activeLayer.cutting.enable()

  _stopCutDrawing: (e) ->
    cuttingShape = e.layer

    @_map.off L.Draw.Event.CREATED, @_stopCutDrawing, @

    @_activeLayer.cutting.disable()

    #TMP
    # shape = @_intersect(@_activeLayer, layer)
    # @_activeLayer._poly = @_difference(@_activeLayer, shape)
    # shape.addTo @_map
    # @_map.fitBounds(shape.getBounds())
#
    # @_activeLayer._poly.addTo(@_map)
    # @_map.fitBounds(@_activeLayer.getBounds())
    #

    if @_featureGroup.search is "function"
      closestLayers = @_featureGroup.search cuttingShape.getBounds()
    else
      closestLayers = @_featureGroup.getLayers()

    for closestLayer in closestLayers
      intersectShape = @_intersect closestLayer, cuttingShape
      console.error intersectShape

      @_map.removeLayer(closestLayer._poly)
      closestLayer._poly = @_difference closestLayer, intersectShape
      closestLayer._poly.addTo @_map


    console.error shape.getLayers()[0]
    editShape = new L.Edit.Poly(shape.getLayers()[0])
    editShape._poly.addTo(@_map)

    editShape._poly.on 'editdrag', @_moveMarker, @

    editShape.enable()

    @_moveMarker layer: shape


    # @_activeLayer._poly.eachLayer (l) =>
    #   # @_activeLayer._poly.addTo(@_map)
    #   editShape = new L.Edit.Poly(l)
    #   editShape._poly.addTo(@_map)
    #   editShape.enable()
    # lay = @_activeLayer._poly.getLayers()[0]
    # console.error lay


  _moveMarker: (e) ->
    cuttingShape = e.target || e.layer
    console.error 'move', e

    console.error @_featureGroup

    if @_featureGroup.search is "function"
      closestLayers = @_featureGroup.search cuttingShape.getBounds()
    else
      closestLayers = @_featureGroup.getLayers()

    for closestLayer in closestLayers
      intersectShape = @_intersect closestLayer, cuttingShape

      @_map.removeLayer(closestLayer._poly)
      closestLayer._poly = @_difference closestLayer, intersectShape
      closestLayer._poly.addTo @_map

    #
    # shape = @_intersect(layer)
    #
    # @_map.removeLayer(@_activeLayer._poly)
    #
    # @_activeLayer._poly = @_difference(shape)
    # @_activeLayer._poly.addTo(@_map)

    # shape.addTo @_map
    # @_map.fitBounds(shape.getBounds())


  _backupLayer: (layer) ->
    id = L.Util.stamp(layer)

    if !@_uneditedLayerProps[id]
      # Polyline, Polygon or Rectangle
      if layer instanceof L.Polyline or layer instanceof L.Polygon or layer instanceof L.Rectangle
        @_uneditedLayerProps[id] = latlngs: L.LatLngUtil.cloneLatLngs(layer.getLatLngs())
      else if layer instanceof L.Circle
        @_uneditedLayerProps[id] =
          latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())
          radius: layer.getRadius()
      else if layer instanceof L.Marker or layer instanceof L.CircleMarker
        # Marker
        @_uneditedLayerProps[id] = latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())

  _hasAvailableLayers: ->
    @_featureGroup.getLayers().length != 0

L.Cut.include L.Mixin.Events
