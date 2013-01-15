#!/usr/bin/env coffee

require("#{__dirname}/../src/ArrayBufferSlice.coffee")
BJSON = require("#{__dirname}/../src/BJSON.coffee").BJSON

fs = require 'fs'
Benchmark = require('benchmark').Benchmark
folder = "#{__dirname}/../tests/"


compare = (e1, e2) ->
  return true       if e1 == e2
  if e1 instanceof Array or e2 instanceof Array
    return false    if not (e1 instanceof Array and e2 instanceof Array)
    return false    if e1.length != e2.length
    for i in [0...e1.length]
      return false  if not compare(e1[i], e2[i])
    return true
  if typeof e1 is 'object' or typeof e2 is 'object'
    return false    if not (typeof e1 is 'object' and typeof e2 is 'object')
    keys = [k for k, v of e1]
    return false      if not compare(keys, [k for k, v of e2])
    for key in keys
      return false  if not compare(e1[key], e2[key])
    return true
  return false

suite = new Benchmark.Suite()

# Let's create a long ascii string
ascii_string = new Uint8Array(1024 * 512)
offset = 0
while offset < ascii_string.length
  ascii_string[offset++] = Math.random() * 127

testCases = [
  "utf8-poems",
  "18 long-string",
  "complex",
  "youtube-featured",
  "33 array",
  "34 long-array",
  "bitly-hotphrases",
  "youtube-search",
  "bitly-hotphrases"
]

parsers =
  BJSON:  BJSON.parse

console.log "\nTesting Parsers:"
for test in testCases
  orig_json_data = fs.readFileSync(folder + test + ".json")
  orig_json         = JSON.parse(orig_json_data)
  bjson             = BJSON.serialize(orig_json)
  for name, parser of parsers
    console.log "#{name}.parse(#{test}): " + compare(orig_json, parser(bjson))
    do (parser, bjson) ->
      suite.add "#{name}.parse(#{test})", -> parser(bjson)

# Run suites
console.log "\nBenchmarks:"
suite.run()
for test in suite
  console.log test.toString()
console.log ""
