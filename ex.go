package ex

import (
	"errors"
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

// WithInnerError sets the value of the inner error
func (e Exception) WithInnerError(err error) Exception {
	e.innerError = err
	return e
}

func (e Exception) Error() string {
	return fmt.Sprintf("%s %+v", e.message, e.innerError)
}

// New creates an exception with a message
func New(code ExType, id int, message string) Exception {
	return Exception{code: code, id: id, message: message, innerError: errors.New("")}
}
