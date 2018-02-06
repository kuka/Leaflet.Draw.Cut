describe('DrawCutPolyline', function() {
  var polygon;
  var latlngs;
  var test;

  beforeEach(function() {
    this.latlngs = [[37, -109.05],[41, -109.03],[41, -102.05],[37, -102.04]];
    this.polygon = new L.Polygon(this.latlngs);
    // var mapElement = document.createElement('div');
    // document.body.append(mapElement);
    // this.map = new L.Map(mapElement).setView [0, 0], 15
    this.map = new L.Map(document.createElement('div')).setView [0, 0], 15
  });

  it('test', function() {
    var options = {};
    options.featureGroup = new L.FeatureGroup();
    klass = new L.Cut.Polyline(this.map, options);
    console.error(this.polygon.getLatLngs()[0][0].lat);
    expect(this.polygon.getLatLngs()[0][0].lat).toBe(37)
  });
});
