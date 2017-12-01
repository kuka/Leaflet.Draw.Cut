turf = require '@turf/helpers'
turfFlip = require '@turf/flip'

L.Polygon.include
  toTurfFeature: ->
    return if @isEmpty() or !@_latlngs

    #I don't use project to avoid adding the layer to map

    multi = !L.LineUtil.isFlat(@_latlngs[0])

    ring0 = if multi then @_latlngs[0][0] else @_latlngs[0]

    #Convert to array and close polygon
    coords = L.GeoJSON.latLngsToCoords(ring0, 0, true)
    turf.polygon([coords])

  outerRingAsTurfLineString: ->

    #I don't use project to avoid adding the layer to map

    multi = !L.LineUtil.isFlat(@_latlngs[0])
    ring0 = if multi then @_latlngs[0][0] else @_latlngs[0]

    coords = L.GeoJSON.latLngsToCoords(ring0, 0, true)
    turf.lineString(coords)

#Returns a LatLng object as a Turf Feature<Point>
L.LatLng::toTurfFeature = ->
  coords = L.GeoJSON.latLngToCoords @
  turf.point coords

L.Polyline.include
  merge: (polyline) ->
    latLngs = polyline.getLatLngs()
    return unless latLngs.length

    firstPoint = @getLatLngs()[0]
    lastPoint = @getLatLngs()[@getLatLngs().length - 1]
    length = latLngs.length

    for latLng, i in latLngs
      if i == 0
        latLng = lastPoint
      if i == (length - 1)
        latLng = firstPoint
      @addLatLng(latLng)
    return

  toTurfFeature: ->
    return if @isEmpty() or !@_latlngs
    coords = L.GeoJSON.latLngsToCoords(@_latlngs, 0)
    turf.lineString(coords)

  fromTurfFeature: (feature) ->
    @setLatLngs(turfFlip(feature).geometry.coordinates)

L.LayerGroup.include
  getLayerUUID: (layer) ->
    layer.feature.properties.uuid

  hasUUIDLayer: (layer) ->
    if !!layer && layerUUID = @getLayerUUID(layer)
      for id, l of @_layers
        if @getLayerUUID(l) == layerUUID
          return true
    return false
