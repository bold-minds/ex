package ex_test

import (
	"errors"
	"fmt"
	"sync"
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
			t.Errorf("Inner error not correct: expected '%+v'; got '%+v'", testCase.innerErr, e.InnerError())
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
	// Exception identity for errors.Is is (Code, ID). This is intentional —
	// the default == fallback would both panic on non-comparable inner
	// errors and incorrectly match unrelated errors that happen to share
	// message text.

	originalExc := ex.New(ex.ExTypeIncorrectData, 400, "Bad request")
	wrappedExc := ex.New(ex.ExTypeApplicationFailure, 500, "Server error").WithInnerError(originalExc)

	// Same (Code, ID) as the wrapped exception: should match regardless of
	// message text differences.
	if !errors.Is(wrappedExc, originalExc) {
		t.Errorf("errors.Is should find wrapped Exception by (Code, ID)")
	}

	sameIdentityDifferentMessage := ex.New(ex.ExTypeIncorrectData, 400, "Some other wording")
	if !errors.Is(wrappedExc, sameIdentityDifferentMessage) {
		t.Errorf("errors.Is should match on (Code, ID) regardless of message")
	}

	// Different ID → should not match, even with same Code.
	differentID := ex.New(ex.ExTypeIncorrectData, 404, "Not found")
	if errors.Is(wrappedExc, differentID) {
		t.Errorf("errors.Is should not match when ID differs")
	}

	// Different Code → should not match, even with same ID.
	differentCode := ex.New(ex.ExTypeLoginRequired, 400, "Bad request")
	if errors.Is(wrappedExc, differentCode) {
		t.Errorf("errors.Is should not match when Code differs")
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

func TestExTypeCasting(t *testing.T) {
	// Test that users can cast any int to ExType
	customCode42 := ex.ExType(42)
	customCode999 := ex.ExType(999)
	customCode1 := ex.ExType(1)

	// Create exceptions with custom codes
	exc1 := ex.New(customCode42, 500, "Custom error code 42")
	exc2 := ex.New(customCode999, 400, "Custom error code 999")
	exc3 := ex.New(customCode1, 200, "Custom error code 1")

	// Verify the codes are preserved
	if exc1.Code() != customCode42 {
		t.Errorf("Expected code %d, got %d", customCode42, exc1.Code())
	}

	if exc2.Code() != customCode999 {
		t.Errorf("Expected code %d, got %d", customCode999, exc2.Code())
	}

	if exc3.Code() != customCode1 {
		t.Errorf("Expected code %d, got %d", customCode1, exc3.Code())
	}

	// String() renders custom codes as "Unknown(N)"; the predefined
	// constant at iota+1 keeps its named rendering.
	assert.Equal(t, "Unknown(42)", customCode42.String())
	assert.Equal(t, "Unknown(999)", customCode999.String())
	assert.Equal(t, "IncorrectData", customCode1.String())

	// Error() strings for custom-coded exceptions still surface the message.
	assert.Equal(t, "Custom error code 42", exc1.Error())
	assert.Equal(t, "Custom error code 999", exc2.Error())
	assert.Equal(t, "Custom error code 1", exc3.Error())
}

// emptyError is a test helper whose Error() returns "".
type emptyError struct{}

func (emptyError) Error() string { return "" }

func TestException_ErrorFormatting_EdgeCases(t *testing.T) {
	t.Run("empty message with non-nil inner error uses inner", func(t *testing.T) {
		inner := errors.New("root cause")
		exc := ex.New(ex.ExTypeApplicationFailure, 500, "").WithInnerError(inner)
		// Was: ": root cause" (leading colon bug). Now: "root cause".
		assert.Equal(t, "root cause", exc.Error())
	})

	t.Run("empty message with inner whose Error is empty returns empty", func(t *testing.T) {
		exc := ex.New(ex.ExTypeApplicationFailure, 500, "").WithInnerError(emptyError{})
		assert.Equal(t, "", exc.Error())
	})

	t.Run("non-empty message with inner whose Error is empty returns message only", func(t *testing.T) {
		// Previously the non-nil inner error was silently dropped; the
		// observable string is still message-only, but the inner error
		// remains retrievable via Unwrap for programmatic inspection.
		exc := ex.New(ex.ExTypeApplicationFailure, 500, "outer").WithInnerError(emptyError{})
		assert.Equal(t, "outer", exc.Error())
		assert.NotNil(t, exc.Unwrap())
	})

	t.Run("WithInnerError transition from non-nil back to nil", func(t *testing.T) {
		exc := ex.New(ex.ExTypeIncorrectData, 400, "msg")
		withInner := exc.WithInnerError(errors.New("boom"))
		cleared := withInner.WithInnerError(nil)
		assert.Nil(t, cleared.InnerError())
		assert.Equal(t, "msg", cleared.Error())
		// Original chain must remain intact (immutability).
		assert.NotNil(t, withInner.InnerError())
	})
}

func TestException_LongChainTraversal(t *testing.T) {
	// Build a 10-deep chain and assert full traversal via errors.Is / Unwrap.
	root := errors.New("root cause")
	var current error = root
	for i := 0; i < 10; i++ {
		current = ex.New(ex.ExTypeApplicationFailure, 500+i, "level").WithInnerError(current)
	}

	if !errors.Is(current, root) {
		t.Fatalf("errors.Is should find root cause across deep chain")
	}

	// Walk the chain manually and count links.
	depth := 0
	for e := current; e != nil; e = errors.Unwrap(e) {
		depth++
	}
	// 10 Exceptions + 1 root = 11 links.
	assert.Equal(t, 11, depth)
}

func TestException_ConcurrentUse(t *testing.T) {
	t.Parallel()
	// Exception is an immutable value type; concurrent reads and
	// concurrent WithInnerError calls must not race or corrupt state.
	// This test documents that contract and is gated by -race in CI.
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "shared").
		WithInnerError(errors.New("inner"))

	var wg sync.WaitGroup
	const workers = 32
	wg.Add(workers)
	for i := 0; i < workers; i++ {
		go func() {
			defer wg.Done()
			_ = exc.Error()
			_ = exc.Code()
			_ = exc.ID()
			_ = exc.Message()
			_ = exc.Unwrap()
			// Derived exceptions must not mutate the shared one.
			other := exc.WithInnerError(errors.New("local"))
			_ = other.Error()
		}()
	}
	wg.Wait()

	// Original exception still reads back exactly.
	assert.Equal(t, "shared: inner", exc.Error())
}

func TestErrorsAs_WrongTargetType(t *testing.T) {
	// errors.As requires the target to be a non-nil pointer to a type
	// that implements error (or is an interface). Passing a pointer to
	// an error-implementing type that does not appear anywhere in the
	// chain must return false rather than accidentally matching.
	exc := ex.New(ex.ExTypeIncorrectData, 400, "bad").
		WithInnerError(errors.New("inner"))

	var stdTarget *customNonChainError
	assert.False(t, errors.As(exc, &stdTarget),
		"errors.As should not match a type absent from the chain")
	assert.Nil(t, stdTarget, "target should remain nil when As returns false")
}

// customNonChainError is a type never inserted into any Exception chain,
// used to verify the errors.As failure path.
type customNonChainError struct{}

func (*customNonChainError) Error() string { return "custom" }

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
