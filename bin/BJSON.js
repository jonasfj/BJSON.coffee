// Generated by CoffeeScript 1.3.3
(function() {
  var prim, put, read, sizes, type, typesize, _ref,
    __slice = [].slice;

  if ((_ref = this.BJSON) == null) {
    this.BJSON = {};
  }

  type = [];

  prim = [null, false, "", true];

  type[0] = function(st) {
    return prim[st];
  };

  type[1] = function(val) {
    return val;
  };

  type[2] = function(val) {
    return -val;
  };

  type[3] = function(st, ctx) {
    var val;
    if (st === 0) {
      val = ctx.view.getFloat32(ctx.offset, true);
    } else {
      val = ctx.view.getFloat64(ctx.offset, true);
    }
    ctx.offset += 4 + 4 * st;
    return val;
  };

  type[4] = function(size, ctx) {
    var val;
    val = TextDecoder('utf-8').decode(new Uint8Array(ctx.buffer, ctx.offset, size));
    ctx.offset += size;
    return val;
  };

  type[5] = function(size, ctx) {
    var val;
    val = ctx.buffer.slice(ctx.offset, size);
    ctx.offset += size;
    return val;
  };

  type[6] = null;

  type[7] = null;

  type[8] = function(size, ctx) {
    var end;
    end = ctx.offset + size;
    return ((function() {
      var _results;
      _results = [];
      while (ctx.offset < end) {
        _results.push(read(ctx));
      }
      return _results;
    })());
  };

  type[9] = function(size, ctx) {
    var end, key, obj, val;
    end = ctx.offset + size;
    obj = {};
    while (ctx.offset < end) {
      key = read(ctx);
      val = read(ctx);
      obj[key] = val;
    }
    return obj;
  };

  sizes = [1, 2, 4, 8];

  read = function(ctx) {
    var lower, size, st, t, tt, upper;
    t = ctx.view.getUint8(ctx.offset++);
    tt = Math.floor(t / 4);
    st = t % 4;
    if (tt === 0 || tt === 3) {
      return type[tt](st, ctx);
    }
    if (st < 2) {
      if (st === 0) {
        size = ctx.view.getUint8(ctx.offset);
      } else {
        size = ctx.view.getUint16(ctx.offset, true);
      }
    } else {
      if (st === 2) {
        size = ctx.view.getUint32(ctx.offset, true);
      } else {
        lower = ctx.view.getUint64(ctx.offset, true);
        upper = ctx.view.getUint64(ctx.offset + 4, true);
        size = lower + upper * 0x100000000;
      }
    }
    ctx.offset += sizes[st];
    return type[tt](size, ctx);
  };

  this.BJSON.parse = function(buf) {
    return read({
      buffer: buf,
      view: new DataView(buf),
      offset: 0
    });
  };

  put = {};

  put.string = function(data) {
    var buf, parts;
    if (data.length === 0) {
      buf = new ArrayBuffer(1);
      (new DataView(buf)).setUint8(0, 0x2);
      return {
        size: 1,
        parts: [buf]
      };
    }
    parts = [null];
    parts[1] = TextEncoder('utf-8').encode(data);
    parts[0] = typesize(0x10, parts[1].byteLength);
    return {
      size: parts[0].byteLength + parts[1].byteLength,
      parts: parts
    };
  };

  put.boolean = function(data) {
    var buf;
    buf = new ArrayBuffer(1);
    (new DataView(buf)).setUint8(0, 1 + data * 2);
    return {
      size: 1,
      parts: [buf]
    };
  };

  put.number = function(data) {
    var buf, size, view;
    if (data % 1 === 0 && Math.abs(data) <= 0xffffffff) {
      if (data > 0) {
        buf = typesize(0x4, data);
      } else {
        buf = typesize(0x8, -data);
      }
      size = buf.byteLength;
    } else {
      buf = new ArrayBuffer(9);
      view = new DataView(buf);
      view.setUint8(0, 0xd);
      view.setFloat64(1, data, true);
      size = 9;
    }
    return {
      size: size,
      parts: [buf]
    };
  };

  put.object = function(data) {
    var key, kp, ks, parts, size, val, vp, vs, _i, _len, _ref1, _ref2, _ref3;
    parts = [null];
    size = 0;
    if (data instanceof ArrayBuffer) {
      parts[0] = typesize(0x14, size);
      size += parts[0].byteLength;
      parts.push(data);
      size += data.byteLength;
    } else if (data instanceof Array) {
      for (_i = 0, _len = data.length; _i < _len; _i++) {
        val = data[_i];
        _ref1 = put[typeof val](val), vs = _ref1.size, vp = _ref1.parts;
        parts.push.apply(parts, vp);
        size += vs;
      }
      parts[0] = typesize(0x20, size);
      size += parts[0].byteLength;
    } else if (data !== null) {
      for (key in data) {
        val = data[key];
        _ref2 = put[typeof key](key), ks = _ref2.size, kp = _ref2.parts;
        _ref3 = put[typeof val](val), vs = _ref3.size, vp = _ref3.parts;
        parts.push.apply(parts, __slice.call(kp).concat(__slice.call(vp)));
        size += ks + vs;
      }
      parts[0] = typesize(0x24, size);
      size += parts[0].byteLength;
    } else {
      parts[0] = new ArrayBuffer(1);
      (new DataView(parts[0])).setUint8(0, 0x0);
      size = 1;
    }
    return {
      size: size,
      parts: parts
    };
  };

  typesize = function(type, size, buf) {
    var view;
    if (size < 0x10000) {
      if (size < 0x100) {
        if (buf == null) {
          buf = new ArrayBuffer(2);
        }
        view = new DataView(buf);
        view.setUint8(0, type);
        view.setUint8(1, size);
      } else {
        if (buf == null) {
          buf = new ArrayBuffer(3);
        }
        view = new DataView(buf);
        view.setUint8(0, type + 1);
        view.setUint16(1, size, true);
      }
    } else if (size < 0x100000000) {
      if (buf == null) {
        buf = new ArrayBuffer(5);
      }
      view = new DataView(buf);
      view.setUint8(0, type + 2);
      view.setUint32(1, size, true);
    } else {
      if (buf == null) {
        buf = new ArrayBuffer(9);
      }
      view = new DataView(buf);
      view.setUint8(0, type + 3);
      view.setUint32(1, size & 0xffffffff, true);
      view.setUint32(5, (size - (size & 0xffffffff)) / 0x100000000, true);
    }
    return buf;
  };

  this.BJSON.serialize = function(data) {
    var buf, offset, part, parts, size, view, _i, _len, _ref1;
    _ref1 = put[typeof data](data), size = _ref1.size, parts = _ref1.parts;
    offset = 0;
    buf = new ArrayBuffer(size);
    view = new Uint8Array(buf);
    for (_i = 0, _len = parts.length; _i < _len; _i++) {
      part = parts[_i];
      view.set(new Uint8Array(part), offset);
      offset += part.byteLength;
    }
    if (offset !== size) {
      throw "BJSON has an internal error: computed size didn't match actual size!";
    }
    return buf;
  };

}).call(this);
