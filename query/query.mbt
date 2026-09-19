///|
pub(all) enum QueryError {
  InvalidPagination(String, Int)
  InvalidFilter(@filter.FilterError)
  InvalidSortPath(@path.PathError)
  InvalidProjection(ProjectionError)
  InvalidCursor(String)
  CursorQueryMismatch
} derive(Debug, Eq)

///|
pub struct SearchRequest {
  filter_source : String
  filter : @filter.Filter?
  sort_source : String
  sort_by : @path.AttributePath?
  descending : Bool
  start_index : Int
  count : Int
  attributes : Array[String]
  excluded_attributes : Array[String]
} derive(Debug, Eq)

///|
pub struct ListResponse {
  total_results : Int
  start_index : Int
  items_per_page : Int
  resources : Array[@value.Object]
} derive(Debug, Eq)

///|
priv struct IndexedResource {
  ordinal : Int
  resource : @value.Object
}

///|
pub fn search_request(
  filter? : String = "",
  sort_by? : String = "",
  descending? : Bool = false,
  start_index? : Int = 1,
  count? : Int = 100,
  attributes? : Array[String] = [],
  excluded_attributes? : Array[String] = [],
) -> Result[SearchRequest, QueryError] {
  if start_index < 1 {
    return Err(InvalidPagination("startIndex", start_index))
  }
  if count < 0 {
    return Err(InvalidPagination("count", count))
  }
  if !attributes.is_empty() && !excluded_attributes.is_empty() {
    return Err(InvalidProjection(ConflictingProjection))
  }
  let compiled_filter = if filter.is_empty() {
    None
  } else {
    match @filter.compile_filter(filter) {
      Ok(value) => Some(value)
      Err(error) => return Err(InvalidFilter(error))
    }
  }
  let parsed_sort = if sort_by.is_empty() {
    None
  } else {
    match @path.parse_attribute_path(sort_by) {
      Ok(value) => Some(value)
      Err(error) => return Err(InvalidSortPath(error))
    }
  }
  Ok({
    filter_source: filter,
    filter: compiled_filter,
    sort_source: sort_by,
    sort_by: parsed_sort,
    descending,
    start_index,
    count,
    attributes: attributes.copy(),
    excluded_attributes: excluded_attributes.copy(),
  })
}

///|
pub fn execute_query(
  resources : Array[@value.Object],
  request : SearchRequest,
) -> Result[ListResponse, QueryError] {
  let selected : Array[IndexedResource] = []
  for ordinal, resource in resources {
    let accepted = match request.filter {
      Some(filter) => filter.matches(resource)
      None => true
    }
    if accepted {
      selected.push({ ordinal, resource, })
    }
  }
  match request.sort_by {
    Some(path) =>
      selected.sort_by((left, right) => {
        let order = compare_resource_path(left.resource, right.resource, path)
        let directed = if request.descending { -order } else { order }
        if directed == 0 {
          left.ordinal.compare(right.ordinal)
        } else {
          directed
        }
      })
    None => ()
  }
  let total_results = selected.length()
  let offset = request.start_index - 1
  let available = if offset >= total_results {
    0
  } else {
    total_results - offset
  }
  let items_per_page = if request.count < available {
    request.count
  } else {
    available
  }
  let projected : Array[@value.Object] = []
  for position = 0; position < items_per_page; position = position + 1 {
    let resource = selected[offset + position].resource
    match
      project_attributes(
        resource,
        request.attributes,
        request.excluded_attributes,
      ) {
      Ok(value) => projected.push(value)
      Err(error) => return Err(InvalidProjection(error))
    }
  }
  Ok({
    total_results,
    start_index: request.start_index,
    items_per_page,
    resources: projected,
  })
}

///|
pub fn ListResponse::total_results(self : ListResponse) -> Int {
  self.total_results
}

///|
pub fn ListResponse::start_index(self : ListResponse) -> Int {
  self.start_index
}

///|
pub fn ListResponse::items_per_page(self : ListResponse) -> Int {
  self.items_per_page
}

///|
pub fn ListResponse::resources(self : ListResponse) -> Array[@value.Object] {
  self.resources.copy()
}

///|
fn compare_resource_path(
  left : @value.Object,
  right : @value.Object,
  path : @path.AttributePath,
) -> Int {
  match (value_at_path(left, path), value_at_path(right, path)) {
    (None, None) => 0
    (None, Some(_)) => 1
    (Some(_), None) => -1
    (Some(a), Some(b)) => compare_sort_value(a, b)
  }
}

///|
fn value_at_path(
  resource : @value.Object,
  path : @path.AttributePath,
) -> @value.Value? {
  let object = match path.schema_uri {
    None => Some(resource)
    Some(uri) =>
      match resource.get(uri) {
        Some(value) => value.as_object()
        None => None
      }
  }
  guard object is Some(container) else { return None }
  guard container.get(path.attribute) is Some(value) else { return None }
  match path.sub_attribute {
    None => first_value(value)
    Some(name) => {
      guard first_value(value) is Some(first) else { return None }
      guard first.as_object() is Some(complex) else { return None }
      match complex.get(name) {
        Some(child) => first_value(child)
        None => None
      }
    }
  }
}

///|
fn first_value(value : @value.Value) -> @value.Value? {
  if value.is_null() {
    return None
  }
  match value.as_list() {
    Some(items) => if items.is_empty() { None } else { Some(items[0]) }
    None => Some(value)
  }
}

///|
fn compare_sort_value(left : @value.Value, right : @value.Value) -> Int {
  match (left.as_string(), right.as_string()) {
    (Some(a), Some(b)) => return a.to_lower().compare(b.to_lower())
    _ => ()
  }
  match (left.as_number(), right.as_number()) {
    (Some(a), Some(b)) => return a.compare(b)
    _ => ()
  }
  match (left.as_boolean(), right.as_boolean()) {
    (Some(a), Some(b)) => return if a == b { 0 } else if a { 1 } else { -1 }
    _ => ()
  }
  value_kind_rank(left.kind()).compare(value_kind_rank(right.kind()))
}

///|
fn value_kind_rank(kind : @value.ValueKind) -> Int {
  match kind {
    @value.Null => 0
    @value.Boolean => 1
    @value.Number => 2
    @value.String => 3
    @value.List => 4
    @value.Object => 5
  }
}
