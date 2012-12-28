fs            = require "fs"
{print}       = require "util"
{spawn, exec} = require "child_process"

coffee = "coffee"
coffee = "coffee.cmd"   if process.platform is "win32"

build = (watch = false) ->
  options = ["-c", "-o", "bin", "src", "utils"]
  options.unshift "-w" if watch
  coffee = spawn coffee, options
  coffee.stdout.on "data", (data) -> print data.toString()
  coffee.stderr.on "data", (data) -> print data.toString()
  coffee.on "exit", (status) ->
    if status is 0
      print "Coffee completed.\n"
    else
      print "Coffee failed!\n"

task "generate", "Generate test data", ->
  options = ["compile-tests.coffee"]
  coffee = spawn coffee, options
  coffee.stdout.on "data", (data) -> print data.toString()
  coffee.stderr.on "data", (data) -> print data.toString()
  coffee.on "exit", (status) ->
    if status is 0
      print "Test data generated.\n"
    else
      print "Test data generation failed!\n"

task "build", "Compile CoffeeScript files to Javascript", ->
  build()

task "watch", "Rebuild when files are changed", ->
  build(true)

task "clean", "Cleanup generated files", ->
  exec "rm -rf bin/", (status, stdout, stderr) ->


