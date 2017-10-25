# Leaflet.Draw.Cut

This plugin extends Leaflet.Draw to provide cut capabilities.
It takes advantage of RTree spatial index if available.

Works with Leaflet 1.2.0 and Leaflet.Draw 0.4.12

## Usage

```
options:
  position: 'topleft'
  featureGroup: undefined
  disabledPathOptions:
    dashArray: null
    fill: true
    fillColor: '#fe57a1'
    fillOpacity: 0.1
    maintainColor: true
  selectedPathOptions:
    dashArray: null
    fill: true
    fillColor: '#fe57a1'
    fillOpacity: 0.9
    maintainColor: true
  cuttingPathOptions:
    dashArray: '10, 10'
    fill: false
    color: '#fe57a1'

new L.Cut map,
  featureGroup: featureGroup
  selectedPathOptions: options.selectedPathOptions
  disabledPathOptions: options.disabledPathOptions
  cuttingPathOptions: options.cuttingPathOptions

```

## Installation
  Via NPM: ```npm install leaflet-draw-cut```

  Include ```dist/leaflet.draw.cut.js``` on your page.

  Or, if using via CommonJS (Browerify, Webpack, etc.):
  ```
var L = require('leaflet')
require('leaflet-draw-cut')
```
## Development  
This plugin is powered by webpack:

* Use ```npm run watch``` to automatically rebuild while developing.
* Use ```npm test``` to run unit tests.
* Use ```npm run build``` to minify for production use, in the ```dist/```
