describe('DrawCutPolyline', function() {

  beforeEach(function() {
    this.map = new L.Map(document.createElement('div')).setView([0, 0], 15);
  });

  it('should split a polygon into two new polygons matching specific coordinates', function() {
    var squareLatlngs = [[0, 0], [2, 0], [2, 2], [0, 2], [0, 0]];
    var lineLatlngs = [[0, 0], [2, 2]];
    var squarePolygon = L.polygon(squareLatlngs);
    var splitLine = L.polyline(lineLatlngs);
    var options = {};
    options.featureGroup = new L.FeatureGroup();
    var klass = new L.Cut.Polyline(this.map, options);
    var firstTriangleLatlngs = [[2, 2], [2, 0], [0, 0], [2, 2]];
    var secondTriangleLatlngs = [[0, 0], [2, 2], [0, 2], [0, 0]];
    var firstTriangle = L.polygon(firstTriangleLatlngs);
    var secondTriangle = L.polygon(secondTriangleLatlngs);
    var splitResult = klass._cut(squarePolygon, splitLine);
    expect(splitResult[0].getLatLngs()).toEqual(firstTriangle.getLatLngs());
    expect(splitResult[1].getLatLngs()).toEqual(secondTriangle.getLatLngs());
    expect(splitResult[2].getLatLngs()).toEqual(splitLine.getLatLngs());
  });

  it('should split a polygon into two new polygons matching a specific area', function() {
    function getReadableArea(polygon) {
      L.GeometryUtil.readableArea(L.GeometryUtil.geodesicArea(polygon.getLatLngs()[0]), true);
    }
    var squareLatlngs = [[0, 0], [1, 0], [3, 0], [3, 3], [1, 3], [0, 3], [0, 0]];
    var lineLatlngs = [[1, 0], [1, 3]];
    var squarePolygon = L.polygon(squareLatlngs);
    var splitLine = L.polyline(lineLatlngs);
    var options = {};
    options.featureGroup = new L.FeatureGroup();
    var klass = new L.Cut.Polyline(this.map, options);
    var firstRectangleLatlngs = [[0, 0], [1, 0], [1, 3], [0, 3], [0, 0]];
    var secondRectangleLatlngs = [[1, 0], [3, 0], [3, 3], [1, 3], [1, 0]];
    var firstRectangle = L.polygon(firstRectangleLatlngs);
    var secondRectangle = L.polygon(secondRectangleLatlngs);
    var splitResult = klass._cut(squarePolygon, splitLine);
    expect(getReadableArea(splitResult[0])).toEqual(getReadableArea(secondRectangle));
    expect(getReadableArea(splitResult[1])).toEqual(getReadableArea(firstRectangle));
  });
});
