
# A shim for ArrayBuffer.slice using Uint8Array
# Internet Explorer 10 and node.js doesn't support `ArrayBuffer.slice`.
ArrayBuffer::slice ?= (begin, end = @.byteLength) ->
  end   += @.byteLength    if end < 0     # Correct for negative offset
  begin += @.byteLength    if begin < 0   # Correct for negative offset
  end = begin              if end < begin # Correct for invalid range
  buf = new Uint8Array(end - begin)
  buf.set new Uint8Array(@, begin, end - begin)
  return buf.buffer

