///|
/// Stable failure categories for bounded JSON conversion. Errors are values so
/// servers can map them to a SCIM error response without catching exceptions.
pub(all) enum CodecError {
  InvalidJson(String)
  RootNotObject
  InputTooLarge(Int, Int)
  NestingTooDeep(Int)
  TooManyNodes(Int)
  DuplicateAttribute(String)
  NonFiniteNumber
} derive(Debug, Eq)

///|
/// Resource budgets applied before allocating a MoonSCIM value tree.
pub struct CodecLimits {
  max_chars : Int
  max_depth : Int
  max_nodes : Int
}

///|
/// Construct explicit JSON budgets. Defaults are suitable for ordinary SCIM
/// resources while remaining small enough for untrusted HTTP request bodies.
pub fn codec_limits(
  max_chars? : Int = 4 * 1024 * 1024,
  max_depth? : Int = 64,
  max_nodes? : Int = 100000,
) -> CodecLimits {
  { max_chars, max_depth, max_nodes, }
}

///|
priv struct Scanner {
  text : String
  limits : CodecLimits
  mut nodes : Int
}

///|
/// Decode any JSON value after a structural pass enforces resource limits and
/// rejects duplicate SCIM attributes case insensitively.
pub fn decode_value(
  text : String,
  limits? : CodecLimits = codec_limits(),
) -> Result[@value.Value, CodecError] {
  if text.length() > limits.max_chars {
    return Err(InputTooLarge(text.length(), limits.max_chars))
  }
  let scanner = Scanner::{ text, limits, nodes: 0, }
  let end = match scanner.scan_value(0, 0) {
    Ok(end) => scanner.skip_space(end)
    Err(error) => return Err(error)
  }
  if end != text.length() {
    return Err(InvalidJson("unexpected trailing JSON content"))
  }
  let parsed = @json.parse(text) catch {
    error => return Err(InvalidJson(error.to_string()))
  }
  Ok(from_json(parsed))
}

///|
/// Decode a SCIM resource object. Protocol endpoints normally use this entry
/// point so a valid scalar or array root cannot be mistaken for a resource.
pub fn decode_object(
  text : String,
  limits? : CodecLimits = codec_limits(),
) -> Result[@value.Object, CodecError] {
  match decode_value(text, limits~) {
    Ok(value) =>
      match value.as_object() {
        Some(object) => Ok(object)
        None => Err(RootNotObject)
      }
    Err(error) => Err(error)
  }
}

///|
/// Encode a JSON-shaped value with deterministic object field order.
pub fn encode_value(value : @value.Value) -> Result[String, CodecError] {
  match value.kind() {
    @value.ValueKind::Null => Ok("null")
    @value.ValueKind::Boolean =>
      Ok(if value.as_boolean().unwrap() { "true" } else { "false" })
    @value.ValueKind::Number => {
      let number = value.as_number().unwrap()
      if !finite(number) {
        Err(NonFiniteNumber)
      } else {
        Ok(Json::number(number).stringify())
      }
    }
    @value.ValueKind::String =>
      Ok(Json::string(value.as_string().unwrap()).stringify())
    @value.ValueKind::List => encode_list(value.as_list().unwrap())
    @value.ValueKind::Object => encode_object(value.as_object().unwrap())
  }
}

///|
pub fn encode_object(object : @value.Object) -> Result[String, CodecError] {
  let fields : Array[String] = []
  for entry in object.entries() {
    let encoded = match encode_value(entry.value()) {
      Ok(encoded) => encoded
      Err(error) => return Err(error)
    }
    fields.push(Json::string(entry.name()).stringify() + ":" + encoded)
  }
  Ok("{" + fields.join(",") + "}")
}

///|
fn encode_list(values : Array[@value.Value]) -> Result[String, CodecError] {
  let items : Array[String] = []
  for value in values {
    match encode_value(value) {
      Ok(encoded) => items.push(encoded)
      Err(error) => return Err(error)
    }
  }
  Ok("[" + items.join(",") + "]")
}

///|
fn finite(value : Double) -> Bool {
  value == value && value.abs() <= 1.7976931348623157e308
}

///|
fn from_json(value : Json) -> @value.Value {
  match value {
    Null => @value.null_value()
    True => @value.boolean(true)
    False => @value.boolean(false)
    Number(number, ..) => @value.number(number)
    String(text) => @value.string(text)
    Array(items) => @value.list(items.map(from_json))
    Object(items) => {
      let fields : Array[@value.Field] = []
      for name, item in items {
        fields.push(@value.field(name, from_json(item)))
      }
      @value.object_value(fields)
    }
  }
}

///|
fn Scanner::scan_value(
  self : Scanner,
  start : Int,
  depth : Int,
) -> Result[Int, CodecError] {
  let cursor = self.skip_space(start)
  if cursor >= self.text.length() {
    return Err(InvalidJson("unexpected end of JSON"))
  }
  self.nodes = self.nodes + 1
  if self.nodes > self.limits.max_nodes {
    return Err(TooManyNodes(self.nodes))
  }
  let character = self.text[cursor].to_int().unsafe_to_char()
  match character {
    '{' => {
      let nested = depth + 1
      if nested > self.limits.max_depth {
        Err(NestingTooDeep(nested))
      } else {
        self.scan_object(cursor + 1, nested)
      }
    }
    '[' => {
      let nested = depth + 1
      if nested > self.limits.max_depth {
        Err(NestingTooDeep(nested))
      } else {
        self.scan_array(cursor + 1, nested)
      }
    }
    '"' => self.scan_string_end(cursor)
    '}' | ']' | ',' | ':' =>
      Err(InvalidJson("expected JSON value at offset \{cursor}"))
    _ => self.scan_primitive(cursor)
  }
}

///|
fn Scanner::scan_object(
  self : Scanner,
  start : Int,
  depth : Int,
) -> Result[Int, CodecError] {
  let keys : Array[String] = []
  let mut cursor = self.skip_space(start)
  if self.at(cursor, '}') {
    return Ok(cursor + 1)
  }
  while cursor < self.text.length() {
    if !self.at(cursor, '"') {
      return Err(InvalidJson("object key must be a string at offset \{cursor}"))
    }
    let after_key = match self.scan_string_end(cursor) {
      Ok(end) => end
      Err(error) => return Err(error)
    }
    let token = self.text[cursor:after_key].to_owned()
    let decoded_key : Json = @json.parse(token) catch {
      _ => return Err(InvalidJson("invalid object key at offset \{cursor}"))
    }
    let key = match decoded_key {
      String(value) => value
      _ => return Err(InvalidJson("object key must be a string"))
    }
    let folded = key.to_lower()
    if keys.contains(folded) {
      return Err(DuplicateAttribute(key))
    }
    keys.push(folded)
    cursor = self.skip_space(after_key)
    if !self.at(cursor, ':') {
      return Err(InvalidJson("object key must be followed by ':'"))
    }
    cursor = match self.scan_value(cursor + 1, depth) {
      Ok(end) => self.skip_space(end)
      Err(error) => return Err(error)
    }
    if self.at(cursor, ',') {
      cursor = self.skip_space(cursor + 1)
      continue
    }
    if self.at(cursor, '}') {
      return Ok(cursor + 1)
    }
    return Err(InvalidJson("object is not terminated"))
  }
  Err(InvalidJson("unexpected end of object"))
}

///|
fn Scanner::scan_array(
  self : Scanner,
  start : Int,
  depth : Int,
) -> Result[Int, CodecError] {
  let mut cursor = self.skip_space(start)
  if self.at(cursor, ']') {
    return Ok(cursor + 1)
  }
  while cursor < self.text.length() {
    cursor = match self.scan_value(cursor, depth) {
      Ok(end) => self.skip_space(end)
      Err(error) => return Err(error)
    }
    if self.at(cursor, ',') {
      cursor = self.skip_space(cursor + 1)
      continue
    }
    if self.at(cursor, ']') {
      return Ok(cursor + 1)
    }
    return Err(InvalidJson("array is not terminated"))
  }
  Err(InvalidJson("unexpected end of array"))
}

///|
fn Scanner::scan_string_end(
  self : Scanner,
  start : Int,
) -> Result[Int, CodecError] {
  let mut cursor = start + 1
  let mut escaped = false
  while cursor < self.text.length() {
    let character = self.text[cursor].to_int().unsafe_to_char()
    if escaped {
      escaped = false
    } else if character == '\\' {
      escaped = true
    } else if character == '"' {
      return Ok(cursor + 1)
    } else if character.to_int() < 32 {
      return Err(InvalidJson("control character in JSON string"))
    }
    cursor = cursor + 1
  }
  Err(InvalidJson("unterminated JSON string"))
}

///|
fn Scanner::scan_primitive(
  self : Scanner,
  start : Int,
) -> Result[Int, CodecError] {
  let mut cursor = start
  while cursor < self.text.length() {
    let character = self.text[cursor].to_int().unsafe_to_char()
    if character == ',' ||
      character == ']' ||
      character == '}' ||
      whitespace(character) {
      break
    }
    cursor = cursor + 1
  }
  if cursor == start {
    Err(InvalidJson("invalid JSON value at offset \{start}"))
  } else {
    Ok(cursor)
  }
}

///|
fn Scanner::skip_space(self : Scanner, start : Int) -> Int {
  let mut cursor = start
  while cursor < self.text.length() &&
        whitespace(self.text[cursor].to_int().unsafe_to_char()) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn Scanner::at(self : Scanner, offset : Int, wanted : Char) -> Bool {
  offset < self.text.length() &&
  self.text[offset].to_int().unsafe_to_char() == wanted
}

///|
fn whitespace(character : Char) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\r' ||
  character == '\n'
}
