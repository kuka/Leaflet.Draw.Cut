L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfIntersect = require '@turf/intersect'
turfDifference = require '@turf/difference'
turfLineSlice = require '@turf/line-slice'
turfFlip = require '@turf/flip'
turfRewind = require '@turf/rewind'
turfinside = require '@turf/inside'
require 'leaflet-geometryutil'

L.Cutting = {}
L.Cutting.Polyline = {}
L.Cutting.Polyline.Event = {}
L.Cutting.Polyline.Event.START = "cut:polyline:start"
L.Cutting.Polyline.Event.STOP = "cut:polyline:stop"
L.Cutting.Polyline.Event.SELECT = "cut:polyline:select"
L.Cutting.Polyline.Event.UNSELECT = "cut:polyline:unselect"
# L.Cutting.Polyline.Event.SELECTED = "layerSelection:selected"

class L.Cut.Polyline extends L.Handler
  @TYPE: 'cut-polyline'

  constructor: (map, options) ->
    @type = @constructor.TYPE
    @_map = map
    super map
    @options = _.merge @options, options

    @_featureGroup = options.featureGroup
    @_availableLayers = new L.FeatureGroup
    @_activeLayer = undefined
    @_uneditedLayerProps = []

    if !(@_featureGroup instanceof L.FeatureGroup)
      throw new Error('options.featureGroup must be a L.FeatureGroup')

  enable: ->
    if @_enabled or !@_featureGroup.getLayers().length
      return

    @fire 'enabled', handler: @type

    @_map.fire L.Cutting.Polyline.Event.START, handler: @type

    super

    # @refreshAvailableLayers()

    @_availableLayers.on 'layeradd', @_enableLayer, @
    @_availableLayers.on 'layerremove', @_disableLayer, @

    @_map.on L.Cutting.Polyline.Event.SELECT, @_cut, @

    @_map.on 'zoomend moveend', () =>
      @refreshAvailableLayers()

    @_map.on 'mousemove', @_selectLayer, @
    @_map.on 'mousemove', @_cut, @


    # @_map.on L.Cutting.Polyline.Event.UNSELECT, @_cancelCutDrawing, @
    # @_map.on L.Draw.Event.DRAWSTART, @_stopCutDrawing, @
    # @_map.on L.Draw.Event.CREATED, @_stopCutDrawing, @

  disable: ->
    if !@_enabled
      return
    @_availableLayers.off 'layeradd', @_enableLayer, @
    @_availableLayers.off 'layerremove', @_disableLayer, @

    super

    @_map.fire L.Cutting.Polyline.Event.STOP, handler: @type

    @_map.off L.Cutting.Polyline.Event.SELECT, @_startCutDrawing, @
    # @_map.off L.Cutting.Polyline.Event.UNSELECT, @_stopCutDrawing, @
    @_map.off L.Draw.Event.CREATED, @_stopCutDrawing, @


    @fire 'disabled', handler: @type
    return

  addHooks: ->

    @refreshAvailableLayers()

    @_availableLayers.eachLayer @_enableLayer, @

  refreshAvailableLayers: ->
    return unless @_featureGroup.getLayers().length

    #RTree
    if typeof @_featureGroup.search == 'function'
      newLayers = new L.LayerGroup(@_featureGroup.search(@_map.getBounds()))

      removeList = @_availableLayers.getLayers().filter (layer) ->
        !newLayers.hasLayer layer

      if removeList.length
        for l in removeList
          @_availableLayers.removeLayer l

      addList = newLayers.getLayers().filter (layer) =>
        !@_availableLayers.hasLayer layer

      if addList.length
        for l in addList
          @_availableLayers.addLayer(l)

    else
      @_availableLayers = @_featureGroup


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
        fillColor: 'blue', opacity: 1, fillOpacity: 1


  removeHooks: ->
    @_featureGroup.eachLayer @_disableLayer, @

  save: ->
    # selectedLayers = new L.LayerGroup
    # @_featureGroup.eachLayer (layer) ->
    #   if layer.selected
    #     selectedLayers.addLayer layer
    #     layer.selected = false
    # @_map.fire L.Cutting.Polyline.Event.SELECTED, layers: selectedLayers

    #TMP
    @_featureGroup.eachLayer (l) =>
      @_map.removeLayer(l)
    @_featureGroup.addLayer(@_activeLayer._poly)
    @_featureGroup.addTo(@_map)
    # @_map.removeLayer(@_activeLayer._poly)
    delete @_activeLayer._poly
    delete @_activeLayer
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

  _selectLayer: (e) ->
    layer = e.target || e.layer || e
    mouseLatLng = e.latlng

    for layer in @_availableLayers.getLayers()
      mousePoint = mouseLatLng.toTurfFeature()
      polygon = layer.toTurfFeature()

      if turfinside.default(mousePoint, polygon)
        if layer != @_activeLayer
          @_activate layer, mouseLatLng
        return

    if @_activeLayer
      @_unselectLayer @_activeLayer

  _unselectLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    if @options.selectedPathOptions
      layer.setStyle layer.options.disabled

    if @_activeLayer.cutting
      @_activeLayer.cutting.disable()
      delete @_activeLayer.cutting

    @_activeLayer = null

  _disableLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    # Reset layer styles to that of before select
    if @options.selectedPathOptions
      layer.setStyle layer.options.original

    delete layer.options.disabled
    delete layer.options.selected
    delete layer.options.original

  _activate: (e, latlng) ->
    layer = e.target || e.layer || e
    console.error layer

    if !layer.selected
      layer.selected = true
      layer.setStyle layer.options.selected

      if @_activeLayer
        @_activeLayer.selected = false
        @_activeLayer.setStyle @_activeLayer.options.disabled

      @_activeLayer = layer

      @_map.fire L.Cutting.Polyline.Event.SELECT, layer: @_activeLayer, latlng: latlng
    else
      layer.selected = false
      layer.setStyle(layer.options.disabled)

      @_activeLayer.cutting.disable()
      delete @_activeLayer.cutting

      @_activeLayer = null
      @_map.fire L.Cutting.Polyline.Event.UNSELECT, layer: layer

  _cut: (e) ->
    return unless @_activeLayer
    mouseLatLng = e.event || e.latlng
    mousePoint = mouseLatLng.toTurfFeature()

    console.error 'cutting'

    if !@_activeLayer.cutting
      @_activeLayer.cutting = new L.Draw.Polyline(@_map)
      if @options.cuttingPathOptions
        pathOptions = L.Util.extend {}, @options.cuttingPathOptions

        # Use the existing color of the layer
        if pathOptions.maintainColor
          pathOptions.color = layer.options.color
          pathOptions.fillColor = layer.options.fillColor

        # layer.options.original = L.extend {}, layer.options
        @_activeLayer.options.cutting = pathOptions


      @_activeLayer.cutting.enable()


    # console.error mousePoint
    # mousePoint = e.event.toTurfFeature()

    # firstPoint, snapped
    # if !@_startPoint

      #TMP
      # closestLatLng = L.GeometryUtil.closestLayerSnap(@_map, [@_activeLayer], mouseLatLng, 10)
      # if closestLatLng
        # closestLatLng = closestLatLng.latlng
        # console.error closestLatLng
      # console.error closestLatLng
        # mousePoint = L.latLng([closestLatLng.lat, closestLatLng.lng]).toTurfFeature()
      # console.error mousePoint

      # console.error 'on the line', onLine
      # console.error closestLatLng, onLine, ring0
    # @_backupLayer @_activeLayer

    # @_map.on L.Draw.Event.DRAWSTART, @_stopCutDrawing, @

    # @_map.on L.Draw.Event.CREATED, @_stopCutDrawing, @

    # @_activeLayer.cutting = new L.Draw.Polyline(@_map)
    # console.error @_activeLayer.cutting



    # @_activeLayer.cutting.enable()

    #TMP
    # @_map.on L.Draw.Event.DRAWVERTEX, @_finishDrawing, @


  _finishDrawing: (e) ->
    console.error e

    if(e.layers.getLayers().length >=3)
      # @_map.fire L.Draw.Event.CREATED, @
      @_activeLayer.cutting.completeShape()
      # e.layers._fireCreatedEvent()

  _stopCutDrawing: (e) ->
    @_map.off L.Draw.Event.CREATED, @_stopCutDrawing, @

    activeLineString = @_activeLayer.outerRingAsTurfLineString()

    [firstPoint, ..., lastPoint] = e.layer.getLatLngs()
    slicedLineString = turfLineSlice(firstPoint.toTurfFeature(), lastPoint.toTurfFeature(), activeLineString)
    rewindSlicedLineString = turfRewind(slicedLineString, true)
    slicedPolyline = new L.Polyline []
    slicedPolyline.fromTurfFeature(rewindSlicedLineString)

    cuttingLineString = e.layer.toTurfFeature()
    rewindCuttingLineString = turfRewind(cuttingLineString)
    cuttingPolyline = new L.Polyline []
    cuttingPolyline.fromTurfFeature(rewindCuttingLineString)

    ## tmp
    slFirstPoint = slicedPolyline.getLatLngs()[0]
    slLastPoint = slicedPolyline.getLatLngs()[slicedPolyline.getLatLngs().length - 1]

    fakePolyLine = new L.Polyline([slFirstPoint, cuttingPolyline.getLatLngs()[1], slLastPoint])

    slicedPolyline.merge fakePolyLine
    #####

    slicedPolygon = L.polygon(slicedPolyline.getLatLngs(), color: 'yellow', Opacity: 1, fillOpacity: 1)

    poly1 = slicedPolygon
    poly2 = @_difference(@_activeLayer, poly1)

    slicedPolygon.addTo @_map
    poly2.addTo @_map

    @_activeLayer._polys = []
    @_activeLayer._polys.push poly1
    @_activeLayer._polys.push poly2


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
  #
  #
  # _backupLayer: (layer) ->
  #   id = L.Util.stamp(layer)
  #
  #   if !@_uneditedLayerProps[id]
  #     # Polyline, Polygon or Rectangle
  #     if layer instanceof L.Polyline or layer instanceof L.Polygon or layer instanceof L.Rectangle
  #       @_uneditedLayerProps[id] = latlngs: L.LatLngUtil.cloneLatLngs(layer.getLatLngs())
  #     else if layer instanceof L.Circle
  #       @_uneditedLayerProps[id] =
  #         latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())
  #         radius: layer.getRadius()
  #     else if layer instanceof L.Marker or layer instanceof L.CircleMarker
  #       # Marker
  #       @_uneditedLayerProps[id] = latlng: L.LatLngUtil.cloneLatLng(layer.getLatLng())

  _hasAvailableLayers: ->
    @_availableLayers.length != 0

L.Cut.Polyline.include L.Mixin.Events
