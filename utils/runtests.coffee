#!/usr/bin/env coffee

# Import TextEncoder and TextDecoder into global scope
{
  TextDecoder: global.TextDecoder
  TextEncoder: global.TextEncoder
} = require "#{__dirname}/../src/encoding.js"

BJSON = require("#{__dirname}/../src/BJSON.coffee").BJSON

fs = require 'fs'

folder = "#{__dirname}/../tests/"
tests = fs.readdirSync(folder)
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

console.log underline bold format("Test:", 24, "size (JSON):", 15, "size (BJSON):", 15, "Compression:", 15, "Success:", 0);

for test, i in tests
  data    = fs.readFileSync(folder + test)
  json    = JSON.parse(data)
  bjson   = BJSON.serialize(json)
  json2   = BJSON.parse(bjson)
  data2   = new Buffer(JSON.stringify(json2), 'utf8')
  result  = compare(json, json2)
  mod = (s) -> s
  if not result
    mod = (s) -> bold s
  ratio   = Math.floor( (1 - bjson.byteLength / data.length) * 100) + "%"
  output = format(test, 24, data2.length, -8, "", 7, bjson.byteLength, -8, "", 7, ratio, -8, "", 7) + mod format(result, 8)
  if i % 2 is 0
    output = highlight output
  console.log output
