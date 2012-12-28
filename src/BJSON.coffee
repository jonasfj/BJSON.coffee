# Copyright 2012 Jonas Finnemann Jensen <jopsen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

@BJSON ?= {}

#### BJSON Parser

# Parse functions for different types
# Type is defined in the BJSON specification, we choose a type parser
# using the 6 high bits of the type field.
type = []

# Primitive type parse
prim = [null, false, "", true]
type[0] = (st)        -> prim[st]

# Positive integer type parser
type[1] = (val)       -> val

# Negative integer type parser
type[2] = (val)       -> - val

# Floating point type parser
type[3] = (st, ctx)   ->
  if st is 0
    val = ctx.view.getFloat32(ctx.offset, true)
  else
    val = ctx.view.getFloat64(ctx.offset, true)
  ctx.offset += 4 + 4 * st
  return val

# String type parser
type[4] = (size, ctx) ->
  val = TextDecoder('utf-8').decode(new Uint8Array(ctx.buffer, ctx.offset, size))
  ctx.offset += size
  return val

# Binary blob type parser
type[5] = (size, ctx) ->
  val = ctx.buffer.slice(ctx.offset, size)
  ctx.offset += size
  return val

# Unused types
type[6] = null
type[7] = null

# Array type parser
type[8] = (size, ctx) ->
  end = ctx.offset + size
  return (read(ctx) while ctx.offset < end)

# Object type parser
type[9] = (size, ctx) ->
  end = ctx.offset + size
  obj = {}
  while ctx.offset < end
    key = read(ctx)
    val = read(ctx)
    obj[key] = val
  return obj

# Array lookup is faster than Math.pow: http://jsperf.com/math-pow-vs-array-lookup
sizes = [1, 2, 4, 8]

# Read BJSON item
read = (ctx) ->
  t  = ctx.view.getUint8(ctx.offset++)
  tt = Math.floor(t / 4)  # Type form the type array
  st = t % 4              # Low bits, indicating size of size field
  # Types 0 and 3 are special cases, these take different arguments
  if tt is 0 or tt is 3
    return type[tt](st, ctx)
  # Types not 0 or 3 depends on an integer whos size can be read from the low bits.
  if st < 2
    if st is 0
      size = ctx.view.getUint8(ctx.offset)
    else
      size = ctx.view.getUint16(ctx.offset, true)
  else
    if st is 2
      size = ctx.view.getUint32(ctx.offset, true)
    else
      # This code path is untested, and will fail for numbers larger
      # than 2^53, but let's hope documents large than 4GiB are unlikely.
      # Technically, Javascript supports integers up to 2^53, however,
      # bitwise operations on more than 32bit integers is not possible.
      # This is why we use addition and multiplication to combine the
      # upper and lower parts of the 64 bit integer.
      # This transformation could have nasty side effects, who, knows...
      # But browsers probably doesn't support ArrayBuffers larger than
      # 4GiB anyway.
      lower = ctx.view.getUint64(ctx.offset, true) 
      upper = ctx.view.getUint64(ctx.offset + 4, true)
      size = lower + upper * 0x100000000
  ctx.offset += sizes[st]
  return type[tt](size, ctx)

# Parse a BJSON document
@BJSON.parse = (buf) ->
  # Create a context and read using it
  return read
      buffer: buf
      view:   new DataView(buf)
      offset: 0

#### BJSON Serialization

# Dictionary with serializers for different types, each returning a dictionary
# of {size, parts}, where size is accumulated size of the ArrayBuffers in parts
put = {}

# String serialization
put.string = (data) ->
  if data.length is 0
    buf = new ArrayBuffer(1)
    (new DataView(buf)).setUint8(0, 0x2)
    return {size: 1, parts: [buf]}
  parts = [null]
  parts[1] = TextEncoder('utf-8').encode(data)
  parts[0] = typesize(0x10, parts[1].byteLength)
  return {size: parts[0].byteLength + parts[1].byteLength, parts}

# Boolean serialization
put.boolean = (data) ->
  buf = new ArrayBuffer(1)
  (new DataView(buf)).setUint8(0, 1 + data * 2)
  return {size: 1, parts: [buf]}

# Number serialization
put.number = (data) ->
  # If integer less than 2^32 encode as integer, otherwise we write it as 64 bit float.
  # Javascript only support 64 bit floats, so encoding anything bigger than 2^32 as
  # integer is pointless.
  if data % 1 is 0 and Math.abs(data) <= 0xffffffff
    if data > 0
      buf = typesize(0x4, data)
    else
      buf = typesize(0x8, -data)
    size = buf.byteLength
  else
    buf = new ArrayBuffer(9)
    view = new DataView(buf)
    view.setUint8(0, 0xd)
    view.setFloat64(1, data, true)
    size = 9
  return {size, parts: [buf]}

# Object serialization
put.object = (data) ->
  parts = [null]
  size  = 0
  # Handle binary fields
  if data instanceof ArrayBuffer
    parts[0] = typesize(0x14, size)
    size += parts[0].byteLength
    parts.push data
    size += data.byteLength
  # Serialization of arrays
  else if data instanceof Array
    for val in data
      {size: vs, parts: vp} = put[typeof val](val)
      parts.push vp...
      size += vs
    parts[0] = typesize(0x20, size)
    size += parts[0].byteLength
  # Serialize objects that isn't null
  else if data isnt null
    for key, val of data
      {size: ks, parts: kp} = put[typeof key](key)
      {size: vs, parts: vp} = put[typeof val](val)
      parts.push kp..., vp...
      size += ks + vs
    parts[0] = typesize(0x24, size)
    size += parts[0].byteLength
  # Serialization of null
  else #if data is null
    parts[0] = new ArrayBuffer(1)
    (new DataView(parts[0])).setUint8(0, 0x0)
    size = 1
  return {size, parts}

# Write type and size field, writing the low bits of the type field depending
# on the number of bits required to write the size field.
typesize = (type, size, buf) ->
  if size < 0x10000
    if size < 0x100
      buf ?= new ArrayBuffer(2)
      view = new DataView(buf)
      view.setUint8(0, type)
      view.setUint8(1, size)
    else
      buf ?= new ArrayBuffer(3)
      view = new DataView(buf)
      view.setUint8(0, type + 1)
      view.setUint16(1, size, true)
  else if size < 0x100000000
    buf ?= new ArrayBuffer(5)
    view = new DataView(buf)
    view.setUint8(0, type + 2)
    view.setUint32(1, size, true)
  else
    # This code path is untested, will fail for numbers larger than
    # 2^53 as Javascript numbers are 64bit floats.
    # But let's hope documents larger 4GiB are unlikely, and assume
    # documents larger than 9 PetaBytes isn't relevant.
    #
    # BJSON.coffee encodes numbers larger than 2^32 as 64 bit floats,
    # however, other BJSON implementations could implement them as
    # numbers, in which case this code is best effort to read these
    # numbers.
    #
    # Technically, Javascript supports integers up to 2^53, however,
    # bitwise operations on more than 32bit integers is not possible.
    # This is why we use subtractions and division to find the upper
    # 32 bits of the 64 bit integer. This transformation could have
    # nasty side effects, who, knows... But browsers probably doesn't
    # support ArrayBuffers larger than 4GiB anyway.
    buf ?= new ArrayBuffer(9)
    view = new DataView(buf)
    view.setUint8(0, type + 3)
    view.setUint32(1, size & 0xffffffff, true)
    view.setUint32(5, (size - (size & 0xffffffff)) / 0x100000000, true)
  return buf

# Serialize a JSON document to BJSON
@BJSON.serialize = (data) ->
  {size, parts} = put[typeof data](data)
  offset = 0
  buf = new ArrayBuffer(size)
  view = new Uint8Array(buf)
  for part in parts
    view.set(new Uint8Array(part), offset)
    offset += part.byteLength
  if offset != size
    throw "BJSON has an internal error: computed size didn't match actual size!"
  return buf

