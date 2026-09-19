///|
pub(all) enum BulkMethod {
  Post
  Put
  Patch
  Delete
} derive(Debug, Eq)

///|
pub struct BulkOperation {
  http_method : BulkMethod
  path : String
  bulk_id : String?
  version : String?
  data : @value.Value?
} derive(Debug, Eq)

///|
pub struct BulkRequest {
  operations : Array[BulkOperation]
  fail_on_errors : Int?
} derive(Debug, Eq)

///|
pub(all) struct BulkIssue {
  code : String
  operation : Int?
  message : String
} derive(Debug, Eq)

///|
pub struct BulkIssues(Array[BulkIssue]) derive(Debug, Eq)

///|
pub fn bulk_operation(
  http_method : BulkMethod,
  path : String,
  bulk_id? : String,
  version? : String,
  data? : @value.Value,
) -> BulkOperation {
  { http_method, path, bulk_id, version, data, }
}

///|
pub fn bulk_request(
  operations : Array[BulkOperation],
  fail_on_errors? : Int,
) -> BulkRequest {
  { operations: operations.copy(), fail_on_errors, }
}

///|
pub fn BulkOperation::bulk_method(self : BulkOperation) -> BulkMethod {
  self.http_method
}

///|
pub fn BulkOperation::path(self : BulkOperation) -> String {
  self.path
}

///|
pub fn BulkOperation::bulk_id(self : BulkOperation) -> String? {
  self.bulk_id
}

///|
pub fn BulkOperation::version(self : BulkOperation) -> String? {
  self.version
}

///|
pub fn BulkOperation::data(self : BulkOperation) -> @value.Value? {
  self.data
}

///|
pub fn BulkRequest::operations(self : BulkRequest) -> Array[BulkOperation] {
  self.operations.copy()
}

///|
pub fn BulkRequest::fail_on_errors(self : BulkRequest) -> Int? {
  self.fail_on_errors
}

///|
pub fn BulkIssues::items(self : BulkIssues) -> Array[BulkIssue] {
  self.0.copy()
}

///|
pub fn BulkIssues::length(self : BulkIssues) -> Int {
  self.0.length()
}

///|
pub fn BulkIssues::has_code(self : BulkIssues, code : String) -> Bool {
  for item in self.0 {
    if item.code == code {
      return true
    }
  }
  false
}

///|
pub fn validate_bulk_request(
  request : BulkRequest,
  max_operations? : Int = 1000,
) -> BulkIssues {
  let issues : Array[BulkIssue] = []
  if max_operations < 0 || request.operations.length() > max_operations {
    issues.push(
      bulk_issue(
        "BULK_OPERATION_LIMIT",
        None,
        "bulk request exceeds the configured operation limit",
      ),
    )
  }
  match request.fail_on_errors {
    Some(value) if value < 0 =>
      issues.push(
        bulk_issue(
          "BULK_FAIL_ON_ERRORS",
          None,
          "failOnErrors cannot be negative",
        ),
      )
    _ => ()
  }
  let identifiers : Array[String] = []
  for index, operation in request.operations {
    if operation.path.is_empty() {
      issues.push(
        bulk_issue(
          "BULK_PATH_REQUIRED",
          Some(index),
          "bulk operation path cannot be empty",
        ),
      )
    }
    match operation.bulk_id {
      Some(value) if value.is_empty() =>
        issues.push(
          bulk_issue(
            "BULK_ID_EMPTY",
            Some(index),
            "bulkId cannot be an empty string",
          ),
        )
      Some(value) => {
        let canonical = value.to_lower()
        if identifiers.contains(canonical) {
          issues.push(
            bulk_issue(
              "BULK_ID_DUPLICATE",
              Some(index),
              "bulkId is repeated ignoring case",
            ),
          )
        } else {
          identifiers.push(canonical)
        }
      }
      None => ()
    }
    match operation.http_method {
      Delete =>
        if operation.data is Some(_) {
          issues.push(
            bulk_issue(
              "BULK_DELETE_DATA",
              Some(index),
              "DELETE bulk operation cannot contain data",
            ),
          )
        }
      Post | Put | Patch =>
        if operation.data is None {
          issues.push(
            bulk_issue(
              "BULK_DATA_REQUIRED",
              Some(index),
              "write bulk operation requires data",
            ),
          )
        }
    }
  }
  BulkIssues(issues)
}

///|
fn bulk_issue(code : String, operation : Int?, message : String) -> BulkIssue {
  { code, operation, message, }
}
