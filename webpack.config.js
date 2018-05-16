module.exports = {
  module: {
    rules: [{
        test: /\.js/,
        use: ['babel-loader']
      }
    ]
  },
  entry: ['./src/leaflet.draw.cut.js', './src/leaflet.draw.cut.polyline.js', './src/util.js', './src/geographic_util.js', './src/leaflet.draw.overlapping.drawing.locking.js'],
  output: {
    path: __dirname + '/dist',
    filename: 'leaflet.draw.cut.js'
  },
  externals: {
    'leaflet': 'L',
    'lodash': '_'
  },
  resolve: {
    extensions: ['.js', '.js']
  }
}
