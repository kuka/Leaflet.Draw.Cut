describe 'DrawCutPolyline', ->

  beforeAll ->
    @map = new L.Map(document.createElement('div')).setView([0, 0], 15)

  it 'should split a polygon into two new polygons matching specific coordinates', ->
    squareLatlngs = [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]
    lineLatlngs = [[0, 0], [2, 2]]
    squarePolygon = L.polygon(squareLatlngs)
    splitLine = L.polyline(lineLatlngs)
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    firstTriangleLatlngs = [[2, 2], [2, 0], [0, 0], [2, 2]]
    secondTriangleLatlngs = [[0, 0], [2, 2], [0, 2], [0, 0]]
    firstTriangle = L.polygon(firstTriangleLatlngs)
    secondTriangle = L.polygon(secondTriangleLatlngs)
    splitResult = klass._cut(squarePolygon, splitLine)
    expect(splitResult[0].getLatLngs()).toEqual(firstTriangle.getLatLngs())
    expect(splitResult[1].getLatLngs()).toEqual(secondTriangle.getLatLngs())
    expect(splitResult[2].getLatLngs()).toEqual(splitLine.getLatLngs())

  it 'should split a polygon into two new polygons matching a specific area', ->
    getReadableArea = (polygon) ->
      L.GeometryUtil.readableArea(L.GeometryUtil.geodesicArea(polygon.getLatLngs()[0]), true)

    squareLatlngs = [[0, 0], [1, 0], [3, 0], [3, 3], [1, 3], [0, 3], [0, 0]]
    lineLatlngs = [[1, 0], [1, 3]]
    squarePolygon = L.polygon(squareLatlngs)
    splitLine = L.polyline(lineLatlngs)
    options = {}
    options.featureGroup = new L.FeatureGroup()
    klass = new L.Cut.Polyline(@map, options)
    firstRectangleLatlngs = [[0, 0], [1, 0], [1, 3], [0, 3], [0, 0]]
    secondRectangleLatlngs = [[1, 0], [3, 0], [3, 3], [1, 3], [1, 0]]
    firstRectangle = L.polygon(firstRectangleLatlngs)
    secondRectangle = L.polygon(secondRectangleLatlngs)
    splitResult = klass._cut(squarePolygon, splitLine)
    expect(getReadableArea(splitResult[0])).toEqual(getReadableArea(secondRectangle))
    expect(getReadableArea(splitResult[1])).toEqual(getReadableArea(firstRectangle))

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

  it 'should set the active layer as a snap target', ->
    handler = new L.Cut.Polyline(@map, featureGroup: L.featureGroup())
    handler._activeLayer = L.polygon [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]]

    handler._cutMode()

    splitter = handler._activeLayer.cutting
    expect(splitter.options.guideLayers).toContain(handler._activeLayer)
