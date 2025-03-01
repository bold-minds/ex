package ex_test

import (
	"errors"
	"fmt"
	"testing"

	"github.com/bold-minds/ex"
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
			t.Errorf("Error code not correct: expected '%s'; got '%s'", testCase.errMsg, e.Message())
		}

		expectedErrorMessage := fmt.Sprintf("%s %+v", e.Message(), e.InnerError())
		if e.Error() != expectedErrorMessage {
			t.Errorf("Error does not contain message and/or error: expected %s; got %s", expectedErrorMessage, e.Error())
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
			t.Errorf("Error code not correct: expected '%s'; got '%s'", testCase.errMsg, e.Message())
		}

		if e.InnerError() != testCase.innerErr {
			t.Errorf("Inner error not correct: expected '%+v'; got '%+v'", testCase.errMsg, e.Message())
		}

		expectedErrorMessage := fmt.Sprintf("%s %+v", e.Message(), e.InnerError())
		if e.Error() != expectedErrorMessage {
			t.Errorf("Error does not contain message and/or error: expected %s; got %s", expectedErrorMessage, e.Error())
		}
	}
}
