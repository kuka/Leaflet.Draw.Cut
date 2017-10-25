turf = require '@turf/helpers'

L.Polygon.include
  toTurfFeature: ->
    return if @isEmpty() or !@_latlngs

    #I don't use project to avoid adding the layer to map

    multi = !L.LineUtil.isFlat(@_latlngs[0])

    ring0 = if multi then @_latlngs[0][0] else @_latlngs[0]

    #Convert to array and close polygon
    coords = L.GeoJSON.latLngsToCoords(ring0, 0, true)
    turf.polygon([coords])
