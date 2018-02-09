describe 'DrawCutPolyline', ->

  beforeEach ->
    @map = new L.Map(document.createElement('div')).setView([0, 0], 15)
    squareLatlngs = [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]
    @squarePolygon = L.polygon(squareLatlngs)
    @squarePolygon.selected = false
    lgSquareLatlngs = [[0, 0], [1, 0], [3, 0], [3, 3], [1, 3], [0, 3], [0, 0]]
    @lgSquarePolygon = L.polygon(lgSquareLatlngs)

  it 'should split a polygon into two new polygons matching specific coordinates', ->
    lineLatlngs = [[0, 0], [2, 2]]
    splitLine = L.polyline(lineLatlngs)
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    firstTriangleLatlngs = [[2, 2], [2, 0], [0, 0], [2, 2]]
    secondTriangleLatlngs = [[0, 0], [2, 2], [0, 2], [0, 0]]
    firstTriangle = L.polygon(firstTriangleLatlngs)
    secondTriangle = L.polygon(secondTriangleLatlngs)
    splitResult = klass._cut(@squarePolygon, splitLine)
    expect(splitResult[0].getLatLngs()).toEqual(firstTriangle.getLatLngs())
    expect(splitResult[1].getLatLngs()).toEqual(secondTriangle.getLatLngs())
    expect(splitResult[2].getLatLngs()).toEqual(splitLine.getLatLngs())

  it 'should split a polygon into two new polygons matching a specific area', ->
    getReadableArea = (polygon) ->
      L.GeometryUtil.readableArea(L.GeometryUtil.geodesicArea(polygon.getLatLngs()[0]), true)

    lineLatlngs = [[1, 0], [1, 3]]
    splitLine = L.polyline(lineLatlngs)
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    firstRectangleLatlngs = [[0, 0], [1, 0], [1, 3], [0, 3], [0, 0]]
    secondRectangleLatlngs = [[1, 0], [3, 0], [3, 3], [1, 3], [1, 0]]
    firstRectangle = L.polygon(firstRectangleLatlngs)
    secondRectangle = L.polygon(secondRectangleLatlngs)
    splitResult = klass._cut(@lgSquarePolygon, splitLine)
    expect(getReadableArea(splitResult[0])).toEqual(getReadableArea(secondRectangle))
    expect(getReadableArea(splitResult[1])).toEqual(getReadableArea(firstRectangle))

  it 'should split a polygon into two new polygons when drawing a polyline from one point to another that are not picked among the polygon\'s coordinates', ->
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    klass._activate(@squarePolygon, { lat: 0, lng:0 })
    e1 = {}
    e1.target = L.marker([0.2, 0.4])
    e1.latlng = e1.target._latlng
    klass.glueMarker(e1)
    e2 = {}
    e2.target = L.marker([1.4, 1.6])
    e2.latlng = e2.target._latlng
    klass.glueMarker(e2)
    splitLine = L.polyline([e1.target._latlng, [0.7, 0.7], [1.2, 1.2], e2.target._latlng])
    splitResult = klass._cut(@squarePolygon, splitLine)
    expect(splitResult[0].toGeoJSON().geometry.type).toEqual('Polygon')
    expect(splitResult[1].toGeoJSON().geometry.type).toEqual('Polygon')
    expect(splitResult[2].toGeoJSON().geometry.type).toEqual('LineString')

  it 'should activate a layer', ->
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    klass._activate(@squarePolygon, { lat: 0, lng:0 })
    expect(klass._activeLayer).toBe(@squarePolygon)
    expect(@squarePolygon.selected).toBeTruthy()

  it 'should deactivate a layer', ->
    @squarePolygon.selected = true
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    klass._unselectLayer(@squarePolygon)
    expect(klass._activeLayer).toBeNull()
    expect(@squarePolygon.selected).toBeFalsy()

  it 'should activate a layer when the mouse pointer is on its polygon', ->
    options = {}
    options.featureGroup = new L.FeatureGroup([@squarePolygon])
    klass = new L.Cut.Polyline(@map, options)
    klass.enable()
    e = {}
    e.latlng = L.latLng(1, 1)
    klass._selectLayer(e)
    expect(@squarePolygon.selected).toBeTruthy()
    e.latlng = L.latLng(5, 5)
    klass._selectLayer(e)
    expect(@squarePolygon.selected).toBeFalsy()

  it 'should put the marker on the polygon\'s outer ring if the mouse pointer is inside the polygon', ->
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    klass._activate(@lgSquarePolygon, { lat: 0, lng:0 })
    e = {}
    e.target = L.marker([1, 1])
    e.latlng = e.target._latlng
    klass.glueMarker(e)
    expect(e.latlng == e.target._latlng).toBeFalsy()
    closestLayer = L.GeometryUtil.closestLayer(@map, [@lgSquarePolygon], e.target._latlng)
    expect(closestLayer.distance).toEqual(0)
    closestLayer = L.GeometryUtil.closestLayer(@map, [@lgSquarePolygon], e.latlng)
    expect(closestLayer.latlng.equals(e.target._latlng)).toBeTruthy()

  it 'should enable the draw of the splitter', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    handler._activeLayer = L.polygon [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]

    expect(handler._activeLayer.cutting).toBeUndefined()

    handler._cutMode()

    splitter = handler._activeLayer.cutting
    expect(splitter).toBeDefined()
    expect(splitter.type).toBe("polyline")
    expect(splitter.enabled).toBeTruthy()
    expect(splitter._markers.length).toBe(0)
    expect(splitter._mouseMarker).toBeDefined(0)
    expect(handler._startPoint).toBeUndefined()

  it 'should set the active layer as a snap target', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    handler._activeLayer = L.polygon [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]

    handler._cutMode()

    splitter = handler._activeLayer.cutting
    expect(splitter.options.guideLayers).toContain(handler._activeLayer)

  it 'should throw an error as the splitter intersects the outer ring', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    poly = L.polygon [[-0.045404,44.70503],[-0.045973,44.704321],[-0.042626,44.703047],[-0.041596,44.704793],[-0.043108,44.705289],[-0.043731,44.704465],[-0.045404,44.70503]]
    splitter = L.polyline [[-0.04449798000371161, 44.70472402193789], [-0.041596,44.704793]]

    # Needs to use anonymous function as jasmine try to invoke it
    expect(() -> handler._cut(poly, splitter)).toThrowError('kinks')

  it 'should pin the first point of the splitter at the mouse position', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    handler._activeLayer = L.polygon [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]
    handler._activeLayer.addTo @map

    splitter = handler._activeLayer.cutting = new L.Draw.Polyline(@map)

    #We need to activate snap to be able to set origin
    splitter.setOptions guideLayers: [handler._activeLayer]

    splitter.enable()
    splitter._mouseMarker.setLatLng([0,0])

    expect(splitter.enabled).toBeTruthy()
    expect(splitter._markers.length).toBe(0)

    handler._glue_on_click()
    expect(splitter._markers.length).toBe(1)

    marker = splitter._markers[..].pop()
    expect([marker._latlng.lat, marker._latlng.lng]).toEqual([0,0])
    expect(handler._activeLayer.glue).toBeFalsy()
    expect(handler._startPoint).toBe(marker)

  it 'should pin the last point of the splitter at the mouse position', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    handler._activeLayer = L.polygon [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]
    handler._activeLayer.addTo @map

    splitter = handler._activeLayer.cutting = new L.Draw.Polyline(@map)

    #We need to activate snap to be able to set origin
    splitter.setOptions guideLayers: [handler._activeLayer]

    splitter.enable()
    splitter._mouseMarker.setLatLng([0,0])

    handler._glue_on_click()

    marker = splitter._markers[..].pop()
    expect(handler._startPoint).toBe(marker)
    splitter._mouseMarker.setLatLng([2,2])
    splitter._markers.push(splitter._createMarker(splitter._mouseMarker._latlng))

    handler._finishDrawing({})
    expect(splitter._markers.length).toBe(2)
