///|
pub struct CursorResponse {
  total_results : Int
  items_per_page : Int
  resources : Array[@value.Object]
  next_cursor : String?
  previous_cursor : String?
} derive(Debug, Eq)

///|
/// Execute RFC 9865-style cursor pagination. The built-in token is an opaque,
/// deterministic query-bound continuation token. Applications that cross a
/// trust boundary should sign or encrypt it in their transport adapter.
pub fn execute_cursor_query(
  resources : Array[@value.Object],
  request : SearchRequest,
  cursor : String?,
) -> Result[CursorResponse, QueryError] {
  let signature = query_signature(request)
  let offset = match cursor {
    None => 0
    Some(token) =>
      match decode_cursor(token, signature) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
  }
  let index_request = SearchRequest::{
    filter_source: request.filter_source,
    filter: request.filter,
    sort_source: request.sort_source,
    sort_by: request.sort_by,
    descending: request.descending,
    start_index: offset + 1,
    count: request.count,
    attributes: request.attributes,
    excluded_attributes: request.excluded_attributes,
  }
  let page = match execute_query(resources, index_request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let consumed = offset + page.items_per_page()
  let next_cursor = if consumed < page.total_results() {
    Some(encode_cursor(consumed, signature))
  } else {
    None
  }
  let previous_offset = if offset <= request.count {
    0
  } else {
    offset - request.count
  }
  let previous_cursor = if offset > 0 {
    Some(encode_cursor(previous_offset, signature))
  } else {
    None
  }
  Ok({
    total_results: page.total_results(),
    items_per_page: page.items_per_page(),
    resources: page.resources(),
    next_cursor,
    previous_cursor,
  })
}

///|
pub fn CursorResponse::total_results(self : CursorResponse) -> Int {
  self.total_results
}

///|
pub fn CursorResponse::items_per_page(self : CursorResponse) -> Int {
  self.items_per_page
}

///|
pub fn CursorResponse::resources(self : CursorResponse) -> Array[@value.Object] {
  self.resources.copy()
}

///|
pub fn CursorResponse::next_cursor(self : CursorResponse) -> String? {
  self.next_cursor
}

///|
pub fn CursorResponse::previous_cursor(self : CursorResponse) -> String? {
  self.previous_cursor
}

///|
fn encode_cursor(offset : Int, signature : Int64) -> String {
  "mcs1:" + offset.to_string() + ":" + signature.to_string()
}

///|
fn decode_cursor(token : String, expected : Int64) -> Result[Int, QueryError] {
  let fields = token.split(":").map(part => part.to_owned()).collect()
  if fields.length() != 3 || fields[0] != "mcs1" {
    return Err(InvalidCursor("cursor has an unsupported format or version"))
  }
  let offset = @string.parse_int(fields[1]) catch {
    _ => return Err(InvalidCursor("cursor offset is not an integer"))
  }
  if offset < 0 {
    return Err(InvalidCursor("cursor offset cannot be negative"))
  }
  let actual = @string.parse_int64(fields[2]) catch {
    _ => return Err(InvalidCursor("cursor query signature is not an integer"))
  }
  if actual != expected {
    return Err(CursorQueryMismatch)
  }
  Ok(offset)
}

///|
fn query_signature(request : SearchRequest) -> Int64 {
  let canonical = request.filter_source.trim().to_owned().to_lower() +
    "\u{001f}" +
    request.sort_source.trim().to_owned().to_lower() +
    "\u{001f}" +
    request.descending.to_string() +
    "\u{001f}" +
    join_signature_parts(request.attributes) +
    "\u{001f}" +
    join_signature_parts(request.excluded_attributes)
  let mut result = 17L
  for character in canonical {
    result = (result * 131L + character.to_int().to_int64()) % 1000000007L
  }
  result
}

///|
fn join_signature_parts(values : Array[String]) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string(value.trim().to_owned().to_lower())
  }
  output.to_string()
}
