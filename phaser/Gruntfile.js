// Generated on 2014-03-28 using generator-phaser-official 0.0.8-rc-2
'use strict';
var config = require('./config.json');
var _ = require('underscore');
_.str = require('underscore.string');

// Mix in non-conflict functions to Underscore namespace if you want
_.mixin(_.str.exports());

var LIVERELOAD_PORT = 35729;
var lrSnippet = require('connect-livereload')({port: LIVERELOAD_PORT});
var mountFolder = function (connect, dir) {
  return connect.static(require('path').resolve(dir));
};

module.exports = function (grunt) {
  // load all grunt tasks
  require('matchdep').filterDev('grunt-*').forEach(grunt.loadNpmTasks);
  var path = require('path');
 
  // https://gist.github.com/cowboy/3819170
  grunt.registerMultiTask('subgrunt', 'Run a sub-project\'s grunt tasks.', function() {
    if (!grunt.file.exists(this.data.subdir)) {
      grunt.log.error('Directory "' + this.data.subdir + '" not found.');
      return false;
    }
    var done = this.async();
    var subdir = path.resolve(this.data.subdir);
    grunt.util.spawn({
      cmd: 'grunt',
      args: this.data.args || [],
      opts: {cwd: subdir},
    }, function(error, result, code) {
      if (code === 127) {
        grunt.log.error('Error running sub-grunt. Did you run "npm install" in the sub-project?');
      } else {
        grunt.log.writeln('\n' + result.stdout);
      }
      done(code === 0);
    });
  });

  grunt.initConfig({
    subgrunt: {
        phaser: {
            subdir: './phaser/',
            args: ['build'],
        },
    },
    watch: {
      scripts: {
        files: [
            'game/**/*.js',
            'assets/levels/*.txt',
            '!game/main.js'
        ],
        options: {
          spawn: false,
          livereload: LIVERELOAD_PORT
        },
        tasks: ['build']
      }
    },
    connect: {
      options: {
        port: 9000,
        // change this to '0.0.0.0' to access the server from outside
        hostname: 'localhost'
      },
      livereload: {
        options: {
          middleware: function (connect) {
            return [
              lrSnippet,
              mountFolder(connect, 'dist')
            ];
          }
        }
      }
    },
    open: {
      server: {
        path: 'http://localhost:9000'
      }
    },
    copy: {
      dist: {
        files: [
          // includes files within path and its sub-directories
          { expand: true, src: ['assets/**'], dest: 'dist/' },
          { expand: true, flatten: true, src: ['game/plugins/*.js'], dest: 'dist/js/plugins/' },
          { expand: true, flatten: true, src: ['phaser/dist/*.js'], dest: 'dist/js/' },
          { expand: true, flatten: true, src: ['bower_components/**/dist/*.js'], dest: 'dist/js/' },
          { expand: true, src: ['css/**'], dest: 'dist/' },
          { expand: true, src: ['index.html'], dest: 'dist/' }
        ]
      }
    },
    browserify: {
      build: {
        src: ['game/main.js'],
        dest: 'dist/js/game.js'
      }
    }
  });

  grunt.registerTask('build', ['buildBootstrapper', 'browserify','copy']);
  grunt.registerTask('phaser', ['subgrunt']);
  grunt.registerTask('serve', ['build', 'connect:livereload', 'open', 'watch']);
  grunt.registerTask('default', ['serve']);
  grunt.registerTask('prod', ['build', 'copy']);

  grunt.registerTask('buildBootstrapper', 'builds the bootstrapper file correctly', function() {
    var stateFiles = grunt.file.expand('game/states/*.js');
    var gameStates = [];
    var statePattern = new RegExp(/(\w+).js$/);
    stateFiles.forEach(function(file) {
      var state = file.match(statePattern)[1];
      if (!!state) {
        gameStates.push({shortName: state, stateName: _.capitalize(state) + 'State'});
      }
    });
    config.gameStates = gameStates;
    console.log(config);
    var bootstrapper = grunt.file.read('templates/_main.js.tpl');
    bootstrapper = grunt.template.process(bootstrapper,{data: config});
    grunt.file.write('game/main.js', bootstrapper);
  });
};
