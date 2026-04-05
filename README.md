# Go Exception Library

[![Go Reference](https://pkg.go.dev/badge/github.com/bold-minds/ex.svg)](https://pkg.go.dev/github.com/bold-minds/ex)
[![Build](https://img.shields.io/github/actions/workflow/status/bold-minds/ex/test.yaml?branch=main&label=tests)](https://github.com/bold-minds/ex/actions/workflows/test.yaml)
[![Go Version](https://img.shields.io/github/go-mod/go-version/bold-minds/ex)](go.mod)
[![Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bold-admin/c7074f035bc8222b560455348e2d1704/raw/coverage.json)](https://github.com/bold-minds/ex/actions/workflows/test.yaml)

A high-performance, idiomatic Go library for structured exception handling with full compatibility with Go's standard `errors` package.

## ✨ Features

- 🔗 **Full `errors.Is` and `errors.As` compatibility**
- 🎯 **Structured error codes** with predefined categories and room for custom codes
- 🔄 **Error chaining** with inner error support
- 📝 **Idiomatic Go error formatting**
- 🧪 **Comprehensive test coverage**
- 🛡️ **Immutable error structures** (safe to share across goroutines)
- 🔍 **Enhanced debugging** with string representations
- ⚡ **Lean hot path**: simple string concatenation, no `fmt.Sprintf`, no reflection

## 🚀 Quick Start

### Installation

```bash
go get github.com/bold-minds/ex
```

### Basic Usage

```go
package main

import (
    "fmt"
    "errors"
    "github.com/bold-minds/ex"
)

func main() {
    // Create a basic exception
    err := ex.New(ex.ExTypeIncorrectData, 400, "Invalid user input")
    fmt.Println(err) // Output: Invalid user input
    
    // Create with inner error
    dbErr := errors.New("connection timeout")
    appErr := ex.New(ex.ExTypeApplicationFailure, 500, "Database operation failed").
        WithInnerError(dbErr)
    fmt.Println(appErr) // Output: Database operation failed: connection timeout
    
    // Use with Go's standard error handling
    if errors.Is(appErr, dbErr) {
        fmt.Println("Found database error in chain")
    }
    
    var exc ex.Exception
    if errors.As(appErr, &exc) {
        fmt.Printf("Exception: %s (Code: %s, ID: %d)\n", 
            exc.Message(), exc.Code(), exc.ID())
    }
}
```

## 📖 API Reference

### Exception Types

Predefined error categories for consistent error handling:

```go
const (
    ExTypeIncorrectData      // Invalid, missing, or conflicting data
    ExTypeLoginRequired      // Authentication required
    ExTypePermissionDenied   // Insufficient permissions  
    ExTypeApplicationFailure // Application logic errors
)
```

#### Custom Error Codes

You can also use custom error codes by casting any int to ExType:

```go
// Use your existing error code groupings
customCode := ex.ExType(42)
exc := ex.New(customCode, 500, "Custom domain error")

// Or directly inline
exc := ex.New(ex.ExType(1), 400, "Your existing code 1")
exc := ex.New(ex.ExType(999), 500, "Your existing code 999")

// Custom codes show as "Unknown(N)" in string representation
fmt.Println(ex.ExType(42).String()) // Output: "Unknown(42)"
```

This preserves your existing error code organization while gaining type safety and structured error handling.

### Core Functions

#### `New(code ExType, id int, message string) Exception`

Creates a new exception with the specified error code, ID, and message.

```go
exc := ex.New(ex.ExTypeIncorrectData, 400, "Validation failed")
```

**Parameters:**
- `code`: One of the predefined `ExType` constants
- `id`: Numeric identifier (typically HTTP status code)
- `message`: Human-readable error description

### Exception Methods

#### `Code() ExType`
Returns the exception type code.

#### `ID() int`
Returns the numeric identifier.

#### `Message() string`
Returns the error message.

#### `InnerError() error`
Returns the wrapped inner error, or `nil` if none.

#### `WithInnerError(err error) Exception`
Returns a new Exception with the specified inner error. This method preserves immutability by creating a copy.

```go
original := ex.New(ex.ExTypeApplicationFailure, 500, "Server error")
withInner := original.WithInnerError(dbError)
// original remains unchanged
```

#### `Error() string`
Implements the `error` interface. Formatting rules:

- If both the message and the inner error's `Error()` string are non-empty, the result is `"message: innerError"`.
- If the message is empty but a non-nil inner error is present, the inner error's `Error()` string is returned on its own (no leading colon).
- Otherwise the message alone is returned.

The inner error remains retrievable via `Unwrap` and `InnerError` even when it contributes nothing to the `Error()` string (e.g. its `Error()` returned `""`).

#### `Unwrap() error`
Implements error unwrapping for `errors.Is` and `errors.As` compatibility.

### ExType Methods

#### `String() string`
Returns a string representation of the error type for debugging.

```go
fmt.Println(ex.ExTypeIncorrectData.String()) // Output: "IncorrectData"
```

## 🔄 Error Chaining

The library supports full error chaining compatible with Go's standard error handling:

```go
// Create error chain
rootCause := errors.New("network timeout")
middleErr := ex.New(ex.ExTypeApplicationFailure, 503, "Service unavailable").
    WithInnerError(rootCause)
topErr := ex.New(ex.ExTypeIncorrectData, 400, "Request failed").
    WithInnerError(middleErr)

// Traverse the chain
if errors.Is(topErr, rootCause) {
    fmt.Println("Network issue detected") // This will execute
}

// Extract specific types
var appErr ex.Exception
if errors.As(topErr, &appErr) {
    fmt.Printf("Application error: %s\n", appErr.Message())
}
```

## 🎯 Best Practices

### Error Code Selection

Choose appropriate error codes for different scenarios:

```go
// Data validation errors
ex.New(ex.ExTypeIncorrectData, 400, "Invalid email format")

// Authentication errors
ex.New(ex.ExTypeLoginRequired, 401, "Authentication required")

// Authorization errors
ex.New(ex.ExTypePermissionDenied, 403, "Insufficient permissions")

// Application logic errors
ex.New(ex.ExTypeApplicationFailure, 500, "Database connection failed")
```

### Error Wrapping

Wrap errors to preserve context while maintaining the error chain:

```go
func processUser(id string) error {
    user, err := database.GetUser(id)
    if err != nil {
        return ex.New(ex.ExTypeApplicationFailure, 500, "Failed to retrieve user").
            WithInnerError(err)
    }
    // ... process user
    return nil
}
```

### Error Handling

Use Go's standard error handling patterns:

```go
func handleError(err error) {
    // Check for specific errors in the chain
    if errors.Is(err, sql.ErrNoRows) {
        // Handle not found
        return
    }
    
    // Extract exception information
    var exc ex.Exception
    if errors.As(err, &exc) {
        log.Printf("Exception [%s:%d]: %s", exc.Code(), exc.ID(), exc.Message())
        
        // Handle by type
        switch exc.Code() {
        case ex.ExTypeLoginRequired:
            // Redirect to login
        case ex.ExTypePermissionDenied:
            // Show access denied page
        case ex.ExTypeIncorrectData:
            // Show validation errors
        default:
            // Generic error handling
        }
    }
}
```

## ⚡ Performance

The library is designed to be lean on the hot path: no `fmt.Sprintf`, no
reflection, and a struct small enough to stay on the stack when the compiler
can prove it does not escape.

### Benchmark Results

Representative numbers from `go test -bench=. -benchmem ./...`:

```
BenchmarkNew-24                    ~0.14 ns/op     0 B/op    0 allocs/op
BenchmarkNewWithInnerError-24      ~0.14 ns/op     0 B/op    0 allocs/op
BenchmarkErrorSimple-24            ~1.18 ns/op     0 B/op    0 allocs/op
BenchmarkErrorWithInner-24        ~29    ns/op    48 B/op    1 allocs/op
BenchmarkUnwrap-24                 ~0.11 ns/op     0 B/op    0 allocs/op
BenchmarkWithInnerError-24         ~0.14 ns/op     0 B/op    0 allocs/op
BenchmarkAccessors-24              ~0.14 ns/op     0 B/op    0 allocs/op
```

### ⚠️ A note on "zero allocation" claims

The zero-alloc numbers above come from benchmarks that assign the result to
`_`, keeping the `Exception` value on the stack. **In realistic use, returning
an `Exception` through an `error` interface forces a heap allocation** because
the concrete struct must be boxed into the interface header. For example:

```go
func DoThing() error {
    return ex.New(ex.ExTypeIncorrectData, 400, "bad") // allocates at the return boundary
}
```

You can see this yourself with `go test -gcflags='-m' -bench=BenchmarkNew`: the
moment an `Exception` is assigned to a variable of type `error`, the escape
analysis output will show the allocation. This is a property of Go interfaces,
not of this library; the same cost applies to `errors.New`, `fmt.Errorf`, and
every other error type.

What this library **does** guarantee:

- ✅ `Unwrap` and accessors (`Code`, `ID`, `Message`, `InnerError`) do not allocate.
- ✅ `Error()` without an inner error does not allocate.
- ⚡ `Error()` with an inner error performs a single string concatenation (one allocation), not the two allocations of `fmt.Errorf("%s: %w", …)`.
- ✅ The struct itself is immutable and safe to share across goroutines.

If a call site never converts the `Exception` to `error`, the creation stays
on the stack and costs nothing extra.

## 🧪 Testing

The library includes comprehensive tests and supports easy testing of error conditions:

```go
func TestErrorHandling(t *testing.T) {
    err := processData("invalid")
    
    // Test error type
    var exc ex.Exception
    require.True(t, errors.As(err, &exc))
    assert.Equal(t, ex.ExTypeIncorrectData, exc.Code())
    assert.Equal(t, 400, exc.ID())
    
    // Test error chain
    assert.True(t, errors.Is(err, someSpecificError))
}
```

### Running Tests

```bash
# Run all tests
go test ./...

# Run with coverage
go test -cover ./...

# Run with race detection
go test -race ./...
```

## 🔧 Development

### Prerequisites

- Go 1.24 or later (matches `go.mod`)
- Git

### Building

```bash
# Clone the repository
git clone https://github.com/bold-minds/ex.git
cd ex

# Run tests
go test ./...

# Build
go build ./...
```

### Validation

The project includes a comprehensive validation script:

```bash
# Run full validation pipeline
./scripts/validate.sh

# Run in CI mode
./scripts/validate.sh ci
```

The validation includes:
- Code formatting (`go fmt`)
- Linting (`golangci-lint`)
- Static analysis (`go vet`)
- Unit tests with race detection
- Coverage analysis
- Documentation checks

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for detailed information on:

- Development setup and workflow
- Code style and testing requirements
- Pull request process
- What types of contributions we're looking for

For quick contributions: fork the repo, make your changes, add tests, and submit a PR!

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [Go errors package](https://pkg.go.dev/errors) - Go's standard error handling
- [pkg/errors](https://github.com/pkg/errors) - Error handling primitives

---

**Made with ❤️ for the Go community**
