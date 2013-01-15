#!/usr/bin/env coffee

require("#{__dirname}/../src/ArrayBufferSlice.coffee")

BJSON = require("#{__dirname}/../src/BJSON.coffee").BJSON

fs = require 'fs'

folder = "#{__dirname}/../tests/"
tests = []
for f in fs.readdirSync(folder) when f[-5...] is ".json"
  tests.push f[...-5]
tests.sort()

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

format = (str, len, args...) ->
  str = "#{str}"
  length = Math.max(Math.abs(len) - str.length, 0)
  padding = (" " for i in [0...length]).join("")
  reminder = ""
  if args.length != 0
    reminder = format(args...)
  if len < 0
    return padding + str + reminder
  return str + padding + reminder

# Terminal colors
reset     = "\u001b[0m"
bold      = (s) -> "\u001b[1m" + s + reset
underline = (s) -> "\u001b[4m" + s + reset
highlight = (s) -> "\u001b[47m" + s + reset

console.log underline bold format("Test:", 24, "size (JSON):", 15, "size (BJSON):", 15, "Compression:", 15, "Parse:", 10, "Serialize:", 0);

for test, i in tests
  # Load test data
  orig_json_data    = fs.readFileSync(folder + test + ".json")
  orig_bjson_data   = fs.readFileSync(folder + test + ".bjson")
  # Parse orignal JSON
  orig_json         = JSON.parse(orig_json_data)
  # Serialize and parse BJSON
  new_bjson         = BJSON.serialize(orig_json)
  new_json          = BJSON.parse(new_bjson)
  serialize_result  = compare(orig_json, new_json)
  # Stringify JSON for size ratio measure
  orig_json_data2   = new Buffer(JSON.stringify(new_json), 'utf8')
  # Parse BJSON file
  parsed_bjson      = BJSON.parse(orig_bjson_data)
  parse_result      = compare(orig_json, parsed_bjson)
  ratio   = Math.floor( (1 - new_bjson.byteLength / orig_json_data2.length) * 100) + "%"
  output = format(test, 24, orig_json_data2.length, -8, "", 7, new_bjson.byteLength, -8, "", 7, ratio, -8, "", 7)
  result = format(serialize_result, 10)
  if not serialize_result
    result = bold result
  output += result
  result = format(parse_result, 10)
  if not parse_result
    result = bold result
  output += result
  if i % 2 is 0
    output = highlight output
  console.log output
