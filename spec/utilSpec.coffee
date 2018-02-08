describe 'Util', ->
  describe 'L.Polygon', ->
    it 'should return a turf polygon from a L.Polygon', ->
      turfFeature = {
        type: "Feature",
        properties: {},
        geometry:
          type: 'Polygon',
          coordinates: [[
            [0, 0],
            [0, 1],
            [1, 1],
            [1, 0],
            [0, 0]
          ]]
      }
      polygon = L.polygon [[0,0], [1,0], [1,1], [0,1], [0,0]]
      expect(polygon.toTurfFeature()).toEqual(turfFeature)

    it 'should return a turf linestring from the outer ring of a L.Polygon', ->
      turfFeature = {
        type: "Feature",
        properties: {},
        geometry:
          type: 'LineString',
          coordinates: [
            [0, 0],
            [0, 1],
            [1, 1],
            [1, 0],
            [0, 0]
          ]
      }
      polygon = L.polygon [[0,0], [1,0], [1,1], [0,1], [0,0]]
      expect(polygon.outerRingAsTurfLineString()).toEqual(turfFeature)

  describe 'L.LatLng', ->
    it 'should return a turf point from a L.LatLng', ->
      turfFeature = {
        type: "Feature",
        properties: {},
        geometry:
          type: 'Point',
          coordinates: [0, 0]
      }

      latLng = L.latLng [0,0]
      expect(latLng.toTurfFeature()).toEqual(turfFeature)

  describe 'L.Polyline', ->
    it 'should return a turf linestring from a L.Polyline', ->
      turfFeature = {
        type: "Feature",
        properties: {},
        geometry:
          type: 'LineString',
          coordinates: [
            [0, 0],
            [1, 1]
          ]
      }
      polyline = L.polyline [[0,0], [1,1]]
      expect(polyline.toTurfFeature()).toEqual(turfFeature)

    it 'should return a L.Polyline from a turf feature', ->
      polylineFeature = turfFeature = {
        type: "Feature",
        properties: {},
        geometry:
          type: 'LineString',
          coordinates: [
            [0, 0],
            [1, 1]
          ]
      }
      polyline = L.polyline []
      polyline.fromTurfFeature turfFeature
      expect(polyline.toGeoJSON()).toEqual(polylineFeature)

  describe 'L.LayerGroup', ->
    beforeAll () ->
      poly1 = L.polygon [[0,0], [1,0], [1,1], [0,1], [0,0]]
      poly2 = L.polygon [[0,0], [1,0], [1,1], [0,1], [0,0]]
      @layerGroup = L.layerGroup [poly1, poly2]
      @layerGroup.getLayers()[0].feature = { properties: { uuid: '4d3d2bba-1c2c-4f82-8613-b83d15506c7d' } }
      @layerGroup.getLayers()[1].feature = { properties: { uuid: '4ff23368-4702-45bd-9b4b-db0d7cee6f95' } }

    it 'should return UUID of a layer', ->
      layer = @layerGroup.getLayers()[0]
      uuid = @layerGroup.getLayerUUID layer
      expect(uuid).toEqual(layer.feature.properties.uuid)

    it 'should check if layerGroup includes UUID', ->
      uuid = @layerGroup.getLayers()[0].feature.properties.uuid
      uuid2 = @layerGroup.getLayers()[1].feature.properties.uuid
      expect(@layerGroup.hasUUIDLayer(@layerGroup.getLayers()[0])).toBeTruthy()
