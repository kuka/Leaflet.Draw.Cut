L = require 'leaflet'
_ = require 'lodash'

L.Cutting = {}
L.Cutting.Event = {}
L.Cutting.Event.START = "cut:start"
L.Cutting.Event.STOP = "cut:stop"
L.Cutting.Event.SELECT = "cut:select"
L.Cutting.Event.UNSELECT = "cut:unselect"
# L.Cutting.Event.SELECTED = "layerSelection:selected"

class L.Cut extends L.Handler
  @TYPE: 'cut'

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
    @_map.on L.Draw.Event.CREATED, @_stopCutDrawing, @

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

  removeHooks: ->
    @_featureGroup.eachLayer @_disableLayer, @

  save: ->
    selectedLayers = new L.LayerGroup
    @_featureGroup.eachLayer (layer) ->
      if layer.selected
        selectedLayers.addLayer layer
        layer.selected = false
    @_map.fire L.Cutting.Event.SELECTED, layers: selectedLayers
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
    @_activeLayer.cutting.disable()
    @_activeLayer._poly = @_activeLayer

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
