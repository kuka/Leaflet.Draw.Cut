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
L.Cutting.Polyline.Event.CREATED = "cut:polyline:created"
L.Cutting.Polyline.Event.UPDATED = "cut:polyline:updated"
L.Cutting.Polyline.Event.SAVED = "cut:polyline:saved"
# L.Cutting.Polyline.Event.SELECTED = "layerSelection:selected"

class L.Cut.Polyline extends L.Handler
  @TYPE: 'cut-polyline'

  constructor: (map, options) ->
    @type = @constructor.TYPE
    @_map = map
    super map
    @options = _.merge @options, options

    @_featureGroup = options.featureGroup
    @_uneditedLayerProps = []

    if !(@_featureGroup instanceof L.FeatureGroup)
      throw new Error('options.featureGroup must be a L.FeatureGroup')

  enable: ->
    if @_enabled or !@_featureGroup.getLayers().length
      return

    @_availableLayers = new L.GeoJSON [], style: (feature) ->
      color: feature.properties.color

    @_activeLayer = undefined

    @fire 'enabled', handler: @type

    @_map.fire L.Cutting.Polyline.Event.START, handler: @type

    @_availableLayers.addTo @_map
    @_availableLayers.on 'layeradd', @_enableLayer, @
    @_availableLayers.on 'layerremove', @_disableLayer, @

    @_map.on L.Cutting.Polyline.Event.SELECT, @_cutMode, @

    @_map.on 'zoomend moveend', @refreshAvailableLayers, @

    @_map.on 'mousemove', @_selectLayer, @
    @_map.on 'mousemove', @_cutMode, @


    super
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

    if @_activeLayer and @_activeLayer.cutting
      @_activeLayer.cutting.disable()

      if @_activeLayer and @_activeLayer.cutting._poly
        @_map.removeLayer @_activeLayer.cutting._poly
        delete @_activeLayer.cutting._poly

      delete @_activeLayer.cutting

    if @_activeLayer and @_activeLayer.editing
      @_activeLayer.editing.disable()

      if @_activeLayer and @_activeLayer.editing._poly
        @_map.removeLayer @_activeLayer.editing._poly

    if @_activeLayer and @_activeLayer._polys
      @_activeLayer._polys.clearLayers()

      delete @_activeLayer._polys
      delete @_activeLayer.editing
    unless @_featureGroup._map
      @_map.addLayer @_featureGroup

    @_availableLayers.eachLayer (l) =>
      @_map.removeLayer l
    @_availableLayers.length = 0

    @_startPoint = null
    delete @_activeLayer.glue
    @_activeLayer = null

    @_map.off L.Draw.Event.DRAWVERTEX, @_finishDrawing, @
    @_map.off 'click', @_finishDrawing, @

    @_map.off 'mousemove', @_selectLayer, @
    @_map.off 'mousemove', @_cutMode, @

    @_map.off 'zoomend moveend', @refreshAvailableLayers, @

    @fire 'disabled', handler: @type
    return

  addHooks: ->

    @refreshAvailableLayers()

    # @_availableLayers.eachLayer @_enableLayer, @

    @_map.removeLayer @_featureGroup

  refreshAvailableLayers: ->
    return unless @_featureGroup.getLayers().length

    #RTree
    if typeof @_featureGroup.search == 'function'
      newLayers = new L.FeatureGroup(@_featureGroup.search(@_map.getBounds()))

      removeList = @_availableLayers.getLayers().filter (layer) ->
        !newLayers.hasLayer layer

      if removeList.length
        for l in removeList
          @_availableLayers.removeLayer l

      addList = newLayers.getLayers().filter (layer) =>
        !@_availableLayers.hasUUIDLayer layer

      if addList.length
        for l in addList
          unless @_availableLayers.hasUUIDLayer l
            geojson = l.toGeoJSON()
            geojson.properties.color = l.options.color
            @_availableLayers.addData(geojson)

    else
      @_availableLayers = @_featureGroup

  #layer1 - layer2
  _difference: (layer1, layer2) ->

    try
      polygon1 = layer1.toTurfFeature()
      polygon2 = layer2.toTurfFeature()

      difference = turfDifference(polygon1, polygon2)

      L.geoJSON difference,
        style: () ->
          fillColor: '#3f51b5', opacity: 1, fillOpacity: 0.6, color: 'black', weight: 2
    catch
      console.error "He's dead, Jim."

  removeHooks: ->
    @_availableLayers.eachLayer @_disableLayer, @

  save: ->
    newLayers = []

    @_map.addLayer @_featureGroup

    if @_activeLayer._polys
      @_activeLayer._polys.eachLayer (l) =>
        @_featureGroup.addData l.toGeoJSON()

      @_activeLayer._polys.clearLayers()
      delete @_activeLayer._polys

      newLayers = @_featureGroup.getLayers()[-2..-1]

      @_map.fire L.Cutting.Polyline.Event.SAVED, oldLayer: {uuid: @_activeLayer.feature.properties.uuid, type: @_activeLayer.feature.properties.type}, layers: newLayers

      @_map.removeLayer @_activeLayer
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
        pathOptions.fillColor = layer.options.fillColor || pathOptions.color

      layer.options.selected = pathOptions

    layer.setStyle layer.options.disabled

  _selectLayer: (e) ->
    mouseLatLng = e.latlng
    found = false

    @_availableLayers.eachLayer (layer) =>
      mousePoint = mouseLatLng.toTurfFeature()
      polygon = layer.toTurfFeature()

      if turfinside.default(mousePoint, polygon)
        if layer != @_activeLayer
          @_activate layer, mouseLatLng
        found = true
        return

    return if found
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

  _cutMode: (e) ->
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
          pathOptions.color = @_activeLayer.options.color
          pathOptions.fillColor = @_activeLayer.options.fillColor

        pathOptions.fillOpacity = 0.5
        @_activeLayer.options.cutting = pathOptions

      @_activeLayer.cutting.enable()

    # firstPoint, snapped
    if !@_startPoint
      @_activeLayer.cutting._mouseMarker.on 'move', @glueMarker, @
      @_activeLayer.cutting._mouseMarker.on 'snap', @_glue_on_enabled, @

  glueMarker: (e) =>
    marker = e.target || @_activeLayer.cutting._mouseMarker
    marker.glue = true
    closest = L.GeometryUtil.closest(@_map, @_activeLayer, e.latlng, false)
    marker._latlng = L.latLng(closest.lat, closest.lng)
    marker.update()

  _glue_on_enabled: =>
    @_activeLayer.glue = true

    @_activeLayer.cutting._snapper.unwatchMarker(@_activeLayer.cutting._mouseMarker)

    @_activeLayer.cutting._mouseMarker.on 'mousedown', @_glue_on_click, @
    @_map.on 'click', @_glue_on_click, @


  _glue_on_click: (e) =>

    console.error 'glueonclick', e
    if !@_activeLayer.cutting._mouseDownOrigin && !@_activeLayer.cutting._markers.length
      @_activeLayer.cutting._mouseMarker
      @_activeLayer.cutting.addVertex(@_activeLayer.cutting._mouseMarker._latlng)

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
        @_activeLayer.cutting._mouseMarker.off 'mousedown', @_glue_on_click, @
        @_map.off 'click', @_glue_on_click, @
        @_activeLayer.cutting._snapper.watchMarker(@_activeLayer.cutting._mouseMarker)

        @_activeLayer.cutting._mouseMarker.off 'snap', @_glue_on_enabled, @

        @_activeLayer.cutting._mouseMarker.on 'snap', (e) =>
          @_map.on L.Draw.Event.DRAWVERTEX, @_finishDrawing, @
          @_map.on 'click', @_finishDrawing, @
          @_activeLayer.cutting._mouseMarker.off 'move', @_constraintSnap, @

        @_activeLayer.cutting._mouseMarker.on 'unsnap', (e) =>
          @_activeLayer.cutting._mouseMarker.on 'move', @_constraintSnap, @

          @_map.off L.Draw.Event.DRAWVERTEX, @_finishDrawing, @
          @_map.off 'click', @_finishDrawing, @


  _constraintSnap: (e) =>
    marker = @_activeLayer.cutting._mouseMarker
    markerPoint = marker._latlng.toTurfFeature()
    polygon = @_activeLayer.toTurfFeature()

    if !turfinside.default(markerPoint, polygon, ignoreBoundary: true)
      @glueMarker(target: @_activeLayer.cutting._mouseMarker, latlng: @_activeLayer.cutting._mouseMarker._latlng)
      snapPoint = @_map.latLngToLayerPoint marker._latlng
      @_activeLayer.cutting._updateGuide snapPoint
      @_map.on 'click', @_finishDrawing, @

  _finishDrawing: (e) ->
    markerCount = @_activeLayer.cutting._markers.length
    marker = @_activeLayer.cutting._markers[markerCount - 1]

    if L.Browser.touch
      lastMarker = @_activeLayer.cutting._markers.pop()
      poly = @_activeLayer.cutting._poly
      latlngs = poly.getLatLngs()
      latlng = latlngs.splice(-1, 1)[0]
      @_activeLayer.cutting._poly.setLatLngs(latlngs)

    if !e.layers or L.Browser.touch
      @_activeLayer.cutting._markers.push(@_activeLayer.cutting._createMarker(@_activeLayer.cutting._mouseMarker._latlng))
      @_activeLayer.cutting._poly.addLatLng(@_activeLayer.cutting._mouseMarker._latlng)

    @_stopCutDrawing()

  _cut: (layer, polyline) ->

    activeLineString = layer.outerRingAsTurfLineString()

    [firstPoint, ..., lastPoint] = polyline.getLatLngs()
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

    cuttingLineString = polyline.toTurfFeature()
    rewindCuttingLineString = turfRewind(cuttingLineString)
    cuttingPolyline = new L.Polyline []
    cuttingPolyline.fromTurfFeature(rewindCuttingLineString)
    # cuttingPolyline.addTo @_map

    slicedPolyline.merge cuttingPolyline

    slicedPolygon = L.polygon(slicedPolyline.getLatLngs(), fillColor: '#009688', fillOpacity: 0.6, opacity: 1, weight: 2, color: 'black')

    remainingPolygon = @_difference(@_activeLayer, slicedPolygon)

    [slicedPolygon, remainingPolygon, cuttingPolyline]


  _stopCutDrawing: () ->

    drawnPolyline = @_activeLayer.cutting._poly

    [slicedPolygon, remainingPolygon, cuttingPolyline] = @_cut @_activeLayer, drawnPolyline

    @_activeLayer.cutting.disable()

    @_map.removeLayer @_activeLayer
    # slicedPolygon.addTo @_map
    # remainingPolygon.addTo @_map

    @_activeLayer._polys = new L.LayerGroup()
    @_activeLayer._polys.addTo @_map
    @_activeLayer._polys.addLayer slicedPolygon
    @_activeLayer._polys.addLayer remainingPolygon

    @_map.fire L.Cutting.Polyline.Event.CREATED, layers: [slicedPolygon, remainingPolygon]

    @_activeLayer.editing = new L.Edit.Poly cuttingPolyline
    @_activeLayer.editing._poly.options.editing = {color: '#fe57a1', dashArray: '10, 10'}

    @_activeLayer.editing._poly.addTo(@_map)
    @_activeLayer.editing.enable()

    @_activeLayer.editing._poly.on 'editstart', (e) =>
      for marker in @_activeLayer.editing._verticesHandlers[0]._markers
        if L.stamp(marker) == L.stamp(@_activeLayer.editing._verticesHandlers[0]._markers[0]) || L.stamp(marker) == L.stamp(@_activeLayer.editing._verticesHandlers[0]._markers[..].pop())
          marker.on 'move', @glueMarker, @
        else
          marker.on 'move', @_moveMarker, @

    @_activeLayer.editing._poly.on 'editdrag', @_moveMarker, @

    @_map.off 'click', @_finishDrawing, @

  _moveMarker: (e) ->
    marker = e.marker || e.target || e

    drawnPolyline = @_activeLayer.editing._poly

    unless marker.glue
      latlng = marker._latlng

      markerPoint = latlng.toTurfFeature()
      polygon = @_activeLayer.toTurfFeature()

      if !turfinside.default(markerPoint, polygon, ignoreBoundary: true) && oldLatLng = e.oldLatLng

        i = marker._index
        marker._latlng = oldLatLng
        marker.update()

        @_activeLayer.editing._verticesHandlers[0]._spliceLatLngs(i, 0, oldLatLng)
        @_activeLayer.editing._verticesHandlers[0]._markers.splice(i, 0, marker)
        @_activeLayer.editing._poly.redraw()

    @_activeLayer._polys.clearLayers()

    [slicedPolygon, remainingPolygon, ...] = @_cut @_activeLayer, drawnPolyline

    @_map.removeLayer @_activeLayer
    slicedPolygon.addTo @_map
    unless remainingPolygon is undefined
      remainingPolygon.addTo @_map
      @_activeLayer._polys.addLayer remainingPolygon

    @_activeLayer._polys.addLayer slicedPolygon
    @_activeLayer.editing._poly.bringToFront()

    @_map.fire L.Cutting.Polyline.Event.UPDATED, layers: [slicedPolygon, remainingPolygon]

  _hasAvailableLayers: ->
    @_availableLayers.length != 0

L.Cut.Polyline.include L.Mixin.Events
