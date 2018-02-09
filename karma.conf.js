// Karma configuration
// Generated on Mon Feb 05 2018 17:00:18 GMT+0100 (CET)

module.exports = function(config) {
  config.set({

    // base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '',

    // frameworks to use
    // available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['jasmine'],
    plugins: ['karma-phantomjs-launcher', 'karma-jasmine', 'karma-chrome-launcher', 'karma-webpack'],


    // list of files / patterns to load in the browser
    files: [
      'node_modules/leaflet/dist/leaflet-src.js',
      'node_modules/lodash/lodash.js',
      'node_modules/leaflet-draw/dist/leaflet.draw-src.js',
      'node_modules/leaflet-snap/leaflet.snap.js',
      'dist/*.js',
      'spec/*Spec.coffee'
    ],


    // list of files / patterns to exclude
    exclude: [
    ],

    webpack: {
      module: {
        rules: [{
            test: /.coffee$/,
            use: ['coffee-loader']
          }
        ]
      }
    },
    // preprocess matching files before serving them to the browser
    // available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      'spec/*Spec.coffee': ['webpack']
    },


    // test results reporter to use
    // possible values: 'dots', 'progress'
    // available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['progress'],


    // web server port
    port: 9876,


    // enable / disable colors in the output (reporters and logs)
    colors: true,


    // level of logging
    // possible values: config.LOG_DISABLE || config.LOG_ERROR || config.LOG_WARN || config.LOG_INFO || config.LOG_DEBUG
    logLevel: config.LOG_INFO,


    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: true,


    // start these browsers
    // available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: ['PhantomJSCustom', 'Chrome'],


    customLaunchers: {
			'PhantomJSCustom': {
				base: 'PhantomJS',
				flags: ['--load-images=true'],
				options: {
					onCallback: function (data) {
						if (data.render) {
							page.render(data.render);
						}
					}
				}
			}
		},

    // Continuous Integration mode
    // if true, Karma captures browsers, runs the tests and exits
    singleRun: false,

    // Concurrency level
    // how many browser should be started simultaneous
    concurrency: Infinity
  })
}
