package ex

import (
	"strconv"
)

// ExType is the type of exception being returned.
//
// The zero value (ExType(0)) is reserved and considered invalid: the
// predefined constants begin at iota + 1. Custom codes created via
// ExType(n) are supported for n > 0, and will be rendered by String()
// as "Unknown(n)".
type ExType int

const (
	// ExTypeIncorrectData indicates that the data is invalid, missing or conflicting
	ExTypeIncorrectData ExType = iota + 1

	// ExTypeLoginRequired indicates that the action requires authentication
	ExTypeLoginRequired

	// ExTypePermissionDenied indicates that the action requires further permission(s)
	ExTypePermissionDenied

	// ExTypeApplicationFailure indicates that the application tried to perform an action that is invalid
	ExTypeApplicationFailure
)

// String returns a string representation of the ExType for debugging and logging.
// The zero value renders as "Invalid(0)". Custom codes render as "Unknown(N)".
func (et ExType) String() string {
	switch et {
	case 0:
		return "Invalid(0)"
	case ExTypeIncorrectData:
		return "IncorrectData"
	case ExTypeLoginRequired:
		return "LoginRequired"
	case ExTypePermissionDenied:
		return "PermissionDenied"
	case ExTypeApplicationFailure:
		return "ApplicationFailure"
	default:
		return "Unknown(" + strconv.Itoa(int(et)) + ")"
	}
}

// Exception represents an error within the application.
//
// Exception is intentionally an immutable value type. All mutation methods
// (e.g. WithInnerError) return a new Exception, leaving the receiver
// unchanged. This makes Exception safe to share across goroutines.
//
// Although Exception is a struct, do not rely on the built-in == operator
// to compare Exceptions: the innerError field holds an arbitrary error
// whose dynamic type may be non-comparable (e.g. a struct containing a
// slice, map, or func), which would panic at runtime. Use the provided
// Is method, or errors.Is, instead.
type Exception struct {
	code       ExType
	id         int
	message    string
	innerError error
}

// Code is a read-only property for the exception type code
func (e Exception) Code() ExType {
	return e.code
}

// ID is a read-only property for the exception id
func (e Exception) ID() int {
	return e.id
}

// Message is a read-only property for the exception message
func (e Exception) Message() string {
	return e.message
}

// InnerError is a read-only property for the inner exception
func (e Exception) InnerError() error {
	return e.innerError
}

// WithInnerError returns a new Exception with the specified inner error.
// This method creates a copy of the current Exception, preserving immutability.
// The inner error can be nil to clear any existing inner error.
func (e Exception) WithInnerError(err error) Exception {
	e.innerError = err
	return e
}

// Error implements the error interface.
//
// Formatting rules:
//   - If both message and the inner error's Error() string are non-empty,
//     the result is "message: innerError".
//   - If the message is empty but an inner error is present, the inner
//     error's Error() string is returned.
//   - Otherwise the message alone is returned.
func (e Exception) Error() string {
	innerMsg := ""
	if e.innerError != nil {
		innerMsg = e.innerError.Error()
	}

	switch {
	case e.message == "" && innerMsg != "":
		return innerMsg
	case e.message == "" && e.innerError != nil:
		// Inner error exists but its message is empty; fall through to
		// returning the (empty) message rather than a leading colon.
		return ""
	case innerMsg != "":
		return e.message + ": " + innerMsg
	default:
		return e.message
	}
}

// Unwrap returns the inner error for errors.Is and errors.As compatibility.
func (e Exception) Unwrap() error {
	return e.innerError
}

// Is reports whether this Exception matches target for use with errors.Is.
//
// Matching semantics are intentional (not the Go default == fallback,
// which would both panic on non-comparable inner errors and incorrectly
// match unrelated Exceptions that happen to share the same code/id/message):
//
//   - If target is an Exception, Is returns true only when both the Code
//     and ID match. This treats (Code, ID) as the exception's identity.
//   - If target is any other error, Is returns false here and lets
//     errors.Is continue walking the wrapped chain via Unwrap.
func (e Exception) Is(target error) bool {
	t, ok := target.(Exception)
	if !ok {
		return false
	}
	return e.code == t.code && e.id == t.id
}

// New creates an exception with the specified code, ID, and message.
//
// The code should be a predefined ExType constant or a custom ExType(n)
// with n > 0. The zero value ExType(0) is reserved; passing it produces
// an Exception whose Code() renders as "Invalid(0)" via String().
//
// The ID is typically an HTTP status code or application-specific error
// code. The message should be a human-readable description of the error.
func New(code ExType, id int, message string) Exception {
	return Exception{code: code, id: id, message: message, innerError: nil}
}

// Compile-time checks that Exception satisfies the standard error interfaces.
var (
	_ error                       = Exception{}
	_ interface{ Unwrap() error } = Exception{}
	_ interface{ Is(error) bool } = Exception{}
)
