package ex_test

import (
	"errors"
	"fmt"
	"testing"

	"github.com/bold-minds/ex"
	"github.com/stretchr/testify/assert"
)

var exceptionTestsCases = []struct {
	errID    int
	errCode  ex.ExType
	errMsg   string
	innerErr error
}{
	{1000, ex.ExTypeApplicationFailure, "Error created", errors.New("inner exception")},
	{0, ex.ExTypeIncorrectData, "", nil},
}

func Test_NewEx(t *testing.T) {

	for _, testCase := range exceptionTestsCases {
		e := ex.New(testCase.errCode, testCase.errID, testCase.errMsg)

		if e.Code() != testCase.errCode {
			t.Errorf("Error code not correct: expected %d; got %d", testCase.errCode, e.Code())
		}

		if e.ID() != testCase.errID {
			t.Errorf("Error id not correct: expected %d; got %d", testCase.errID, e.ID())
		}

		if e.Message() != testCase.errMsg {
			t.Errorf("Error message not correct: expected '%s'; got '%s'", testCase.errMsg, e.Message())
		}

		// Test error message format
		if e.InnerError() != nil && e.InnerError().Error() != "" {
			expectedErrorMessage := fmt.Sprintf("%s: %s", e.Message(), e.InnerError().Error())
			if e.Error() != expectedErrorMessage {
				t.Errorf("Error does not contain message and/or error: expected %s; got %s", expectedErrorMessage, e.Error())
			}
		} else {
			if e.Error() != e.Message() {
				t.Errorf("Error should equal message when no inner error: expected %s; got %s", e.Message(), e.Error())
			}
		}
	}
}

func Test_NewExWithInnerEx(t *testing.T) {

	for _, testCase := range exceptionTestsCases {

		e := ex.New(testCase.errCode, testCase.errID, testCase.errMsg)
		e = e.WithInnerError(testCase.innerErr)

		if e.Code() != testCase.errCode {
			t.Errorf("Error code not correct: expected %d; got %d", testCase.errCode, e.Code())
		}

		if e.ID() != testCase.errID {
			t.Errorf("Error id not correct: expected %d; got %d", testCase.errID, e.ID())
		}

		if e.Message() != testCase.errMsg {
			t.Errorf("Error message not correct: expected '%s'; got '%s'", testCase.errMsg, e.Message())
		}

		if e.InnerError() != testCase.innerErr {
			t.Errorf("Inner error not correct: expected '%+v'; got '%+v'", testCase.errMsg, e.Message())
		}

		// Test error message format
		if e.InnerError() != nil && e.InnerError().Error() != "" {
			expectedErrorMessage := fmt.Sprintf("%s: %s", e.Message(), e.InnerError().Error())
			if e.Error() != expectedErrorMessage {
				t.Errorf("Error does not contain message and/or error: expected %s; got %s", expectedErrorMessage, e.Error())
			}
		} else {
			if e.Error() != e.Message() {
				t.Errorf("Error should equal message when no inner error: expected %s; got %s", e.Message(), e.Error())
			}
		}
	}
}

func Test_ErrorsIs(t *testing.T) {
	// Test errors.Is with inner error
	innerErr := errors.New("database connection failed")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)

	assert.Equal(t, "Service unavailable: database connection failed", exc.Error())

	// Should find the inner error
	if !errors.Is(exc, innerErr) {
		t.Errorf("errors.Is should find inner error")
	}

	// Should not find a different error
	differentErr := errors.New("different error")
	if errors.Is(exc, differentErr) {
		t.Errorf("errors.Is should not find different error")
	}

	// Test with nested exceptions
	nestedInner := errors.New("root cause")
	middleExc := ex.New(ex.ExTypeIncorrectData, 400, "Invalid input").WithInnerError(nestedInner)
	outerExc := ex.New(ex.ExTypeApplicationFailure, 500, "Processing failed").WithInnerError(middleExc)

	// Should find the root cause through the chain
	if !errors.Is(outerExc, nestedInner) {
		t.Errorf("errors.Is should find nested inner error")
	}

	// Should find the middle exception
	if !errors.Is(outerExc, middleExc) {
		t.Errorf("errors.Is should find middle exception")
	}
}

func Test_ErrorsAs(t *testing.T) {
	// Test errors.As with Exception type
	innerErr := errors.New("database error")
	exc := ex.New(ex.ExTypeLoginRequired, 401, "Authentication required").WithInnerError(innerErr)

	// Should be able to extract Exception type
	var targetExc ex.Exception
	if !errors.As(exc, &targetExc) {
		t.Errorf("errors.As should extract Exception type")
	}

	if targetExc.Code() != ex.ExTypeLoginRequired {
		t.Errorf("Extracted exception should have correct code: expected %d, got %d", ex.ExTypeLoginRequired, targetExc.Code())
	}

	if targetExc.ID() != 401 {
		t.Errorf("Extracted exception should have correct ID: expected %d, got %d", 401, targetExc.ID())
	}

	// Test with nested exceptions
	nestedExc := ex.New(ex.ExTypePermissionDenied, 403, "Access denied")
	outerExc := ex.New(ex.ExTypeApplicationFailure, 500, "Server error").WithInnerError(nestedExc)

	// Should be able to extract the nested exception
	var nestedTarget ex.Exception
	if !errors.As(outerExc, &nestedTarget) {
		t.Errorf("errors.As should extract nested Exception type")
	}

	// The first Exception found should be the outer one
	if nestedTarget.Code() != ex.ExTypeApplicationFailure {
		t.Errorf("First extracted exception should be outer: expected %d, got %d", ex.ExTypeApplicationFailure, nestedTarget.Code())
	}
}

func Test_ErrorsIsWithExceptionTypes(t *testing.T) {
	// Test errors.Is with Exception instances
	originalExc := ex.New(ex.ExTypeIncorrectData, 400, "Bad request")
	wrappedExc := ex.New(ex.ExTypeApplicationFailure, 500, "Server error").WithInnerError(originalExc)

	// Should find the original exception
	if !errors.Is(wrappedExc, originalExc) {
		t.Errorf("errors.Is should find wrapped Exception")
	}

	// Should find a different exception with same values (Go's default behavior for comparable types)
	differentExc := ex.New(ex.ExTypeIncorrectData, 400, "Bad request")
	if !errors.Is(wrappedExc, differentExc) {
		t.Errorf("errors.Is should find Exception with same values")
	}

	// Should not find exception with different values
	differentValuesExc := ex.New(ex.ExTypeIncorrectData, 404, "Not found")
	if errors.Is(wrappedExc, differentValuesExc) {
		t.Errorf("errors.Is should not find Exception with different values")
	}
}

func Test_UnwrapMethod(t *testing.T) {
	// Test that Unwrap method works correctly
	innerErr := errors.New("inner error")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Outer error").WithInnerError(innerErr)

	// Test direct unwrap
	unwrapped := exc.Unwrap()
	if unwrapped != innerErr {
		t.Errorf("Unwrap should return the inner error: expected %v, got %v", innerErr, unwrapped)
	}

	// Test unwrap with nil inner error
	excWithoutInner := ex.New(ex.ExTypeIncorrectData, 400, "No inner error")
	unwrappedNil := excWithoutInner.Unwrap()
	if unwrappedNil != nil {
		t.Errorf("Unwrap should return nil when no inner error: got %v", unwrappedNil)
	}
}

func TestExType_String(t *testing.T) {
	tests := []struct {
		name     string
		exType   ex.ExType
		expected string
	}{
		{
			name:     "IncorrectData",
			exType:   ex.ExTypeIncorrectData,
			expected: "IncorrectData",
		},
		{
			name:     "LoginRequired",
			exType:   ex.ExTypeLoginRequired,
			expected: "LoginRequired",
		},
		{
			name:     "PermissionDenied",
			exType:   ex.ExTypePermissionDenied,
			expected: "PermissionDenied",
		},
		{
			name:     "ApplicationFailure",
			exType:   ex.ExTypeApplicationFailure,
			expected: "ApplicationFailure",
		},
		{
			name:     "Unknown type",
			exType:   ex.ExType(999),
			expected: "Unknown(999)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.expected, tt.exType.String())
		})
	}
}

func TestException_EdgeCases(t *testing.T) {
	t.Run("Empty message", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, 400, "")
		assert.Equal(t, "", exc.Message())
		assert.Equal(t, "", exc.Error())
	})

	t.Run("Zero ID", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, 0, "Test message")
		assert.Equal(t, 0, exc.ID())
	})

	t.Run("Negative ID", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, -1, "Test message")
		assert.Equal(t, -1, exc.ID())
	})

	t.Run("WithInnerError with nil", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, 400, "Test message")
		excWithNil := exc.WithInnerError(nil)
		assert.Nil(t, excWithNil.InnerError())
		assert.Equal(t, "Test message", excWithNil.Error())
	})

	t.Run("Multiple WithInnerError calls", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, 400, "Test message")
		firstInner := ex.New(ex.ExTypeLoginRequired, 401, "First inner")
		secondInner := ex.New(ex.ExTypePermissionDenied, 403, "Second inner")

		result := exc.WithInnerError(firstInner).WithInnerError(secondInner)
		assert.Equal(t, secondInner, result.InnerError())
		assert.Equal(t, "Test message: Second inner", result.Error())
	})
}

func TestException_ImmutabilityCheck(t *testing.T) {
	t.Run("WithInnerError creates new instance", func(t *testing.T) {
		original := ex.New(ex.ExTypeIncorrectData, 400, "Original")
		inner := ex.New(ex.ExTypeLoginRequired, 401, "Inner")

		modified := original.WithInnerError(inner)

		// Original should remain unchanged
		assert.Nil(t, original.InnerError())
		assert.Equal(t, "Original", original.Error())

		// Modified should have the inner error
		assert.Equal(t, inner, modified.InnerError())
		assert.Equal(t, "Original: Inner", modified.Error())
	})
}
