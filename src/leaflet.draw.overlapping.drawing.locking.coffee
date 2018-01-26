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
      if L.Browser.touch
        # this._map.on('touchstart', this._draw_on_click, this);
        @_mouseMarker.on 'mouseup', @_draw_on_click, this
      else
        @_mouseMarker.on 'mouseup', @_draw_on_click, this

  _draw_on_click: (e) ->

    latlng = e.target._latlng

    markerPoint = latlng.toTurfFeature()

    for guideLayer in @options.guideLayers
      for layer in guideLayer.getLayers()
        polygon = layer.toTurfFeature()

        if turfinside.default(markerPoint, polygon, ignoreBoundary: false)

          poly = @_poly
          latlngs = poly.getLatLngs()
          latlngs.splice -1, 1
          @_poly.setLatLngs latlngs
          markerCount = @_markers.length
          marker = @_markers[markerCount - 1]

          if marker
            @_markers.pop()
            @_map.removeLayer marker
            @_updateGuide()
            return

  _draw_on_disabled: ->
    if @_mouseMarker
      @_mouseMarker.off 'mouseup', @_draw_on_click, this
    @_map.off 'layeradd', @_draw_on_enabled, this

L.Draw.Feature.include L.Draw.Feature.DrawMixin
L.Draw.Feature.addInitHook '_draw_initialize'
