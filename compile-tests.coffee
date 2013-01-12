#!/usr/bin/env coffee

fs = require 'fs'

source_folder = "#{__dirname}/tests/"
target_folder = "#{__dirname}/bin/"

testdata = {}
for test in fs.readdirSync(source_folder) when test[-5...] is ".json"
  data    = fs.readFileSync(source_folder + test)
  testdata[test] = JSON.parse(data)

fs.writeFileSync(target_folder + "test-data.js", "testData = #{JSON.stringify(testdata)};", 'utf8')
