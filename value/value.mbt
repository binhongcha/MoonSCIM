///|
/// Stable public category for a SCIM value.
pub(all) enum ValueKind {
  Null
  Boolean
  Number
  String
  List
  Object
} derive(Debug, Eq)

///|
/// A JSON-shaped value used by every MoonSCIM semantic module. Object and list
/// payloads remain opaque so callers cannot mutate shared internal arrays.
pub enum Value {
  Null
  Boolean(Bool)
  Number(Double)
  String(String)
  List(Array[Value])
  Object(Object)
} derive(Debug, Eq)

///|
/// One spelling-preserving object field.
pub struct Field {
  name : String
  value : Value
} derive(Debug, Eq)

///|
/// A deterministic SCIM object. Attribute lookup is case insensitive while
/// insertion order and the first declared spelling are preserved.
pub struct Object {
  fields : Array[Field]
} derive(Debug, Eq)

///|
pub fn null_value() -> Value {
  Value::Null
}

///|
pub fn boolean(value : Bool) -> Value {
  Value::Boolean(value)
}

///|
pub fn number(value : Double) -> Value {
  Value::Number(value)
}

///|
pub fn string(value : String) -> Value {
  Value::String(value)
}

///|
pub fn list(values : Array[Value]) -> Value {
  Value::List(values.copy())
}

///|
pub fn field(name : String, value : Value) -> Field {
  { name, value, }
}

///|
pub fn Field::name(self : Field) -> String {
  self.name
}

///|
pub fn Field::value(self : Field) -> Value {
  self.value
}

///|
pub fn object(fields : Array[Field]) -> Object {
  let mut result = Object::{ fields: [], }
  for item in fields {
    result = result.put(item.name, item.value)
  }
  result
}

///|
pub fn object_value(fields : Array[Field]) -> Value {
  Value::Object(object(fields))
}

///|
pub fn Value::kind(self : Value) -> ValueKind {
  match self {
    Null => ValueKind::Null
    Boolean(_) => ValueKind::Boolean
    Number(_) => ValueKind::Number
    String(_) => ValueKind::String
    List(_) => ValueKind::List
    Object(_) => ValueKind::Object
  }
}

///|
pub fn Value::is_null(self : Value) -> Bool {
  self is Null
}

///|
pub fn Value::as_boolean(self : Value) -> Bool? {
  match self {
    Boolean(value) => Some(value)
    _ => None
  }
}

///|
pub fn Value::as_number(self : Value) -> Double? {
  match self {
    Number(value) => Some(value)
    _ => None
  }
}

///|
pub fn Value::as_string(self : Value) -> String? {
  match self {
    String(value) => Some(value)
    _ => None
  }
}

///|
pub fn Value::as_list(self : Value) -> Array[Value]? {
  match self {
    List(values) => Some(values.copy())
    _ => None
  }
}

///|
pub fn Value::as_object(self : Value) -> Object? {
  match self {
    Object(value) => Some(value.copy())
    _ => None
  }
}

///|
pub fn Object::copy(self : Object) -> Object {
  Object::{ fields: self.fields.copy(), }
}

///|
pub fn Object::length(self : Object) -> Int {
  self.fields.length()
}

///|
pub fn Object::is_empty(self : Object) -> Bool {
  self.fields.is_empty()
}

///|
pub fn Object::names(self : Object) -> Array[String] {
  let result : Array[String] = []
  for item in self.fields {
    result.push(item.name)
  }
  result
}

///|
pub fn Object::entries(self : Object) -> Array[Field] {
  self.fields.copy()
}

///|
pub fn Object::contains(self : Object, name : String) -> Bool {
  self.index_of(name) >= 0
}

///|
pub fn Object::get(self : Object, name : String) -> Value? {
  let index = self.index_of(name)
  if index < 0 {
    None
  } else {
    Some(self.fields[index].value)
  }
}

///|
/// Return a new object with a field inserted or replaced. Replacement keeps
/// the original position and spelling to make deterministic codecs possible.
pub fn Object::put(self : Object, name : String, value : Value) -> Object {
  let result = self.fields.copy()
  let index = self.index_of(name)
  if index < 0 {
    result.push({ name, value, })
  } else {
    result[index] = { name: result[index].name, value, }
  }
  Object::{ fields: result, }
}

///|
pub fn Object::remove(self : Object, name : String) -> Object {
  let result : Array[Field] = []
  let wanted = name.to_lower()
  for item in self.fields {
    if item.name.to_lower() != wanted {
      result.push(item)
    }
  }
  Object::{ fields: result, }
}

///|
fn Object::index_of(self : Object, name : String) -> Int {
  let wanted = name.to_lower()
  for index, item in self.fields {
    if item.name.to_lower() == wanted {
      return index
    }
  }
  -1
}
