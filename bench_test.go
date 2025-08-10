package ex_test

import (
	"errors"
	"fmt"
	"testing"

	"github.com/bold-minds/ex"
)

// Benchmark exception creation
func BenchmarkNew(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = ex.New(ex.ExTypeApplicationFailure, 500, "Internal server error")
	}
}

// Benchmark exception creation with inner error
func BenchmarkNewWithInnerError(b *testing.B) {
	innerErr := errors.New("database connection failed")
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)
	}
}

// Benchmark Error() method without inner error
func BenchmarkErrorSimple(b *testing.B) {
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Internal server error")
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exc.Error()
	}
}

// Benchmark Error() method with inner error (allocates due to fmt.Sprintf)
func BenchmarkErrorWithInner(b *testing.B) {
	innerErr := errors.New("database connection failed")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exc.Error()
	}
}

// Benchmark Unwrap() method (should be zero-allocation)
func BenchmarkUnwrap(b *testing.B) {
	innerErr := errors.New("database connection failed")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exc.Unwrap()
	}
}

// Benchmark WithInnerError method
func BenchmarkWithInnerError(b *testing.B) {
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable")
	innerErr := errors.New("database connection failed")
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exc.WithInnerError(innerErr)
	}
}

// Benchmark errors.Is compatibility
func BenchmarkErrorsIs(b *testing.B) {
	target := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable")
	innerErr := errors.New("database connection failed")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = errors.Is(exc, target)
	}
}

// Benchmark errors.As compatibility
func BenchmarkErrorsAs(b *testing.B) {
	innerErr := errors.New("database connection failed")
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable").WithInnerError(innerErr)
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		var target ex.Exception
		_ = errors.As(exc, &target)
	}
}

// Benchmark exception type operations
func BenchmarkExTypeString(b *testing.B) {
	exType := ex.ExTypeApplicationFailure
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exType.String()
	}
}

// Benchmark accessor methods
func BenchmarkAccessors(b *testing.B) {
	exc := ex.New(ex.ExTypeApplicationFailure, 500, "Service unavailable")
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = exc.Code()
		_ = exc.ID()
		_ = exc.Message()
		_ = exc.InnerError()
	}
}

// Benchmark comparison with standard errors
func BenchmarkStandardError(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = errors.New("Internal server error")
	}
}

// Benchmark comparison with fmt.Errorf
func BenchmarkFmtErrorf(b *testing.B) {
	innerErr := errors.New("database connection failed")
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = fmt.Errorf("Service unavailable: %w", innerErr)
	}
}

// Benchmark error chain traversal
func BenchmarkErrorChainTraversal(b *testing.B) {
	// Create a chain of 5 errors
	innerErr := errors.New("root cause")
	exc1 := ex.New(ex.ExTypeIncorrectData, 400, "Level 1").WithInnerError(innerErr)
	exc2 := ex.New(ex.ExTypeApplicationFailure, 500, "Level 2").WithInnerError(exc1)
	exc3 := ex.New(ex.ExTypeApplicationFailure, 500, "Level 3").WithInnerError(exc2)
	exc4 := ex.New(ex.ExTypeApplicationFailure, 500, "Level 4").WithInnerError(exc3)
	finalExc := ex.New(ex.ExTypeApplicationFailure, 500, "Level 5").WithInnerError(exc4)
	
	b.ResetTimer()
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		// Traverse the error chain
		current := error(finalExc)
		for current != nil {
			_ = current.Error()
			current = errors.Unwrap(current)
		}
	}
}
