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

# String type parser
decodeString = (bytes, offset, length) ->
  end    = offset + length
  strs   = []
  
  # while there is text to read
  while offset < end
    buf = []
    ibuf = 0
    # while there's room for two entries in buf
    while offset < end and ibuf < 0xfffe
      b = bytes[offset++]
      if not (b & 0x80)
        # Add codepoint b
        buf[ibuf++] = b
        continue  
      i = 0
      while (b << i) & 0x40
        i++
      c = b & (0xff >> i)
      while i-- > 0
        if offset == end
          i = -1
          break
        b = bytes[offset++]
        if b & 0xc0 != 0x80
          i = -1
          offset--
          break
        c = (c << 6) | (b & 0x3f)
      if i < 0
        c = 0xfffd # Replacement character
      # Add codepoint c
      if c <= 0xffff
        buf[ibuf++] = c
      else
        c -= 0x10000
        buf[ibuf++] = 0xd800 + ((c >> 10) & 0x3ff)
        buf[ibuf++] = 0xdc00 + (c & 0x3ff)
    # Decode codepoints and add string to list
    strs.push String.fromCharCode(buf...)
  # Join and return decoded strings
  if strs.length == 1
    return strs[0]
  return strs.join("")


# Array lookup is faster than Math.pow: http://jsperf.com/math-pow-vs-array-lookup
prim = [null, false, "", true]


# Parse a BJSON document
@BJSON.parse = (buffer) ->
  #nstrbuf = Math.min(0xffff, buffer.byteLength + 1)
  #strbuf = new Uint16Array(nstrbuf)
  view = new DataView(buffer)
  bytes = new Uint8Array(buffer)
  offset = 0
  # Read BJSON item
  read = ->
    t  = bytes[offset++]
    tt = (t & 0x3c) >> 2    # High bits, indicating type
    st = t & 0x3            # Low bits, indicating size of size field
    # Types 0 and 3 are special cases, these take different arguments
    if tt is 0
      return prim[st]
    if tt is 3
      if st is 0
        val = view.getFloat32(offset, true)
      else
        val = view.getFloat64(offset, true)
      offset += 4 + 4 * st
      return val
    # If tt isn't 0 or 3, we must read a size field
    if st < 2
      if st is 0
        size = bytes[offset++]
      else
        size = view.getUint16(offset, true)
        offset += 2
    else 
      if st is 2
        size = view.getUint32(offset, true)
        offset += 4
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
        lower = view.getUint64(offset, true) 
        upper = view.getUint64(offset + 4, true)
        size = lower + upper * 0x100000000
        offset += 8
    if tt < 3
      return size * (3 - 2 * tt) # possible values are 1 and 2
    else if tt is 4 # String
      val = decodeString(bytes, offset, size)
      offset += size
      return val
    else
      if tt is 9 # Object
          end = offset + size
          obj = {}
          while offset < end
            key = read()
            val = read()
            obj[key] = val
          return obj
      else if tt is 8  # Array
        end = offset + size
        return (read() while offset < end)
      else if tt is 5 # ArrayBuffer
        val = buffer.slice(offset, size)
        offset += size
        return val
    throw new Error("Type doesn't exists!!!")
  return read()


#### BJSON Serialization

class SerializationContext
  constructor: (size = 4096) ->
    @buf    = new ArrayBuffer(size)
    @view   = new DataView(@buf)
    @bytes  = new Uint8Array(@buf)
    @offset = 0
  resize: (size) ->
    if @buf.byteLength - @offset < size
      @buf     = new ArrayBuffer((@offset + size) * 2)
      bytes   = new Uint8Array(@buf)
      bytes.set(@bytes)
      @bytes = bytes
      @view   = new DataView(@buf)

# Dictionary with serializers for different types, each taking a value and serializing to context
put = {}

# String serialization
# For DOM-string intepretation see: http://www.w3.org/TR/WebIDL/#idl-DOMString
# For UTF-8 encoding see: http://tools.ietf.org/html/rfc3629#section-3
put.string = (val, ctx) ->
  if val.length is 0
    ctx.resize(1)
    ctx.view.setUint8(ctx.offset, 0x2)
    ctx.offset += 1
  else
    bound = val.length * 3
    typeoffset = ctx.offset
    typesize(0x10, 0, bound, ctx)
    contentoffset = ctx.offset
    ctx.resize(bound)
    offset = ctx.offset
    bytes = ctx.bytes
    i = 0
    n = val.length
    while i < n
      c = val.charCodeAt(i++)
      size = 0
      first = 0
      if c < 0x80
        bytes[offset++] = c
        continue
      else if c < 0x800
        first = 0xc0
        size = 2
      else if c < 0xd800 or c > 0xdfff
        first = 0xe0
        size = 3
      else if 0xdc00 <= c <= 0xdfff
        c = 0xfffd  # Replacement character
        first = 0xe0
        size = 3
      else if 0xd800 <= c <= 0xdbff
        if i < n
          d = val.charCodeAt(i++)
          if 0xdc00 <= d <= 0xdfff
            a = c & 0x3ff
            b = d & 0x3ff
            c = 0x10000 + (a << 10) + b
            first = 0xf0
            size = 4
        else
          c = 0xfffd  # Replacement character
          first = 0xe0
          size = 3
      else
        # Specification doesn't derive any character from c
        continue
      j = offset + size - 1
      while j > offset
        bytes[j--] = (c & 0x3f) | 0x80
        c >>= 6
      bytes[offset] = c | first
      offset += size
    ctx.offset = typeoffset
    typesize(0x10, offset - contentoffset, bound, ctx)
    ctx.offset = offset

# Boolean serialization
put.boolean = (val, ctx) ->
  ctx.resize(1)
  ctx.view.setUint8(ctx.offset, 1 + val * 2)
  ctx.offset++

# Number serialization
put.number = (val, ctx) ->
  # If integer less than 2^32 encode as integer, otherwise we write it as 64 bit float.
  # Javascript only support 64 bit floats, so encoding anything bigger than 2^32 as
  # integer is pointless.
  if val % 1 is 0 and Math.abs(val) <= 0xffffffff
    if val > 0
      typesize(0x4, val, val, ctx)
    else
      typesize(0x8, -val, -val, ctx)
  else
    ctx.resize(9)
    ctx.view.setUint8(ctx.offset, 0xd)
    ctx.view.setFloat64(ctx.offset + 1, val, true)
    ctx.offset += 9

# Object serialization
put.object = (val, ctx) ->
  # Handle binary fields
  if val instanceof ArrayBuffer
    typesize(0x14, val.byteLength, val.byteLength, ctx)
    ctx.resize(val.byteLength)
    ctx.bytes.set(ctx.offset, new Uint8Array(val))
    ctx.offset += val.byteLength
  # Serialization of arrays
  else if val instanceof Array
    typeoffset = ctx.offset
    typesize(0x20, 0, 0x10000, ctx)
    contentoffset = ctx.offset
    for v in val
      put[typeof v](v, ctx)
    offset = ctx.offset
    ctx.offset = typeoffset
    typesize(0x20, offset - contentoffset, 0x10000, ctx)
    ctx.offset = offset
  # Serialize objects that isn't null
  else if val isnt null
    typeoffset = ctx.offset
    typesize(0x24, 0, 0x10000, ctx)
    contentoffset = ctx.offset
    for k, v of val
      put[typeof k](k, ctx)
      put[typeof v](v, ctx)
    offset = ctx.offset
    ctx.offset = typeoffset
    typesize(0x24, offset - contentoffset, 0x10000, ctx)
    ctx.offset = offset
  # Serialization of null
  else #if data is null
    ctx.resize(1)
    ctx.view.setUint8(ctx.offset, 0x0)
    ctx.offset++

# Write type and size field with enought bit s.t. size can grow to bound later
typesize = (type, size, bound, ctx) ->
  if size > bound
    bound = size
  if bound < 0x10000
    if bound < 0x100
      ctx.resize(2)
      ctx.view.setUint8(ctx.offset, type)
      ctx.view.setUint8(ctx.offset + 1, size)
      ctx.offset += 2
    else
      ctx.resize(3)
      ctx.view.setUint8(ctx.offset, type + 1)
      ctx.view.setUint16(ctx.offset + 1, size, true)
      ctx.offset += 3
  else if bound < 0x100000000
    ctx.resize(5)
    ctx.view.setUint8(ctx.offset, type + 2)
    ctx.view.setUint32(ctx.offset + 1, size, true)
    ctx.offset += 5
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
    ctx.resize(9)
    ctx.view.setUint8(ctx.offset, type + 3)
    ctx.view.setUint32(ctx.offset + 1, size & 0xffffffff, true)
    ctx.view.setUint32(ctx.offset + 5, (size - (size & 0xffffffff)) / 0x100000000, true)
    ctx.offset += 9

# Serialize a JSON document to BJSON
@BJSON.serialize = (val) ->
  ctx = new SerializationContext()
  put[typeof val](val, ctx)
  buf = new ArrayBuffer(ctx.offset)
  bytes = new Uint8Array(buf)
  bytes.set(new Uint8Array(ctx.buf, 0, ctx.offset))
  return buf #ctx.buf.splice(0, ctx.offset)
