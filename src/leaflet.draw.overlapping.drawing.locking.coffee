L = require 'leaflet'
_ = require 'lodash'

turf = require '@turf/helpers'
turfinside = require '@turf/inside'

L.Draw.Feature.DrawMixin =
  _draw_initialize: ->
    @on 'enabled', @_draw_on_enabled, this
    @on 'disabled', @_draw_on_disabled, this

  _draw_on_enabled: ->
    if !@options.guideLayers
      return

    if !@_mouseMarker
      @_map.on 'layeradd', @_draw_on_enabled, this
      return
    else
      @_map.off 'layeradd', @_draw_on_enabled, this
      @_map.on L.Draw.Event.DRAWVERTEX, @_draw_on_click, @

  _draw_on_click: (e) ->
    marker = e.layers.getLayers()[..].pop()
    markerPoint = marker.getLatLng().toTurfFeature()

    for guideLayer in @options.guideLayers
      continue unless typeof guideLayer.getLayers == 'function'
      for layer in guideLayer.getLayers()
        polygon = layer.toTurfFeature()

        if turfinside.default(markerPoint, polygon, ignoreBoundary: false)
          @deleteLastVertex()

  _draw_on_disabled: ->
    if @_mouseMarker
      @_mouseMarker.off 'mouseup', @_draw_on_click, this
    @_map.off 'layeradd', @_draw_on_enabled, this

L.Draw.Feature.include L.Draw.Feature.DrawMixin
L.Draw.Feature.addInitHook '_draw_initialize'
