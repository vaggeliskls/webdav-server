# WebDAV Methods and Access Control

The allowed HTTP methods per access mode are controlled via `RO_METHODS` and `RW_METHODS` environment variables.

| Method    | Purpose                                                    |
|-----------|------------------------------------------------------------|
| GET       | Download a file or resource                                |
| HEAD      | Retrieve headers only (no body)                            |
| OPTIONS   | Discover server-supported methods                          |
| PROPFIND  | List directory contents, get resource metadata             |
| PUT       | Upload a file                                              |
| DELETE    | Delete a file or resource                                  |
| MKCOL     | Create a new collection (folder)                           |
| COPY      | Copy a resource                                            |
| MOVE      | Move or rename a resource                                  |
| LOCK      | Lock a resource                                            |
| UNLOCK    | Unlock a resource                                          |
| PROPPATCH | Set or remove resource properties                          |
| REPORT    | Query for information (advanced WebDAV clients)            |
| PATCH     | Partial update of a resource                               |
| POST      | Submit data (rarely used in WebDAV, sometimes for locking) |
