L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfIntersect = require '@turf/intersect'
turfDifference = require '@turf/difference'
turfLineSlice = require '@turf/line-slice'
turfFlip = require '@turf/flip'
turfRewind = require '@turf/rewind'
turfinside = require '@turf/inside'
turfMeta = require '@turf/meta'
turfInvariant = require '@turf/invariant'
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
        fillColor: '#3f51b5', opacity: 1, fillOpacity: 1, color: 'black', weight: 2


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
    # layer = e.target || e.layer || e
    mouseLatLng = e.latlng
    for layer in @_availableLayers.getLayers()
      mousePoint = mouseLatLng.toTurfFeature()
      polygon = layer.toTurfFeature()

      if turfinside.default(mousePoint, polygon)
        if layer != @_activeLayer
          @_activate layer, mouseLatLng
        return

    if @_activeLayer && !@_activeLayer.glue
      @_unselectLayer @_activeLayer

  _unselectLayer: (e) ->
    layer = e.layer or e.target or e
    layer.selected = false
    if @options.selectedPathOptions
      layer.setStyle layer.options.disabled

    if layer.cutting
      layer.cutting.disable()
      delete layer.cutting

    @_map.on 'mousemove', @_selectLayer, @

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

    if !layer.selected
      layer.selected = true
      layer.setStyle layer.options.selected

      if @_activeLayer
        @_unselectLayer @_activeLayer

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

    if !@_activeLayer.cutting
      @_activeLayer.cutting = new L.Draw.Polyline(@_map)

      @_activeLayer.cutting.setOptions(_.merge(@options.snap, guideLayers: [@_activeLayer]))

      if @options.cuttingPathOptions
        pathOptions = L.Util.extend {}, @options.cuttingPathOptions

        # Use the existing color of the layer
        if pathOptions.maintainColor
          pathOptions.color = layer.options.color
          pathOptions.fillColor = layer.options.fillColor

        # layer.options.original = L.extend {}, layer.options
        @_activeLayer.options.cutting = pathOptions

      @_activeLayer.cutting.enable()

    # firstPoint, snapped
    if !@_startPoint
      @_activeLayer.cutting._mouseMarker.on 'move', @glueMarker, @
      @_activeLayer.cutting._mouseMarker.on 'snap', @_glue_on_enabled, @

  glueMarker: (e) =>
    closest = L.GeometryUtil.closest(@_map, @_activeLayer, e.latlng, false)
    @_activeLayer.cutting._mouseMarker._latlng = L.latLng(closest.lat, closest.lng)
    @_activeLayer.cutting._mouseMarker.update()

  _glue_on_enabled: =>
    @_activeLayer.glue = true

    @_activeLayer.cutting._snapper.unwatchMarker(@_activeLayer.cutting._mouseMarker)

    @_map.on 'click', @_glue_on_click, @

  _glue_on_click: =>

    if @_activeLayer.cutting._markers
      markerCount = @_activeLayer.cutting._markers.length
      marker = @_activeLayer.cutting._markers[markerCount - 1]

      if markerCount == 1
        @_activeLayer.cutting._snapper.addOrigin(@_activeLayer.cutting._markers[0])
        L.DomUtil.addClass @_activeLayer.cutting._markers[0]._icon, 'marker-origin'

      if marker
        L.DomUtil.addClass marker._icon, 'marker-snapped'

        marker.setLatLng(@_activeLayer.cutting._mouseMarker._latlng)
        poly = @_activeLayer.cutting._poly
        latlngs = poly.getLatLngs()
        latlngs.splice(-1, 1)
        @_activeLayer.cutting._poly.setLatLngs(latlngs)
        @_activeLayer.cutting._poly.addLatLng(@_activeLayer.cutting._mouseMarker._latlng)

        snapPoint = @_map.latLngToLayerPoint marker._latlng
        @_activeLayer.cutting._updateGuide snapPoint

        @_activeLayer.setStyle(@_activeLayer.options.cutting)

        @_activeLayer.glue = false

        @_map.off 'mousemove', @_selectLayer, @

        @_startPoint = marker

        @_activeLayer.cutting._mouseMarker.off 'move', @glueMarker, @
        @_map.off 'click', @_glue_on_click, @
        @_activeLayer.cutting._snapper.watchMarker(@_activeLayer.cutting._mouseMarker)

        @_activeLayer.cutting._mouseMarker.off 'snap', @_glue_on_enabled, @

        @_activeLayer.cutting._mouseMarker.on 'snap', (e) =>
          console.error 'snap'
          @_map.on 'click', @_finishDrawing, @

        @_activeLayer.cutting._mouseMarker.on 'unsnap', (e) =>
          console.error 'unsnap'
          @_map.off 'click', @_finishDrawing, @


  _finishDrawing: (e) ->
    console.error 'finish'

    @_stopCutDrawing()

  _stopCutDrawing: () ->

    drawnPolyline = @_activeLayer.cutting._poly

    activeLineString = @_activeLayer.outerRingAsTurfLineString()

    [firstPoint, ..., lastPoint] = drawnPolyline.getLatLngs()
    slicedLineString = turfLineSlice(firstPoint.toTurfFeature(), lastPoint.toTurfFeature(), activeLineString)

    # clean duplicate points
    coords = []
    turfMeta.coordEach slicedLineString, (current, index) ->
      unless index > 0 and coords[..].pop() == current
        coords.push current

    slicedLineString = turf.lineString coords

    rewindSlicedLineString = turfRewind(slicedLineString, true)

    slicedPolyline = new L.Polyline []
    slicedPolyline.fromTurfFeature(rewindSlicedLineString)
    # slicedPolyline.addTo @_map

    cuttingLineString = drawnPolyline.toTurfFeature()
    rewindCuttingLineString = turfRewind(cuttingLineString)
    cuttingPolyline = new L.Polyline []
    cuttingPolyline.fromTurfFeature(rewindCuttingLineString)
    # cuttingPolyline.addTo @_map

    slicedPolyline.merge cuttingPolyline

    @_activeLayer.cutting.disable()

    slicedPolygon = L.polygon(slicedPolyline.getLatLngs(), fillColor: '#009688', fillOpacity: 1, opacity: 1, weight: 2, color: 'black')

    remainingPolygon = @_difference(@_activeLayer, slicedPolygon)

    @_map.removeLayer @_activeLayer
    slicedPolygon.addTo @_map
    remainingPolygon.addTo @_map

    @_activeLayer._polys = []
    @_activeLayer._polys.push slicedPolygon
    @_activeLayer._polys.push remainingPolygon

    editPoly = new L.Edit.Poly cuttingPolyline
    editPoly._poly.options.editing = {color: '#fe57a1', dashArray: '10, 10'}

    editPoly._poly.on 'editdrag', @_moveMarker, @

    editPoly._poly.addTo(@_map)
    editPoly.enable()

    @_map.off 'click', @_finishDrawing, @

  _moveMarker: (e) ->

    drawnPolyline = e.target

    activeLineString = @_activeLayer.outerRingAsTurfLineString()

    [firstPoint, ..., lastPoint] = drawnPolyline.getLatLngs()
    slicedLineString = turfLineSlice(firstPoint.toTurfFeature(), lastPoint.toTurfFeature(), activeLineString)

    # clean duplicate points
    coords = []
    turfMeta.coordEach slicedLineString, (current, index) ->
      unless index > 0 and coords[..].pop() == current
        coords.push current

    slicedLineString = turf.lineString coords

    rewindSlicedLineString = turfRewind(slicedLineString, true)

    slicedPolyline = new L.Polyline []
    slicedPolyline.fromTurfFeature(rewindSlicedLineString)
    # slicedPolyline.addTo @_map

    cuttingLineString = drawnPolyline.toTurfFeature()
    rewindCuttingLineString = turfRewind(cuttingLineString)
    cuttingPolyline = new L.Polyline []
    cuttingPolyline.fromTurfFeature(rewindCuttingLineString)
    # cuttingPolyline.addTo @_map

    slicedPolyline.merge cuttingPolyline

    @_activeLayer.cutting.disable()

    slicedPolygon = L.polygon(slicedPolyline.getLatLngs(), fillColor: '#009688', fillOpacity: 1, opacity: 1, weight: 2, color: 'black')

    remainingPolygon = @_difference(@_activeLayer, slicedPolygon)

    @_map.removeLayer @_activeLayer
    slicedPolygon.addTo @_map
    remainingPolygon.addTo @_map

    @_activeLayer._polys = []
    @_activeLayer._polys.push slicedPolygon
    @_activeLayer._polys.push remainingPolygon

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
