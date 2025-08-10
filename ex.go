package ex

import (
	"fmt"
)

// ExType is the type of exception being returned
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

// String returns a string representation of the ExType for debugging and logging
func (et ExType) String() string {
	switch et {
	case ExTypeIncorrectData:
		return "IncorrectData"
	case ExTypeLoginRequired:
		return "LoginRequired"
	case ExTypePermissionDenied:
		return "PermissionDenied"
	case ExTypeApplicationFailure:
		return "ApplicationFailure"
	default:
		return fmt.Sprintf("Unknown(%d)", int(et))
	}
}

// Err represents the error to be logged
type Err interface {
	ID() int
	Message() string
	InnerError() error
	WithInnerError(err error) Exception
}

// Exception represents an error within the application
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

func (e Exception) Error() string {
	if e.innerError != nil && e.innerError.Error() != "" {
		// Use string concatenation instead of fmt.Sprintf for better performance
		return e.message + ": " + e.innerError.Error()
	}
	return e.message
}

// Unwrap returns the inner error for errors.Is and errors.As compatibility
func (e Exception) Unwrap() error {
	return e.innerError
}

// New creates an exception with the specified code, ID, and message.
// The code should be one of the predefined ExType constants.
// The ID is typically an HTTP status code or application-specific error code.
// The message should be a human-readable description of the error.
func New(code ExType, id int, message string) Exception {
	return Exception{code: code, id: id, message: message, innerError: nil}
}
